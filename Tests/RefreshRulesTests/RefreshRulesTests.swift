import XCTest
@testable import RefreshRules

final class RefreshRulesTests: XCTestCase {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    func testDeadlineAndRetryBoundaries() {
        let expiry = now.addingTimeInterval(48 * 3600)
        XCTAssertTrue(RefreshRules.shouldAttempt(policy: .hours48, expirations: [expiry], lastAttempt: nil, now: now))
        XCTAssertFalse(RefreshRules.shouldAttempt(policy: .hours24, expirations: [expiry], lastAttempt: nil, now: now))
        XCTAssertFalse(RefreshRules.shouldAttempt(policy: .hours48, expirations: [expiry], lastAttempt: now.addingTimeInterval(-3600), now: now))
        XCTAssertTrue(RefreshRules.shouldAttempt(policy: .hours48, expirations: [expiry], lastAttempt: now.addingTimeInterval(-6 * 3600), now: now))
    }
    func testManualAndMissingRecordsNeverSchedule() {
        XCTAssertFalse(RefreshRules.shouldAttempt(policy: .manual, expirations: [now], lastAttempt: nil, now: now))
        XCTAssertFalse(RefreshRules.shouldAttempt(policy: .automatic, expirations: [], lastAttempt: nil, now: now))
        XCTAssertTrue(RefreshRules.shouldAttempt(policy: .automatic, expirations: [now.addingTimeInterval(-1)], lastAttempt: nil, now: now))
    }
    func testIdentityChangesAndUnchangedProfilesCannotVerify() {
        func verify(team: String = "TEAM", app: String = "TEAM.app", id: String = "new", expiry: Date? = nil) -> Bool {
            RefreshRules.isRenewal(oldExpiry: now.addingTimeInterval(86400), newExpiry: expiry ?? now.addingTimeInterval(7 * 86400),
                oldID: "old", newID: id, oldTeam: "TEAM", newTeam: team, oldApp: "TEAM.app", newApp: app, now: now)
        }
        XCTAssertTrue(verify())
        XCTAssertFalse(verify(team: "OTHER"))
        XCTAssertFalse(verify(app: "TEAM.other"))
        XCTAssertFalse(verify(id: "old"))
        XCTAssertFalse(verify(expiry: now.addingTimeInterval(86400)))
        XCTAssertFalse(verify(expiry: now.addingTimeInterval(-1)))
    }
}
