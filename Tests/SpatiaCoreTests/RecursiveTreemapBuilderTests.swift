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
            options: RecursiveTreemapBuildOptions(
                maximumTraversalDepth: 3,
                childInset: 4,
                minimumExpandableTileArea: 100
            )
        )

        let tiles = builder.build(
            snapshot: snapshot,
            rootID: 0,
            in: CGRect(x: 0, y: 0, width: 320, height: 200),
            expandedNodeIDs: [1]
        )
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
                maximumTraversalDepth: 3,
                childInset: 4,
                minimumExpandableTileArea: 100,
                reservedHeaderHeight: 24
            )
        )

        let tiles = builder.build(
            snapshot: snapshot,
            rootID: 0,
            in: CGRect(x: 0, y: 0, width: 320, height: 200),
            expandedNodeIDs: [1]
        )
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
            options: RecursiveTreemapBuildOptions(maximumTraversalDepth: 1, childInset: 4)
        )

        let tiles = builder.build(snapshot: snapshot, rootID: 0, in: CGRect(x: 0, y: 0, width: 240, height: 160))
        let other = try! XCTUnwrap(tiles.first { $0.nodeID == syntheticOtherNodeID })

        XCTAssertEqual(other.label, "Other small files")
        XCTAssertEqual(other.size, 40)
        XCTAssertEqual(other.kind, .other)
    }

    func testEmptyExpandedSetOnlyBuildsCurrentLevel() {
        let snapshot = nestedSnapshot()
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 20,
                contentPadding: 0,
                readableWeightExponent: 1,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(
                maximumTraversalDepth: 12,
                childInset: 4,
                minimumExpandableTileArea: 80,
                minimumChildContentArea: 100,
                minimumUsefulChildSide: 10,
                minimumUsefulChildArea: 100,
                maximumTileCount: 20
            )
        )

        let tiles = builder.build(snapshot: snapshot, rootID: 0, in: CGRect(x: 0, y: 0, width: 320, height: 200))

        XCTAssertEqual(Set(tiles.map(\.nodeID)), [1, 2])
        XCTAssertFalse(tiles.contains { $0.depth > 0 })
    }

    func testOnlyExpandedDirectoryBuildsChildren() {
        let snapshot = competingDirectoriesSnapshot()
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 20,
                contentPadding: 0,
                readableWeightExponent: 1,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(
                maximumTraversalDepth: 12,
                childInset: 4,
                minimumExpandableTileArea: 80,
                minimumChildContentArea: 100,
                minimumUsefulChildSide: 10,
                minimumUsefulChildArea: 100,
                maximumTileCount: 20
            )
        )

        let tiles = builder.build(
            snapshot: snapshot,
            rootID: 0,
            in: CGRect(x: 0, y: 0, width: 480, height: 320),
            expandedNodeIDs: [1]
        )

        XCTAssertNotNil(tiles.first { $0.nodeID == 3 })
        XCTAssertNil(tiles.first { $0.nodeID == 4 })
    }

    func testBuildsBeyondFiveLevelsWhenAreaRemainsUseful() {
        let snapshot = deepChainSnapshot(depth: 8)
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 20,
                contentPadding: 0,
                readableWeightExponent: 1,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(
                maximumTraversalDepth: 12,
                childInset: 2,
                minimumExpandableTileArea: 100,
                minimumChildContentArea: 100,
                minimumUsefulChildSide: 10,
                minimumUsefulChildArea: 100,
                maximumTileCount: 40
            )
        )

        let tiles = builder.build(
            snapshot: snapshot,
            rootID: 0,
            in: CGRect(x: 0, y: 0, width: 1_000, height: 700),
            expandedNodeIDs: Set((1...6).map { NodeID($0) })
        )

        XCTAssertNotNil(tiles.first { $0.nodeID == 7 && $0.depth == 6 })
    }

    func testSmallParentAreaStopsExpansionBeforeTraversalLimit() {
        let snapshot = nestedSnapshot()
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 20,
                contentPadding: 0,
                readableWeightExponent: 1,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(
                maximumTraversalDepth: 12,
                childInset: 4,
                minimumExpandableTileArea: 10_000,
                minimumChildContentArea: 100,
                minimumUsefulChildSide: 10,
                minimumUsefulChildArea: 100,
                maximumTileCount: 20
            )
        )

        let tiles = builder.build(
            snapshot: snapshot,
            rootID: 0,
            in: CGRect(x: 0, y: 0, width: 120, height: 80),
            expandedNodeIDs: [1]
        )

        XCTAssertNotNil(tiles.first { $0.nodeID == 1 && $0.depth == 0 })
        XCTAssertNil(tiles.first { $0.nodeID == 3 })
    }

    func testPredictedTinyChildrenStopExpansion() {
        let snapshot = tinyChildrenSnapshot(childCount: 50)
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 80,
                contentPadding: 0,
                readableWeightExponent: 1,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(
                maximumTraversalDepth: 12,
                childInset: 4,
                minimumExpandableTileArea: 10_000,
                minimumChildContentArea: 7_500,
                minimumUsefulChildSide: 28,
                minimumUsefulChildArea: 900,
                maximumTileCount: 80
            )
        )

        let tiles = builder.build(
            snapshot: snapshot,
            rootID: 0,
            in: CGRect(x: 0, y: 0, width: 200, height: 100),
            expandedNodeIDs: [1]
        )

        XCTAssertNotNil(tiles.first { $0.nodeID == 1 && $0.depth == 0 })
        XCTAssertNil(tiles.first { $0.depth == 1 })
    }

    func testMaximumTileCountCapsOutput() {
        let snapshot = wideSnapshot(childCount: 20)
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 30,
                contentPadding: 0,
                readableWeightExponent: 1,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(
                maximumTraversalDepth: 12,
                childInset: 4,
                minimumExpandableTileArea: 80,
                minimumChildContentArea: 100,
                minimumUsefulChildSide: 10,
                minimumUsefulChildArea: 100,
                maximumTileCount: 7
            )
        )

        let tiles = builder.build(snapshot: snapshot, rootID: 0, in: CGRect(x: 0, y: 0, width: 480, height: 320))

        XCTAssertEqual(tiles.count, 7)
    }

    func testBudgetExpandsLargestDirectoryFirst() {
        let snapshot = competingDirectoriesSnapshot()
        let builder = RecursiveTreemapBuilder(
            layout: SquarifiedTreemapLayout(
                minTileArea: 0,
                maxItems: 20,
                contentPadding: 0,
                readableWeightExponent: 1,
                orientationPolicy: .spaceSniffer
            ),
            options: RecursiveTreemapBuildOptions(
                maximumTraversalDepth: 12,
                childInset: 4,
                minimumExpandableTileArea: 80,
                minimumChildContentArea: 100,
                minimumUsefulChildSide: 10,
                minimumUsefulChildArea: 100,
                maximumTileCount: 3
            )
        )

        let tiles = builder.build(
            snapshot: snapshot,
            rootID: 0,
            in: CGRect(x: 0, y: 0, width: 480, height: 320),
            expandedNodeIDs: [1, 2]
        )

        XCTAssertNotNil(tiles.first { $0.nodeID == 3 })
        XCTAssertNil(tiles.first { $0.nodeID == 4 })
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

    private func deepSnapshot() -> FileTreeSnapshot {
        FileTreeSnapshot(
            nodes: [
                FileNode(
                    id: 0,
                    parentID: nil,
                    name: "Root",
                    url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                    kind: .directory,
                    logicalSize: 1_000,
                    allocatedSize: 1_000,
                    children: [1]
                ),
                FileNode(
                    id: 1,
                    parentID: 0,
                    name: "Workspace",
                    url: URL(fileURLWithPath: "/tmp/root/Workspace", isDirectory: true),
                    kind: .directory,
                    logicalSize: 1_000,
                    allocatedSize: 1_000,
                    children: [2]
                ),
                FileNode(
                    id: 2,
                    parentID: 1,
                    name: ".build",
                    url: URL(fileURLWithPath: "/tmp/root/Workspace/.build", isDirectory: true),
                    kind: .directory,
                    logicalSize: 900,
                    allocatedSize: 900,
                    children: [3]
                ),
                FileNode(
                    id: 3,
                    parentID: 2,
                    name: "Products",
                    url: URL(fileURLWithPath: "/tmp/root/Workspace/.build/Products", isDirectory: true),
                    kind: .directory,
                    logicalSize: 800,
                    allocatedSize: 800,
                    children: [4]
                ),
                FileNode(
                    id: 4,
                    parentID: 3,
                    name: "artifact.o",
                    url: URL(fileURLWithPath: "/tmp/root/Workspace/.build/Products/artifact.o"),
                    kind: .file,
                    logicalSize: 800,
                    allocatedSize: 800
                )
            ],
            rootID: 0
        )
    }

    private func deepChainSnapshot(depth: Int) -> FileTreeSnapshot {
        precondition(depth >= 2)

        var nodes: [FileNode] = []
        for index in 0..<depth {
            let isLeaf = index == depth - 1
            let path = "/tmp/root/" + (0...index).map { "level-\($0)" }.joined(separator: "/")
            nodes.append(
                FileNode(
                    id: NodeID(index),
                    parentID: index == 0 ? nil : NodeID(index - 1),
                    name: isLeaf ? "artifact-\(index).bin" : "level-\(index)",
                    url: URL(fileURLWithPath: path, isDirectory: !isLeaf),
                    kind: isLeaf ? .file : .directory,
                    logicalSize: 1_000,
                    allocatedSize: 1_000,
                    children: isLeaf ? [] : [NodeID(index + 1)]
                )
            )
        }

        return FileTreeSnapshot(nodes: nodes, rootID: 0)
    }

    private func wideSnapshot(childCount: Int) -> FileTreeSnapshot {
        var nodes = [
            FileNode(
                id: 0,
                parentID: nil,
                name: "Root",
                url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                kind: .directory,
                logicalSize: Int64(childCount),
                allocatedSize: Int64(childCount),
                children: (1...NodeID(childCount)).map { $0 }
            )
        ]

        for index in 1...childCount {
            nodes.append(
                FileNode(
                    id: NodeID(index),
                    parentID: 0,
                    name: "File-\(index)",
                    url: URL(fileURLWithPath: "/tmp/root/File-\(index)"),
                    kind: .file,
                    logicalSize: 1,
                    allocatedSize: 1
                )
            )
        }

        return FileTreeSnapshot(nodes: nodes, rootID: 0)
    }

    private func tinyChildrenSnapshot(childCount: Int) -> FileTreeSnapshot {
        var nodes = [
            FileNode(
                id: 0,
                parentID: nil,
                name: "Root",
                url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                kind: .directory,
                logicalSize: Int64(childCount),
                allocatedSize: Int64(childCount),
                children: [1]
            ),
            FileNode(
                id: 1,
                parentID: 0,
                name: "node_modules",
                url: URL(fileURLWithPath: "/tmp/root/node_modules", isDirectory: true),
                kind: .directory,
                logicalSize: Int64(childCount),
                allocatedSize: Int64(childCount),
                children: (2..<NodeID(childCount + 2)).map { $0 }
            )
        ]

        for index in 0..<childCount {
            nodes.append(
                FileNode(
                    id: NodeID(index + 2),
                    parentID: 1,
                    name: "package-\(index)",
                    url: URL(fileURLWithPath: "/tmp/root/node_modules/package-\(index)", isDirectory: true),
                    kind: .directory,
                    logicalSize: 1,
                    allocatedSize: 1
                )
            )
        }

        return FileTreeSnapshot(nodes: nodes, rootID: 0)
    }

    private func competingDirectoriesSnapshot() -> FileTreeSnapshot {
        FileTreeSnapshot(
            nodes: [
                FileNode(
                    id: 0,
                    parentID: nil,
                    name: "Root",
                    url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                    kind: .directory,
                    logicalSize: 1_000,
                    allocatedSize: 1_000,
                    children: [1, 2]
                ),
                FileNode(
                    id: 1,
                    parentID: 0,
                    name: "Large",
                    url: URL(fileURLWithPath: "/tmp/root/Large", isDirectory: true),
                    kind: .directory,
                    logicalSize: 900,
                    allocatedSize: 900,
                    children: [3]
                ),
                FileNode(
                    id: 2,
                    parentID: 0,
                    name: "Small",
                    url: URL(fileURLWithPath: "/tmp/root/Small", isDirectory: true),
                    kind: .directory,
                    logicalSize: 100,
                    allocatedSize: 100,
                    children: [4]
                ),
                FileNode(
                    id: 3,
                    parentID: 1,
                    name: "large.bin",
                    url: URL(fileURLWithPath: "/tmp/root/Large/large.bin"),
                    kind: .file,
                    logicalSize: 900,
                    allocatedSize: 900
                ),
                FileNode(
                    id: 4,
                    parentID: 2,
                    name: "small.bin",
                    url: URL(fileURLWithPath: "/tmp/root/Small/small.bin"),
                    kind: .file,
                    logicalSize: 100,
                    allocatedSize: 100
                )
            ],
            rootID: 0
        )
    }
}
