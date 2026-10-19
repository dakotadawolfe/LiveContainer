import Foundation

public enum RefreshPolicy: String, Codable, CaseIterable, Identifiable {
    case automatic, hours48, hours24, manual
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .automatic: return "Automatic when eligible"
        case .hours48: return "48 hours before expiration"
        case .hours24: return "24 hours before expiration"
        case .manual: return "Manual only"
        }
    }
    public var threshold: TimeInterval? {
        switch self {
        case .manual: return nil
        case .hours24: return 24 * 3600
        default: return 48 * 3600
        }
    }
}

public enum RefreshRules {
    public static func shouldAttempt(policy: RefreshPolicy, expirations: [Date], lastAttempt: Date?, now: Date) -> Bool {
        guard let threshold = policy.threshold else { return false }
        if let lastAttempt, now.timeIntervalSince(lastAttempt) < 6 * 3600 { return false }
        return expirations.contains { $0.timeIntervalSince(now) <= threshold }
    }

    public static func isRenewal(oldExpiry: Date, newExpiry: Date, oldID: String, newID: String,
                                 oldTeam: String, newTeam: String, oldApp: String, newApp: String, now: Date) -> Bool {
        oldTeam == newTeam && oldApp == newApp && oldID != newID && newExpiry > oldExpiry && newExpiry > now
    }
}

