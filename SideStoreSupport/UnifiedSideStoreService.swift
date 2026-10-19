import Foundation
import UserNotifications

@MainActor
public enum UnifiedSideStoreService {
    private static var active = false
    public static func validateInstallation() throws {
        let bundle = UserDefaults.lcMainBundle() ?? Bundle.main
        let group: String? = LCSharedUtils.appGroupID()
        let accessible = group.flatMap {
            FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: $0)
        } != nil
        if let problem = BootstrapRequirements.problem(bundleURL: bundle.bundleURL, sharedGroupAccessible: accessible) {
            throw serviceError(problem)
        }
    }

    public static func request(action: String, url: URL? = nil, bundleID: String? = nil) async throws -> Data {
        try validateInstallation()
        guard !active else { throw serviceError("Another signing operation is running.") }
        active = true
        defer { active = false }
        var request = ["action": action]
        request["url"] = url?.absoluteString
        request["bundleID"] = bundleID
        let data = try JSONSerialization.data(withJSONObject: request)
        // A distinct callback receiver prevents late replies from completing a later request.
        let handler = RefreshHandler()
        try await handler.startRefresh(identifier: "unified:" + data.base64EncodedString(), mangledName: "")
        guard let result = handler.snapshot else {
            throw serviceError("SideStore returned no signing records. The operation is unverified.")
        }
        return result
    }
}

private func serviceError(_ message: String) -> NSError {
    NSError(domain: "UnifiedSideStore", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

@MainActor
final class RefreshHandler: NSObject, RefreshServer {
    var progress: Progress?
    var snapshot: Data?
    private var active = false
    private var ready = false
    private var completion: CheckedContinuation<Void, Error>?
    private var launch: CheckedContinuation<Void, Error>?
    private var listener: NSXPCListener?
    private var connection: NSXPCConnection?
    private var client: RefreshClient?
    private var ext: NSExtension?
    private var pid: Int32 = 0
    private var generation = UUID()

    func startRefresh(identifier: String, mangledName: String) async throws {
        try UnifiedSideStoreService.validateInstallation()
        guard !active else { throw serviceError("Another signing operation is running.") }
        active = true
        let operationID = UUID()
        generation = operationID
        snapshot = nil
        defer { active = false; shutdown() }
        try Task.checkCancellation()
        if listener == nil { listener = startAnonymousListener(self) }
        guard let listener else { throw serviceError("Could not create the SideStore service connection.") }
        if pid <= 0 || getpgid(pid) <= 0 || !ready {
            ready = false
            let home = getenv("LC_HOME_PATH").map { String(cString: $0) } ?? NSHomeDirectory()
            let documents = URL(fileURLWithPath: home).appendingPathComponent("Documents/SideStore")
            try FileManager.default.createDirectory(at: documents, withIntermediateDirectories: true)
            guard let bookmark = bookmarkForURL(documents),
                  let url = UserDefaults.lcMainBundle().builtInPlugInsURL?.appendingPathComponent("LiveProcess.appex"),
                  let bundle = Bundle(url: url) else {
                throw serviceError("LiveProcess could not start. Reinstall the complete combined IPA, keeping all extensions, and finish embedded SideStore setup.")
            }
            let helper = try NSExtension(identifier: bundle.bundleIdentifier)
            ext = helper
            helper.setRequestInterruptionBlock { [weak self] _ in
                Task { @MainActor in self?.fail("SideStore was interrupted. Reopen the manager to verify the installation before retrying.") }
            }
            let item = NSExtensionItem()
            item.userInfo = ["selected": "builtinSideStore", "bookmarks": [bookmark], "endpoint": listener.endpoint]
            try await withCheckedThrowingContinuation { continuation in
                launch = continuation
                Task { @MainActor in
                    let uuid = await helper.beginRequest(withInputItems: [item])
                    self.pid = helper.pid(forRequestIdentifier: uuid)
                }
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                    if self.generation == operationID, self.launch != nil { self.fail("Embedded SideStore did not start within one minute.") }
                }
            }
        }
        guard let client else { throw serviceError("Embedded SideStore is disconnected.") }
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                completion = continuation
                // Register the continuation before sending the request; replies may be immediate.
                client.refreshAllApps(withIdentifier: identifier, mangledTypeName: mangledName)
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 300_000_000_000)
                    if self.generation == operationID, self.completion != nil {
                        self.fail("SideStore did not return within five minutes. Verify installation state before retrying.")
                    }
                }
            }
        } onCancel: {
            Task { @MainActor in self.fail("The operation was interrupted. Its installation result must be verified before retrying.") }
        }
    }

    private func fail(_ message: String) {
        ready = false
        client = nil
        ext?._kill(9)
        ext = nil
        pid = 0
        let waiting = completion
        completion = nil
        let starting = launch
        launch = nil
        waiting?.resume(throwing: serviceError(message))
        starting?.resume(throwing: serviceError(message))
    }

    private func shutdown() {
        connection?.interruptionHandler = nil
        connection?.invalidationHandler = nil
        connection?.invalidate()
        connection = nil
        listener?.invalidate()
        listener = nil
        client = nil
        ext?._kill(9)
        ext = nil
        pid = 0
        ready = false
    }

    nonisolated func updateProgress(_ value: Double) {
        Task { @MainActor in self.progress?.completedUnitCount = Int64(max(0, min(1, value)) * 100) }
    }
    nonisolated func finishManagedRequest(_ data: Data!, error: String!) {
        Task { @MainActor in
            self.snapshot = data
            let waiting = self.completion
            self.completion = nil
            if let error { waiting?.resume(throwing: serviceError(error)) }
            else { waiting?.resume() }
        }
    }
    nonisolated func finish(_ error: String?) {
        Task { @MainActor in
            let waiting = self.completion
            self.completion = nil
            if let error { waiting?.resume(throwing: serviceError(error)) }
            else { waiting?.resume() }
        }
    }
    nonisolated func onConnection(_ connection: NSXPCConnection!) {
        connection.remoteObjectInterface = NSXPCInterface(with: RefreshClient.self)
        connection.interruptionHandler = { Task { @MainActor in self.fail("The SideStore connection was interrupted. Verify the installed app before retrying.") } }
        connection.invalidationHandler = { Task { @MainActor in self.fail("The SideStore connection closed. Verify the installed app before retrying.") } }
        Task { @MainActor in
            guard self.active else { connection.invalidate(); return }
            self.connection = connection
            self.client = connection.remoteObjectProxy as? RefreshClient
        }
    }
    nonisolated func finishedLaunching() {
        Task { @MainActor in
            guard self.active else { return }
            self.ready = true
            let starting = self.launch
            self.launch = nil
            starting?.resume()
        }
    }
    nonisolated func add(_ request: UNNotificationRequest!) {
        UNUserNotificationCenter.current().add(request)
    }
    nonisolated func removePendingNotificationRequests(withIdentifiers identifiers: [String]!) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: identifiers)
    }
}
