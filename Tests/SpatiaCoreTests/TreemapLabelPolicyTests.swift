import CoreGraphics
import SpatiaCore
import XCTest

final class TreemapLabelPolicyTests: XCTestCase {
    private let policy = TreemapLabelPolicy()

    func testContainerTileUsesHeaderOnlyLabelMode() {
        let tile = Tile(
            nodeID: 1,
            rect: CGRect(x: 0, y: 0, width: 200, height: 120),
            depth: 0,
            label: "Projects",
            size: 1_000,
            kind: .directory,
            reservedHeaderHeight: 22
        )

        XCTAssertEqual(policy.mode(for: tile), .containerTitle)
    }

    func testSmallTileDoesNotDrawLabel() {
        let tile = Tile(
            nodeID: 2,
            rect: CGRect(x: 0, y: 0, width: 40, height: 18),
            depth: 1,
            label: "tiny",
            size: 10,
            kind: .file
        )

        XCTAssertEqual(policy.mode(for: tile), .none)
    }

    func testLargeLeafDrawsTitleAndSize() {
        let tile = Tile(
            nodeID: 3,
            rect: CGRect(x: 0, y: 0, width: 140, height: 80),
            depth: 1,
            label: "Movie.mov",
            size: 10_000,
            kind: .file
        )

        XCTAssertEqual(policy.mode(for: tile), .titleAndSize)
    }

    func testMediumLeafDrawsTitleOnly() {
        let tile = Tile(
            nodeID: 4,
            rect: CGRect(x: 0, y: 0, width: 90, height: 28),
            depth: 1,
            label: "Notes.md",
            size: 1_000,
            kind: .file
        )

        XCTAssertEqual(policy.mode(for: tile), .titleOnly)
    }
}
