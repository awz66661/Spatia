import Foundation
import SpatiaCore
import XCTest

final class SafetyPolicyTests: XCTestCase {
    func testBlocksSystemPaths() {
        let policy = SafetyPolicy()
        let decision = policy.trashDecision(for: URL(fileURLWithPath: "/System/Library"), kind: .directory)
        XCTAssertTrue(decision.isBlocked)
    }

    func testWarnsForPackages() {
        let policy = SafetyPolicy()
        let decision = policy.trashDecision(for: URL(fileURLWithPath: "/Users/example/Movie.fcpbundle"), kind: .package)

        guard case .needsConfirmation = decision else {
            return XCTFail("Expected package warning, got \(decision)")
        }
    }
}
