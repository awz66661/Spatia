import CoreGraphics
import SpatiaCore
import XCTest

final class SquarifiedTreemapLayoutTests: XCTestCase {
    func testLayoutKeepsTilesInsideBounds() {
        let layout = SquarifiedTreemapLayout(minTileArea: 0, maxItems: 10, contentPadding: 0)
        let bounds = CGRect(x: 0, y: 0, width: 400, height: 300)
        let tiles = layout.layout(
            items: [
                TreemapInput(nodeID: 0, label: "A", size: 70, kind: .directory),
                TreemapInput(nodeID: 1, label: "B", size: 20, kind: .directory),
                TreemapInput(nodeID: 2, label: "C", size: 10, kind: .file)
            ],
            in: bounds
        )

        XCTAssertEqual(tiles.count, 3)
        for tile in tiles {
            XCTAssertTrue(bounds.contains(tile.rect), "\(tile.rect) should be inside \(bounds)")
            XCTAssertGreaterThan(tile.rect.width, 0)
            XCTAssertGreaterThan(tile.rect.height, 0)
        }
    }

    func testSmallItemsAreGrouped() {
        let layout = SquarifiedTreemapLayout(minTileArea: 10_000, maxItems: 2, contentPadding: 0)
        let bounds = CGRect(x: 0, y: 0, width: 200, height: 100)
        let tiles = layout.layout(
            items: [
                TreemapInput(nodeID: 0, label: "A", size: 100, kind: .directory),
                TreemapInput(nodeID: 1, label: "B", size: 1, kind: .file),
                TreemapInput(nodeID: 2, label: "C", size: 1, kind: .file),
                TreemapInput(nodeID: 3, label: "D", size: 1, kind: .file)
            ],
            in: bounds
        )

        XCTAssertTrue(tiles.contains { $0.nodeID == syntheticOtherNodeID })
    }
}
