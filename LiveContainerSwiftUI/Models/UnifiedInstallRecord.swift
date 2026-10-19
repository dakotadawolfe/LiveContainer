import Foundation

struct UnifiedInstallRecord: Codable {
    let bundleID: String
    let source: URL?
    let download: URL?
    let destination: InstallDestination
    let installed: Date
}

@MainActor
final class UnifiedInstallRecords: ObservableObject {
    static let shared = UnifiedInstallRecords()
    @Published private(set) var records: [String: UnifiedInstallRecord] = [:]
    private let url = LCPath.docPath.appendingPathComponent("UnifiedInstallRecords.json")
    private init() {
        if let data = try? Data(contentsOf: url), let stored = try? JSONDecoder().decode([String: UnifiedInstallRecord].self, from: data) { records = stored }
    }
    func record(bundleID: String, source: URL?, download: URL?, destination: InstallDestination) throws {
        let key = destination.rawValue + ":" + bundleID
        let previous = records[key]
        records[key] = UnifiedInstallRecord(bundleID: bundleID, source: source ?? previous?.source,
                                            download: download ?? previous?.download, destination: destination, installed: Date())
        try JSONEncoder().encode(records).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
