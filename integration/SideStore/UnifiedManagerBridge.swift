import Foundation
import CoreData
import SideSign
import UIKit
import Darwin

/// Runs inside embedded SideStore. Signing state remains owned by its database.
@objc(LCUnifiedManagerBridge)
final class LCUnifiedManagerBridge: NSObject {
    @MainActor private static var busy = false

    @objc(execute:reply:)
    static func execute(_ data: Data, reply: @escaping (Data?, String?) -> Void) {
        Task { @MainActor in
            guard !busy, !AppManager.shared.isActivelyManagingAnyApp else {
                reply(nil, "Another signing or installation operation is running.")
                return
            }
            busy = true
            defer { busy = false }
            do {
                let lockURL = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("UnifiedManager.engine.lock")
                let fd = open(lockURL.path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
                guard fd >= 0 else { throw failure("Cannot open the signing-engine lock.") }
                defer { close(fd) }
                guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { throw failure("A signing operation is still running in another helper.") }
                defer { flock(fd, LOCK_UN) }
                try await DatabaseManager.shared.start()
                let request = try JSONDecoder().decode(Request.self, from: data)
                switch request.action {
                case "snapshot": break
                case "install":
                    guard let value = request.url, let url = URL(string: value),
                          url.isFileURL || (url.scheme == "https" && url.host != nil) else {
                        throw failure("Choose a local IPA or an HTTPS download URL.")
                    }
                    _ = try await install(.url(url))
                case "refresh":
                    let context = DatabaseManager.shared.viewContext
                    let apps = InstalledApp.fetchActiveApps(in: context)
                        .filter { request.bundleID == nil || $0.bundleIdentifier == request.bundleID }
                    guard !apps.isEmpty else { throw failure("No managed apps found. Complete Apple ID setup first.") }
                    let guests = apps.filter { $0.bundleIdentifier != StoreApp.altstoreAppID }
                    if !guests.isEmpty {
                        let results = await withCheckedContinuation { continuation in
                            let group = AppManager.shared.refresh(guests, presentingViewController: nil)
                            group.completionHandler = { continuation.resume(returning: $0) }
                        }
                        for app in guests {
                            guard let result = results[app.bundleIdentifier] else {
                                throw failure("An app did not return a refresh result. Review SideStore diagnostics.")
                            }
                            _ = try result.get()
                        }
                    }
                    if apps.contains(where: { $0.bundleIdentifier == StoreApp.altstoreAppID }) {
                        // Reinstall the complete running host, never a source's standalone IPA.
                        let hostURL = Bundle.Info.activeBundleURL
                        try validateCombinedBundle(hostURL)
                        guard let host = ALTApplication(fileURL: hostURL) else {
                            throw failure("The installed combined bundle could not be read.")
                        }
                        _ = try await install(.app(host))
                    }
                default: throw failure("Unsupported manager request.")
                }
                let records = InstalledApp.fetchActiveApps(in: DatabaseManager.shared.viewContext).map { app in
                    Record(name: app.name, bundleID: app.bundleIdentifier,
                           installedBundleID: app.resignedBundleIdentifier, version: app.version,
                           expires: app.expirationDate, refreshed: app.refreshedDate,
                           installed: app.installedDate, isHost: app.bundleIdentifier == StoreApp.altstoreAppID)
                }
                reply(try JSONEncoder().encode(records), nil)
            } catch {
                // Upstream errors can contain account identifiers and server payloads.
                let nsError = error as NSError
                reply(nil, "SideStore could not complete the operation (code \(nsError.code)). Open Apple ID / Signing to check authentication, 2FA, pairing, VPN, available slots, and the detailed error.")
            }
        }
    }

    private struct Request: Decodable { let action: String; let url: String?; let bundleID: String? }
    private struct Record: Encodable {
        let name: String; let bundleID: String; let installedBundleID: String; let version: String
        let expires: Date; let refreshed: Date; let installed: Date; let isHost: Bool
    }

    @MainActor private static func install(_ target: AppManager.InstallTarget) async throws -> InstalledApp {
        try await withCheckedThrowingContinuation { continuation in
            AppManager.shared.install(target, presentingViewController: UIApplication.shared.topViewController()) {
                continuation.resume(with: $0)
            }
        }
    }

    static func validateCombinedBundle(_ url: URL) throws {
        let required = ["Frameworks/SideStoreApp.framework/SideStore", "Frameworks/SideStoreSupport.framework/SideStoreSupport",
                        "Frameworks/StikJITHeadless.framework/StikJITHeadless", "PlugIns/LiveProcess.appex/Info.plist",
                        "PlugIns/LiveWidgetExtension.appex/Info.plist", "Metadata.appintents/extract.actionsdata"]
        guard required.allSatisfy({ FileManager.default.fileExists(atPath: url.appendingPathComponent($0).path) }) else {
            throw failure("Refusing to replace the combined manager with an incomplete bundle. Install the complete LiveContainer+SideStore IPA.")
        }
    }

    private static func failure(_ message: String) -> NSError {
        NSError(domain: "UnifiedManager", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
