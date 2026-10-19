import Foundation
import Combine
import UserNotifications
import Darwin

public struct ManagedDeviceApp: Codable, Identifiable {
    public var id: String { installedBundleID }
    public let name: String
    public let bundleID: String
    public let installedBundleID: String
    public let version: String
    public let expires: Date
    public let refreshed: Date
    public let installed: Date
    public let isHost: Bool
}

public struct RefreshEvent: Codable, Identifiable {
    public let id: UUID
    public let date: Date
    public let message: String
}

public struct InstalledHostProfile: Codable {
    public let expires: Date
    public let uuid: String
    public let team: String
    public let applicationID: String

    public static func read(bundle: Bundle) -> InstalledHostProfile? {
        guard let data = try? Data(contentsOf: bundle.bundleURL.appendingPathComponent("embedded.mobileprovision")),
              let start = data.range(of: Data("<?xml".utf8)),
              let end = data.range(of: Data("</plist>".utf8), in: start.lowerBound..<data.endIndex),
              let plist = try? PropertyListSerialization.propertyList(from: data[start.lowerBound..<end.upperBound], format: nil) as? [String: Any],
              let expiration = plist["ExpirationDate"] as? Date,
              let uuid = plist["UUID"] as? String,
              let teams = plist["TeamIdentifier"] as? [String], let team = teams.first,
              let entitlements = plist["Entitlements"] as? [String: Any],
              let appID = entitlements["application-identifier"] as? String,
              let bundleID = bundle.bundleIdentifier, appID == team + "." + bundleID else { return nil }
        return InstalledHostProfile(expires: expiration, uuid: uuid, team: team, applicationID: appID)
    }
}

@MainActor
public final class UnifiedRefreshCoordinator: ObservableObject {
    public static let shared = UnifiedRefreshCoordinator()
    @Published public private(set) var apps: [ManagedDeviceApp] = []
    @Published public private(set) var events: [RefreshEvent] = []
    @Published public private(set) var busy = false
    @Published public private(set) var status = "Signing status has not been checked."
    @Published public private(set) var hostProfile: InstalledHostProfile?
    @Published public var policy: RefreshPolicy = .hours48 { didSet { persist() } }
    public private(set) var lastAttempt: Date?
    private var pending: Pending?
    private let directory: URL

    private struct Pending: Codable {
        let before: InstalledHostProfile
        let started: Date
        let processID: Int32
    }
    private struct State: Codable {
        let policy: RefreshPolicy
        let apps: [ManagedDeviceApp]
        let events: [RefreshEvent]
        let pending: Pending?
        let lastAttempt: Date?
    }

    private init() {
        let home = getenv("LC_HOME_PATH").map { String(cString: $0) } ?? NSHomeDirectory()
        directory = URL(fileURLWithPath: home).appendingPathComponent("Library/Application Support/UnifiedManager")
        if let data = try? Data(contentsOf: directory.appendingPathComponent("refresh.json")),
           let state = try? JSONDecoder().decode(State.self, from: data) {
            policy = state.policy; apps = state.apps; events = state.events
            pending = state.pending; lastAttempt = state.lastAttempt
        }
        verifyHostAfterLaunch()
    }

    public func verifyHostAfterLaunch() {
        guard let bundle = UserDefaults.lcMainBundle() else { status = "Host bundle unavailable."; return }
        hostProfile = InstalledHostProfile.read(bundle: bundle)
        guard let pending else { return }
        guard pending.processID != getpid() else {
            status = "Self-installation awaits verification after reopening the manager."
            return
        }
        if let current = hostProfile, Self.isRenewal(before: pending.before, after: current), Self.isCombined(bundle.bundleURL) {
            self.pending = nil
            record("Verified the reopened host: provisioning expiration advanced and bundled components are present.")
        } else {
            status = "Previous self-refresh is unverified. The installed profile has not advanced, the identity changed, or a required component is missing."
        }
    }

    public static func isRenewal(before: InstalledHostProfile, after: InstalledHostProfile) -> Bool {
        RefreshRules.isRenewal(oldExpiry: before.expires, newExpiry: after.expires, oldID: before.uuid, newID: after.uuid,
                              oldTeam: before.team, newTeam: after.team, oldApp: before.applicationID, newApp: after.applicationID, now: Date())
    }

    public static func isCombined(_ bundle: URL) -> Bool {
        ["Frameworks/SideStoreApp.framework/SideStore", "Frameworks/SideStoreSupport.framework/SideStoreSupport",
         "Frameworks/StikJITHeadless.framework/StikJITHeadless", "PlugIns/LiveProcess.appex/Info.plist",
         "PlugIns/LiveWidgetExtension.appex/Info.plist", "Metadata.appintents/extract.actionsdata"].allSatisfy {
            FileManager.default.fileExists(atPath: bundle.appendingPathComponent($0).path)
        }
    }

    public func synchronize() async throws {
        guard !busy else { return }
        busy = true
        defer { busy = false }
        let lock = try acquireLock()
        defer { flock(lock, LOCK_UN); close(lock) }
        let data = try await UnifiedSideStoreService.request(action: "snapshot")
        apps = try JSONDecoder().decode([ManagedDeviceApp].self, from: data)
        persist()
        verifyHostAfterLaunch()
    }

    public func foregroundOpportunity() async {
        verifyHostAfterLaunch()
        guard !busy, policy.threshold != nil,
              lastAttempt.map({ Date().timeIntervalSince($0) >= 6 * 3600 }) ?? true else { return }
        do {
            try await synchronize()
            let expirations = apps.map(\.expires) + [hostProfile?.expires].compactMap { $0 }
            if RefreshRules.shouldAttempt(policy: policy, expirations: expirations, lastAttempt: lastAttempt, now: Date()) {
                try await refresh()
            }
        } catch {
            lastAttempt = Date()
            record("Automatic refresh needs attention. Open Apple ID / Signing and check the VPN and pairing connection.")
            notifyAttention()
        }
    }

    public func refresh(bundleID: String? = nil) async throws {
        try await operate(action: "refresh", bundleID: bundleID)
    }

    public func install(url: URL) async throws {
        try await operate(action: "install", url: url)
    }

    private func operate(action: String, url: URL? = nil, bundleID: String? = nil) async throws {
        guard !busy else { throw failure("Another manager operation is running.") }
        let lock = try acquireLock()
        defer { flock(lock, LOCK_UN); close(lock) }
        busy = true
        defer { busy = false }
        if action == "refresh" {
            lastAttempt = Date()
            if bundleID == nil || apps.contains(where: { $0.bundleID == bundleID && $0.isHost }) {
                guard let before = InstalledHostProfile.read(bundle: UserDefaults.lcMainBundle()),
                      Self.isCombined(UserDefaults.lcMainBundle().bundleURL) else {
                    throw failure("The combined host and its provisioning profile could not be verified. Complete bootstrap installation first.")
                }
                pending = Pending(before: before, started: Date(), processID: getpid())
            }
        }
        record(action == "refresh" ? "Refresh started; installation results are pending." : "Device installation started.")
        // The journal must reach disk before SideStore can terminate the host for installation.
        try save()
        do {
            let data = try await UnifiedSideStoreService.request(action: action, url: url, bundleID: bundleID)
            apps = try JSONDecoder().decode([ManagedDeviceApp].self, from: data)
            record(action == "refresh" ? "SideStore returned signing records. Reopen to verify self-installation; device profile readback is still required." : "SideStore completed installation. Verify the app on the Home Screen.")
        } catch {
            record("Operation interrupted or failed. Check Apple ID / Signing for authentication, pairing, VPN, slots, and certificate errors. No verified success recorded.")
            notifyAttention()
            throw error
        }
    }

    public func enableNotifications() async throws {
        _ = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        guard let expiry = hostProfile?.expires else { return }
        for hours in [48, 24] {
            let interval = expiry.addingTimeInterval(-Double(hours) * 3600).timeIntervalSinceNow
            guard interval > 0 else { continue }
            let content = UNMutableNotificationContent()
            content.title = "Check sideloaded app refresh"
            content.body = "The last observed manager profile approaches expiration. Open the manager with LocalDevVPN connected."
            try await UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "unified-expiry-\(hours)", content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)))
        }
    }

    private func notifyAttention() {
        let content = UNMutableNotificationContent()
        content.title = "Sideloading manager needs attention"
        content.body = "Refresh is unverified. Open the manager and check Apple ID, pairing and LocalDevVPN before expiration."
        UNUserNotificationCenter.current().add(UNNotificationRequest(identifier: "unified-attention", content: content, trigger: nil))
    }
    private func record(_ message: String) {
        status = message
        events.insert(RefreshEvent(id: UUID(), date: Date(), message: message), at: 0)
        events = Array(events.prefix(100))
        persist()
    }
    private func persist() {
        do { try save() } catch { status = "Refresh history could not be saved. Do not start a self-refresh until storage is available." }
    }
    private func save() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try JSONEncoder().encode(State(policy: policy, apps: apps, events: events, pending: pending, lastAttempt: lastAttempt))
        try data.write(to: directory.appendingPathComponent("refresh.json"), options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    private func acquireLock() throws -> Int32 {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fd = open(directory.appendingPathComponent("operation.lock").path, O_CREAT | O_RDWR, S_IRUSR | S_IWUSR)
        guard fd >= 0 else { throw failure("Cannot open the installation lock.") }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else {
            close(fd)
            throw failure("Another manager or Shortcuts operation holds the installation lock.")
        }
        return fd
    }
    private func failure(_ message: String) -> NSError {
        NSError(domain: "UnifiedManager", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
