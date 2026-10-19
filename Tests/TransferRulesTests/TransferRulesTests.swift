import XCTest
@testable import TransferRules

final class TransferRulesTests: XCTestCase {
    func item(_ state: TransferState) -> TransferItem {
        var item = TransferItem(id: UUID(), url: URL(string: "https://example.com/game.ipa")!,
                                name: "Game", destination: .liveContainer,
                                source: URL(string: "https://example.com/source.json"), bundleID: "com.example.game")
        item.state = state
        return item
    }

    func testJournalPreservesIndependentJobsAndProvenance() throws {
        let jobs = [item(.downloading), item(.ready)]
        let restored = try JSONDecoder().decode([TransferItem].self, from: JSONEncoder().encode(jobs))
        XCTAssertEqual(restored.map(\.id), jobs.map(\.id))
        XCTAssertNotEqual(restored[0].id, restored[1].id)
        XCTAssertEqual(restored[0].source, jobs[0].source)
        XCTAssertEqual(restored[0].destination, .liveContainer)
        XCTAssertEqual(restored[0].bundleID, "com.example.game")
        XCTAssertEqual(restored.map(\.state), [.downloading, .ready])
    }

    func testInterruptedInstallIsNeverReportedAsSuccessfulOrAutomaticallyRepeated() {
        for hasFile in [true, false] {
            var job = item(.installing)
            job.reconcile(hasFile: hasFile, hasTask: false)
            XCTAssertEqual(job.state, .failed)
            XCTAssertFalse(job.state.isActive)
            XCTAssertTrue(job.message?.contains("not verified") == true)
        }
    }

    func testCompletedBackgroundDownloadBecomesReadyAfterRelaunch() {
        var job = item(.downloading)
        job.reconcile(hasFile: true, hasTask: false)
        XCTAssertEqual(job.state, .ready)
        XCTAssertNil(job.message)
    }

    func testLiveBackgroundTransferIsReattachedInsteadOfRestarted() {
        var job = item(.downloading)
        job.reconcile(hasFile: false, hasTask: true)
        XCTAssertEqual(job.state, .downloading)
    }

    func testMissingTransferOrIPARequiresRetry() {
        for state in [TransferState.downloading, .ready] {
            var job = item(state)
            job.reconcile(hasFile: false, hasTask: false)
            XCTAssertEqual(job.state, .failed)
            XCTAssertNotNil(job.message)
        }
    }

    func testRecoveryDoesNotResurrectCancelledOrFinishedJobs() {
        for state in [TransferState.completed, .cancelled, .failed] {
            var job = item(state)
            job.reconcile(hasFile: true, hasTask: true)
            XCTAssertEqual(job.state, state)
            XCTAssertFalse(job.state.isActive)
        }
    }

    func testUnknownLengthAndMisreportedLengthsHaveSafeProgress() {
        var job = item(.downloading)
        job.received = 50
        XCTAssertNil(job.progress)
        job.expected = -1
        XCTAssertNil(job.progress)
        job.expected = 100
        XCTAssertEqual(job.progress, 0.5)
        job.received = 200
        XCTAssertEqual(job.progress, 1)
        job.received = -1
        XCTAssertEqual(job.progress, 0)
    }
}
