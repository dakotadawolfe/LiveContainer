import Foundation

enum InstallDestination: String, CaseIterable, Identifiable, Codable {
    case device, liveContainer
    var id: String { rawValue }
    var title: String { self == .device ? "Install to Device" : "Install in LiveContainer" }
}

enum TransferState: String, Codable {
    case queued, downloading, ready, installing, completed, failed, cancelled

    var isActive: Bool { [.queued, .downloading, .ready, .installing].contains(self) }
    var title: String {
        switch self {
        case .queued: return "Queued"
        case .downloading: return "Downloading"
        case .ready: return "Waiting to install"
        case .installing: return "Installing"
        case .completed: return "Installed"
        case .failed: return "Needs attention"
        case .cancelled: return "Cancelled"
        }
    }
}

struct TransferItem: Codable, Identifiable {
    let id: UUID
    let url: URL
    let name: String
    let destination: InstallDestination
    let source: URL?
    let bundleID: String?
    var state: TransferState = .queued
    var received: Int64 = 0
    var expected: Int64 = 0
    var message: String?

    var progress: Double? { expected > 0 ? min(1, max(0, Double(received) / Double(expected))) : nil }

    mutating func reconcile(hasFile: Bool, hasTask: Bool) {
        if state == .installing {
            state = .failed
            message = "Installation was interrupted. Check Installed before retrying; completion was not verified."
        } else if state == .downloading && !hasTask {
            state = hasFile ? .ready : .failed
            if !hasFile { message = "Download was interrupted. Tap Retry to download again." }
        } else if state == .ready && !hasFile {
            state = .failed
            message = "The downloaded IPA is missing. Tap Retry to download again."
        }
    }
}
