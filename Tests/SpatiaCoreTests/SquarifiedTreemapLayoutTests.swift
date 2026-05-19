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

    func testGroupedSmallItemsPreserveAggregateSize() {
        let layout = SquarifiedTreemapLayout(minTileArea: 1_000, maxItems: 1, contentPadding: 0)
        let tiles = layout.layout(
            items: [
                TreemapInput(nodeID: 0, label: "A", size: 100, kind: .directory),
                TreemapInput(nodeID: 1, label: "B", size: 30, kind: .file),
                TreemapInput(nodeID: 2, label: "C", size: 20, kind: .file),
                TreemapInput(nodeID: 3, label: "D", size: 10, kind: .file)
            ],
            in: CGRect(x: 0, y: 0, width: 200, height: 100)
        )

        XCTAssertEqual(tiles.first { $0.nodeID == syntheticOtherNodeID }?.size, 60)
    }

    func testReadableWeightKeepsTileSizeAsActualBytesAndMonotonicArea() {
        let layout = SquarifiedTreemapLayout(
            minTileArea: 0,
            maxItems: 10,
            contentPadding: 0,
            readableWeightExponent: 0.88,
            orientationPolicy: .spaceSniffer
        )
        let tiles = layout.layout(
            items: [
                TreemapInput(nodeID: 0, label: "Large", size: 10_000, kind: .file),
                TreemapInput(nodeID: 1, label: "Small", size: 100, kind: .file)
            ],
            in: CGRect(x: 0, y: 0, width: 300, height: 180)
        )

        let large = try! XCTUnwrap(tiles.first { $0.nodeID == 0 })
        let small = try! XCTUnwrap(tiles.first { $0.nodeID == 1 })

        XCTAssertEqual(large.size, 10_000)
        XCTAssertEqual(small.size, 100)
        XCTAssertGreaterThan(large.rect.width * large.rect.height, small.rect.width * small.rect.height)
        XCTAssertGreaterThan(layout.layoutWeight(for: 10_000), layout.layoutWeight(for: 100))
    }

    func testSpaceSnifferOrientationPolicyAlternatesDirection() {
        let policy = TreemapOrientationPolicy.spaceSniffer

        XCTAssertEqual(policy.flow(for: CGRect(x: 0, y: 0, width: 400, height: 200), depth: 0), .columns)
        XCTAssertEqual(policy.flow(for: CGRect(x: 0, y: 0, width: 400, height: 200), depth: 1), .rows)
        XCTAssertEqual(policy.flow(for: CGRect(x: 0, y: 0, width: 200, height: 400), depth: 0), .rows)
    }
}
