import Foundation
import SpatiaCore
import XCTest

final class PathRiskPolicyTests: XCTestCase {
    private let home = URL(fileURLWithPath: "/Users/example", isDirectory: true)

    func testClassifiesSystemAndCachePathsForSharedUse() {
        let policy = PathRiskPolicy(homeDirectory: home)

        XCTAssertTrue(policy.isSystemCategory(url: URL(fileURLWithPath: "/Library", isDirectory: true)))
        XCTAssertTrue(policy.isCacheCategory(
            url: home.appendingPathComponent("Library/Caches/com.example", isDirectory: true),
            name: "com.example"
        ))
    }

    func testRiskClassificationUsesSharedRules() {
        let policy = PathRiskPolicy(homeDirectory: home)

        XCTAssertEqual(
            policy.risk(url: home, name: "example", kind: .directory).classification,
            .homeRoot
        )
        XCTAssertEqual(
            policy.risk(
                url: home.appendingPathComponent("Library/Application Support", isDirectory: true),
                name: "Application Support",
                kind: .directory
            ).classification,
            .userLibrary
        )
        XCTAssertEqual(
            policy.risk(
                url: home.appendingPathComponent("Library/Caches/com.example", isDirectory: true),
                name: "com.example",
                kind: .directory
            ).classification,
            .userCache
        )
    }

    func testImmutableFlagIsSeparateFromSystemCategory() {
        let policy = PathRiskPolicy(homeDirectory: home)
        let url = home.appendingPathComponent("Downloads/locked.dat")

        XCTAssertFalse(policy.isSystemCategory(url: url, flags: [.immutable]))
        XCTAssertEqual(
            policy.risk(url: url, name: "locked.dat", kind: .file, flags: [.immutable]).classification,
            .immutable
        )
    }
}
