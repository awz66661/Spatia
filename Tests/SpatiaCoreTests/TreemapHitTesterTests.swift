import CoreGraphics
import SpatiaCore
import XCTest

final class TreemapHitTesterTests: XCTestCase {
    func testHitTestReturnsContainingTile() {
        let tester = TreemapHitTester(gapTolerance: 0)
        let tiles = [
            Tile(nodeID: 1, rect: CGRect(x: 0, y: 0, width: 100, height: 100), depth: 0, label: "A", size: 10, kind: .directory),
            Tile(nodeID: 2, rect: CGRect(x: 100, y: 0, width: 100, height: 100), depth: 0, label: "B", size: 10, kind: .file)
        ]

        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 40, y: 40), tiles: tiles)?.nodeID, 1)
        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 140, y: 40), tiles: tiles)?.nodeID, 2)
    }

    func testHitTestPrefersSmallestContainingTile() {
        let tester = TreemapHitTester(gapTolerance: 0)
        let tiles = [
            Tile(nodeID: 1, rect: CGRect(x: 0, y: 0, width: 200, height: 200), depth: 0, label: "Parent", size: 100, kind: .directory),
            Tile(nodeID: 2, rect: CGRect(x: 20, y: 20, width: 40, height: 40), depth: 1, label: "Child", size: 10, kind: .file)
        ]

        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 30, y: 30), tiles: tiles)?.nodeID, 2)
    }

    func testHitTestUsesGapTolerance() {
        let tester = TreemapHitTester(gapTolerance: 1)
        let tiles = [
            Tile(nodeID: 1, rect: CGRect(x: 0, y: 0, width: 10, height: 10), depth: 0, label: "A", size: 1, kind: .file)
        ]

        XCTAssertEqual(tester.hitTest(point: CGPoint(x: 10.5, y: 5), tiles: tiles)?.nodeID, 1)
        XCTAssertNil(tester.hitTest(point: CGPoint(x: 12, y: 5), tiles: tiles))
    }
}
