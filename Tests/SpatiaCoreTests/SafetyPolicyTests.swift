import Foundation
import SpatiaCore
import XCTest

final class SafetyPolicyTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

    func testBlocksSystemPaths() {
        let policy = policy()
        let decision = policy.trashDecision(for: URL(fileURLWithPath: "/System/Library"), kind: .directory)
        XCTAssertTrue(decision.isBlocked)
    }

    func testBlocksHomeRoot() {
        let decision = policy().trashDecision(for: home, kind: .directory)
        XCTAssertTrue(decision.isBlocked)
    }

    func testBlocksUserLibraryExceptCaches() {
        let decision = policy().trashDecision(
            for: home.appendingPathComponent("Library/Application Support/App", isDirectory: true),
            kind: .directory
        )
        XCTAssertTrue(decision.isBlocked)
    }

    func testWarnsForUserCaches() {
        let decision = policy().trashDecision(
            for: home.appendingPathComponent("Library/Caches/com.example.app", isDirectory: true),
            kind: .directory
        )

        guard case let .needsConfirmation(warnings) = decision else {
            return XCTFail("Expected cache warning, got \(decision)")
        }
        XCTAssertTrue(warnings.contains { $0.contains("Cache") })
    }

    func testWarnsForPackages() {
        let decision = policy().trashDecision(for: URL(fileURLWithPath: "/Users/example/Movie.fcpbundle"), kind: .package)

        guard case let .needsConfirmation(warnings) = decision else {
            return XCTFail("Expected package warning, got \(decision)")
        }
        XCTAssertTrue(warnings.contains { $0.contains("package") })
    }

    func testWarnsForOrdinaryDirectories() {
        let decision = policy().trashDecision(
            for: home.appendingPathComponent("Downloads/Archive", isDirectory: true),
            kind: .directory
        )

        guard case let .needsConfirmation(warnings) = decision else {
            return XCTFail("Expected directory warning, got \(decision)")
        }
        XCTAssertTrue(warnings.contains { $0.contains("folder") })
    }

    func testAllowsOrdinaryFiles() {
        let decision = policy().trashDecision(
            for: home.appendingPathComponent("Downloads/movie.mov"),
            kind: .file
        )

        XCTAssertEqual(decision, .allowed)
    }

    func testBlocksApplicationBundlesInApplications() {
        let decision = policy().trashDecision(
            for: URL(fileURLWithPath: "/Applications/Example.app", isDirectory: true),
            kind: .package
        )

        XCTAssertTrue(decision.isBlocked)
    }

    func testWarnsWhenRecoverableSpaceIsUncertain() {
        let decision = policy().trashDecision(
            for: home.appendingPathComponent("Downloads/clone.dat"),
            name: "clone.dat",
            kind: .file,
            flags: [.possiblySharedAPFSBlocks]
        )

        guard case let .needsConfirmation(warnings) = decision else {
            return XCTFail("Expected APFS caveat warning, got \(decision)")
        }
        XCTAssertTrue(warnings.contains { $0.contains("space recovered") })
    }

    private func policy() -> SafetyPolicy {
        SafetyPolicy(pathRiskPolicy: PathRiskPolicy(homeDirectory: home))
    }
}
