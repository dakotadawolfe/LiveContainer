import SwiftUI
import Combine
import SideStoreSupport

@MainActor
final class ContainerTransferQueue: ObservableObject {
    static let shared = ContainerTransferQueue()
    static let sessionIdentifier = "com.livecontainer.manager.transfers.v1"
    @Published private(set) var items: [TransferItem] = []
    @Published var showQueue = false
    @Published var storageError: String?
    var backgroundCompletion: (() -> Void)?
    let directory: URL
    private var session: URLSession!
    private var tasks: [UUID: URLSessionDownloadTask] = [:]
    private var installing = false
    private var restored = false
    private var waitingForGuest = false
    private var subscriptions = Set<AnyCancellable>()

    var activeCount: Int { items.filter { $0.state.isActive }.count }
    var failedCount: Int { items.filter { $0.state == .failed }.count }
    var isInstallingGuest: Bool { items.contains { $0.state == .installing && $0.destination == .liveContainer } }

    private init() {
        directory = LCPath.docPath.appendingPathComponent("TransferQueue", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let journal = directory.appendingPathComponent("queue.json")
            if FileManager.default.fileExists(atPath: journal.path) {
                items = try JSONDecoder().decode([TransferItem].self, from: Data(contentsOf: journal))
            }
        } catch { storageError = "Could not load the download queue: \(error.localizedDescription)" }
        let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
        configuration.isDiscretionary = false
        configuration.sessionSendsLaunchEvents = true
        configuration.httpMaximumConnectionsPerHost = 3
        session = URLSession(configuration: configuration,
                             delegate: TransferDownloadDelegate(directory: directory, owner: self), delegateQueue: .main)
        session.getAllTasks { tasks in
            Task { @MainActor in
                for task in tasks {
                    guard let download = task as? URLSessionDownloadTask,
                          let text = task.taskDescription, let id = UUID(uuidString: text),
                          self.items.contains(where: { $0.id == id && $0.state == .downloading }) else {
                        task.cancel(); continue
                    }
                    self.tasks[id] = download
                }
                for i in self.items.indices {
                    let id = self.items[i].id
                    self.items[i].reconcile(hasFile: FileManager.default.fileExists(atPath: self.file(id).path),
                                            hasTask: self.tasks[id] != nil)
                }
                self.restored = true
                self.save()
                self.pump()
            }
        }
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in self?.pump() }.store(in: &subscriptions)
        UnifiedRefreshCoordinator.shared.$busy.removeDuplicates()
            .sink { [weak self] busy in
                if !busy { DispatchQueue.main.async { self?.pump() } }
            }.store(in: &subscriptions)
    }

    func file(_ id: UUID) -> URL { directory.appendingPathComponent(id.uuidString + ".ipa") }

    func enqueue(url: URL, name: String? = nil, destination: InstallDestination, source: URL? = nil, bundleID: String? = nil) throws {
        guard storageError == nil else { throw storageError! }
        guard DataManager.shared.model.multiLCStatus != 2 else { throw "Manage downloads in the primary LiveContainer." }
        guard url.isFileURL || (url.scheme?.lowercased() == "https" && url.host != nil && url.user == nil && url.password == nil) else {
            throw "Choose a local IPA or an HTTPS download URL."
        }
        if items.contains(where: { $0.url == url && $0.destination == destination && $0.state.isActive }) {
            showQueue = true
            return
        }
        var item = TransferItem(id: UUID(), url: url, name: name ?? url.lastPathComponent,
                                destination: destination, source: source, bundleID: bundleID)
        if url.isFileURL {
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            try FileManager.default.copyItem(at: url, to: file(item.id))
            item.state = .ready
        }
        items.append(item)
        guard save() else {
            items.removeAll { $0.id == item.id }
            try? FileManager.default.removeItem(at: file(item.id))
            throw storageError ?? "Could not save the download queue."
        }
        pump()
    }

    func retry(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }), items[i].state == .failed else { return }
        if FileManager.default.fileExists(atPath: file(id).path) { items[i].state = .ready }
        else if items[i].url.isFileURL {
            items[i].message = "Import this IPA again from Files to restore access."; save(); return
        } else { items[i].state = .queued }
        items[i].message = nil
        items[i].received = 0
        items[i].expected = 0
        save(); pump()
    }

    func cancel(_ id: UUID) {
        guard let i = items.firstIndex(where: { $0.id == id }), items[i].state.isActive || items[i].state == .failed,
              items[i].state != .installing else { return }
        items[i].state = .cancelled
        tasks.removeValue(forKey: id)?.cancel()
        try? FileManager.default.removeItem(at: file(id))
        save(); pump()
    }

    func clearFinished() {
        let finished = items.filter { $0.state == .completed || $0.state == .cancelled }
        for item in finished { try? FileManager.default.removeItem(at: file(item.id)) }
        items.removeAll { $0.state == .completed || $0.state == .cancelled }
        save()
    }

    @discardableResult private func save() -> Bool {
        do {
            try JSONEncoder().encode(items).write(to: directory.appendingPathComponent("queue.json"),
                                                   options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
            return true
        } catch {
            storageError = "Could not save the download queue: \(error.localizedDescription)"
            return false
        }
    }

    func pump() {
        guard restored, storageError == nil else { return }
        for i in items.indices where items[i].state == .queued {
            guard tasks.count < 3 else { break }
            let item = items[i]
            let task = session.downloadTask(with: item.url)
            task.taskDescription = item.id.uuidString
            items[i].state = .downloading
            guard save() else { task.cancel(); return }
            tasks[item.id] = task
            task.resume()
        }
        guard !installing, !UnifiedRefreshCoordinator.shared.busy,
              UIApplication.shared.applicationState == .active,
              let next = items.first(where: { $0.state == .ready }) else { return }
        let model = DataManager.shared.model
        if (model.apps + model.hiddenApps).contains(where: { $0.isAppRunning || $0.isSigningInProgress }) {
            if !waitingForGuest {
                waitingForGuest = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    self.waitingForGuest = false
                    self.pump()
                }
            }
            return
        }
        installing = true
        change(next.id, state: .installing)
        guard storageError == nil else { installing = false; return }
        Task {
            var background: UIBackgroundTaskIdentifier = .invalid
            background = UIApplication.shared.beginBackgroundTask(withName: "Finish container installation") {
                if background != .invalid {
                    UIApplication.shared.endBackgroundTask(background)
                    background = .invalid
                }
            }
            defer {
                if background != .invalid { UIApplication.shared.endBackgroundTask(background) }
                installing = false
                pump()
            }
            do {
                if next.destination == .liveContainer {
                    try await UnifiedRefreshCoordinator.shared.withGuestInstallation {
                        try await ContainerInstaller.shared.install(file(next.id), source: next.source, download: next.url.isFileURL ? nil : next.url)
                    }
                } else {
                    let inbox = LCPath.docPath.appendingPathComponent("SideStore/Documents/ManagerImports")
                    try FileManager.default.createDirectory(at: inbox, withIntermediateDirectories: true)
                    let staged = inbox.appendingPathComponent(next.id.uuidString + ".ipa")
                    defer { try? FileManager.default.removeItem(at: staged) }
                    try? FileManager.default.removeItem(at: staged)
                    try FileManager.default.copyItem(at: file(next.id), to: staged)
                    try await UnifiedRefreshCoordinator.shared.install(url: staged)
                    if let bundleID = next.bundleID {
                        try UnifiedInstallRecords.shared.record(bundleID: bundleID, source: next.source, download: next.url, destination: .device)
                    }
                }
                change(next.id, state: .completed, message: next.destination == .liveContainer ? ContainerInstaller.shared.warning : nil)
                try? FileManager.default.removeItem(at: file(next.id))
            } catch is CancellationError { change(next.id, state: .cancelled) }
            catch { change(next.id, state: .failed, message: error.localizedDescription) }
        }
    }

    private func change(_ id: UUID, state: TransferState, message: String? = nil) {
        guard let i = items.firstIndex(where: { $0.id == id }) else { return }
        items[i].state = state; items[i].message = message
        save()
    }

    fileprivate func progress(_ id: UUID, taskID: Int, received: Int64, expected: Int64) {
        guard tasks[id]?.taskIdentifier == taskID,
              let i = items.firstIndex(where: { $0.id == id }), items[i].state == .downloading else { return }
        items[i].received = received; items[i].expected = expected
    }

    fileprivate func downloaded(_ id: UUID, taskID: Int, error: String?) {
        guard let item = items.first(where: { $0.id == id }), item.state == .downloading else {
            if !items.contains(where: { $0.id == id && $0.state.isActive }) {
                try? FileManager.default.removeItem(at: file(id))
            }
            return
        }
        guard !restored || tasks[id]?.taskIdentifier == taskID else { return }
        tasks.removeValue(forKey: id)
        change(id, state: error == nil ? .ready : .failed, message: error)
        pump()
    }

    fileprivate func failed(_ id: UUID, taskID: Int, error: Error) {
        guard items.contains(where: { $0.id == id && $0.state == .downloading }) else { return }
        downloaded(id, taskID: taskID, error: error.localizedDescription)
    }
}

private final class TransferDownloadDelegate: NSObject, URLSessionDownloadDelegate {
    let directory: URL
    weak var owner: ContainerTransferQueue?
    init(directory: URL, owner: ContainerTransferQueue) { self.directory = directory; self.owner = owner }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let text = downloadTask.taskDescription, let id = UUID(uuidString: text) else { return }
        var failure: String?
        do {
            guard let response = downloadTask.response as? HTTPURLResponse, (200...299).contains(response.statusCode),
                  response.url?.scheme?.lowercased() == "https" else {
                throw NSError(domain: "Download", code: (downloadTask.response as? HTTPURLResponse)?.statusCode ?? -1,
                              userInfo: [NSLocalizedDescriptionKey: "The server did not return a successful HTTPS download."])
            }
            let target = directory.appendingPathComponent(id.uuidString + ".ipa")
            try? FileManager.default.removeItem(at: target)
            // URLSession removes location after this callback returns.
            try FileManager.default.moveItem(at: location, to: target)
            try FileManager.default.setAttributes([.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication], ofItemAtPath: target.path)
        } catch { failure = error.localizedDescription }
        let message = failure
        DispatchQueue.main.async { self.owner?.downloaded(id, taskID: downloadTask.taskIdentifier, error: message) }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard let text = downloadTask.taskDescription, let id = UUID(uuidString: text) else { return }
        DispatchQueue.main.async { self.owner?.progress(id, taskID: downloadTask.taskIdentifier, received: totalBytesWritten, expected: totalBytesExpectedToWrite) }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error, let text = task.taskDescription, let id = UUID(uuidString: text) else { return }
        DispatchQueue.main.async { self.owner?.failed(id, taskID: task.taskIdentifier, error: error) }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            let completion = self.owner?.backgroundCompletion
            self.owner?.backgroundCompletion = nil
            completion?()
        }
    }
}
