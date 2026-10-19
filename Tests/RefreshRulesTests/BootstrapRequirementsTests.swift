import Foundation
import XCTest
@testable import RefreshRules

final class BootstrapRequirementsTests: XCTestCase {
    func testCompleteBundleStillRequiresSharedGroupAccess() throws {
        try withBundle { url in
            XCTAssertNil(BootstrapRequirements.problem(bundleURL: url, sharedGroupAccessible: true))
            let problem = try XCTUnwrap(BootstrapRequirements.problem(bundleURL: url, sharedGroupAccessible: false))
            XCTAssertTrue(problem.contains("App Group"))
            XCTAssertFalse(problem.contains("missing required components"))
        }
    }

    func testStrippedExtensionsCannotPassWithAnAccessibleGroup() throws {
        try withBundle { url in
            for component in BootstrapRequirements.components.filter({ $0.hasPrefix("PlugIns/") }) {
                try FileManager.default.removeItem(at: url.appendingPathComponent(component))
            }
            let problem = try XCTUnwrap(BootstrapRequirements.problem(bundleURL: url, sharedGroupAccessible: true))
            XCTAssertTrue(problem.contains("LiveProcess.appex"))
            XCTAssertTrue(problem.contains("LiveWidgetExtension.appex"))
            XCTAssertTrue(problem.contains("Do not choose Remove and Install"))
        }
    }

    func testMissingBundleAndGroupReportBothProblemsWithoutCreatingFiles() throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let problem = try XCTUnwrap(BootstrapRequirements.problem(bundleURL: url, sharedGroupAccessible: false))
        XCTAssertTrue(problem.contains("missing required components"))
        XCTAssertTrue(problem.contains("App Group"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    private func withBundle(_ test: (URL) throws -> Void) throws {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: url) }
        for component in BootstrapRequirements.components {
            let file = url.appendingPathComponent(component)
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data().write(to: file)
        }
        try test(url)
    }
}
