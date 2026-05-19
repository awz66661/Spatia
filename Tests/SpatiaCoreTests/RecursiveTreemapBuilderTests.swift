import CoreGraphics
import SpatiaCore
import XCTest

final class RecursiveTreemapBuilderTests: XCTestCase {
    func testBuildsNestedTilesInsideParentRects() {
        let snapshot = nestedSnapshot()
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 20,
                contentPadding: 0,
                readableWeightExponent: 0.88,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(maxDepth: 3, childInset: 4, minimumParentArea: 100)
        )

        let tiles = builder.build(snapshot: snapshot, rootID: 0, in: CGRect(x: 0, y: 0, width: 320, height: 200))
        let parent = try! XCTUnwrap(tiles.first { $0.nodeID == 1 && $0.depth == 0 })
        let child = try! XCTUnwrap(tiles.first { $0.nodeID == 3 && $0.depth == 1 })

        XCTAssertTrue(parent.rect.contains(child.rect), "\(child.rect) should be inside \(parent.rect)")
        XCTAssertEqual(child.size, 70)
    }

    func testNestedChildrenDoNotOverlapReservedParentHeader() {
        let snapshot = nestedSnapshot()
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 20,
                contentPadding: 0,
                readableWeightExponent: 0.88,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(
                maxDepth: 3,
                childInset: 4,
                minimumParentArea: 100,
                reservedHeaderHeight: 24
            )
        )

        let tiles = builder.build(snapshot: snapshot, rootID: 0, in: CGRect(x: 0, y: 0, width: 320, height: 200))
        let parent = try! XCTUnwrap(tiles.first { $0.nodeID == 1 && $0.depth == 0 })
        let childTiles = tiles.filter { $0.depth == 1 }

        XCTAssertGreaterThan(parent.reservedHeaderHeight, 0)
        for child in childTiles {
            XCTAssertFalse(
                parent.reservedHeaderRect.intersects(child.rect),
                "\(child.rect) should not overlap reserved header \(parent.reservedHeaderRect)"
            )
        }
    }

    func testOtherSmallFilesKeepsActualAggregateSizeAndSyntheticID() {
        let snapshot = nestedSnapshot()
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 1,
                contentPadding: 0,
                readableWeightExponent: 0.88,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(maxDepth: 1, childInset: 4)
        )

        let tiles = builder.build(snapshot: snapshot, rootID: 0, in: CGRect(x: 0, y: 0, width: 240, height: 160))
        let other = try! XCTUnwrap(tiles.first { $0.nodeID == syntheticOtherNodeID })

        XCTAssertEqual(other.label, "Other small files")
        XCTAssertEqual(other.size, 40)
        XCTAssertEqual(other.kind, .other)
    }

    private func nestedSnapshot() -> FileTreeSnapshot {
        FileTreeSnapshot(
            nodes: [
                FileNode(
                    id: 0,
                    parentID: nil,
                    name: "Root",
                    url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                    kind: .directory,
                    logicalSize: 140,
                    allocatedSize: 140,
                    children: [1, 2]
                ),
                FileNode(
                    id: 1,
                    parentID: 0,
                    name: "Projects",
                    url: URL(fileURLWithPath: "/tmp/root/Projects", isDirectory: true),
                    kind: .directory,
                    logicalSize: 100,
                    allocatedSize: 100,
                    children: [3, 4]
                ),
                FileNode(
                    id: 2,
                    parentID: 0,
                    name: "Archive.zip",
                    url: URL(fileURLWithPath: "/tmp/root/Archive.zip"),
                    kind: .file,
                    logicalSize: 40,
                    allocatedSize: 40
                ),
                FileNode(
                    id: 3,
                    parentID: 1,
                    name: "Movie.mov",
                    url: URL(fileURLWithPath: "/tmp/root/Projects/Movie.mov"),
                    kind: .file,
                    logicalSize: 70,
                    allocatedSize: 70
                ),
                FileNode(
                    id: 4,
                    parentID: 1,
                    name: "Poster.png",
                    url: URL(fileURLWithPath: "/tmp/root/Projects/Poster.png"),
                    kind: .file,
                    logicalSize: 30,
                    allocatedSize: 30
                )
            ],
            rootID: 0
        )
    }
}
