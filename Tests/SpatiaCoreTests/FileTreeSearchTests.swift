import Foundation
import SpatiaCore
import XCTest

final class FileTreeSearchTests: XCTestCase {
    func testSearchMatchesNameRelativePathKindAndCategory() {
        let snapshot = searchSnapshot()

        XCTAssertEqual(snapshot.search(query: "movie", rootedAt: 0).map(\.nodeID), [2])
        XCTAssertEqual(snapshot.search(query: "Projects", rootedAt: 0).map(\.nodeID), [1, 3, 4])
        XCTAssertEqual(snapshot.search(query: "directory", rootedAt: 0).map(\.nodeID), [1])
        XCTAssertEqual(snapshot.search(query: "video", rootedAt: 0).map(\.nodeID), [2])
    }

    func testSearchScopesToCurrentRootAndSortsBySize() {
        let snapshot = searchSnapshot()

        let rootResults = snapshot.search(query: "swift", rootedAt: 0)
        XCTAssertEqual(rootResults.map(\.nodeID), [3, 4])

        let scopedResults = snapshot.search(query: "swift", rootedAt: 1)
        XCTAssertEqual(scopedResults.map(\.nodeID), [3, 4])
        XCTAssertEqual(scopedResults.map(\.relativePath), ["App.swift", "Tests.swift"])

        XCTAssertTrue(snapshot.search(query: "movie", rootedAt: 1).isEmpty)
    }

    func testSearchIndexStoresScopedEntriesAndMatchesFields() {
        let snapshot = searchSnapshot()

        let index = FileSearchIndex(snapshot: snapshot, rootedAt: 0)

        XCTAssertEqual(index.rootID, 0)
        XCTAssertEqual(index.entries.map(\.nodeID), [1, 3, 4, 2])
        XCTAssertEqual(index.entries.first?.relativePath, "Projects")
        XCTAssertTrue(index.entries.first?.matchText.contains("directory") == true)
        XCTAssertEqual(index.search(query: "video").map(\.nodeID), [2])
    }

    func testLargeWideSearchUsesBoundedTopResults() {
        let snapshot = largeWideSnapshot(fileCount: 10_000)
        let index = FileSearchIndex(snapshot: snapshot, rootedAt: 0)

        let results = index.search(query: "match", limit: 30)

        XCTAssertEqual(results.count, 30)
        XCTAssertEqual(results.first?.nodeID, 10_000)
        XCTAssertEqual(results.last?.nodeID, 9_971)
    }

    private func searchSnapshot() -> FileTreeSnapshot {
        FileTreeSnapshot(
            nodes: [
                FileNode(
                    id: 0,
                    parentID: nil,
                    name: "root",
                    url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                    kind: .directory,
                    logicalSize: 190,
                    allocatedSize: 190,
                    children: [1, 2]
                ),
                FileNode(
                    id: 1,
                    parentID: 0,
                    name: "Projects",
                    url: URL(fileURLWithPath: "/tmp/root/Projects", isDirectory: true),
                    kind: .directory,
                    logicalSize: 110,
                    allocatedSize: 110,
                    children: [3, 4]
                ),
                FileNode(
                    id: 2,
                    parentID: 0,
                    name: "Movie.mov",
                    url: URL(fileURLWithPath: "/tmp/root/Movie.mov"),
                    kind: .file,
                    logicalSize: 80,
                    allocatedSize: 80
                ),
                FileNode(
                    id: 3,
                    parentID: 1,
                    name: "App.swift",
                    url: URL(fileURLWithPath: "/tmp/root/Projects/App.swift"),
                    kind: .file,
                    logicalSize: 70,
                    allocatedSize: 70
                ),
                FileNode(
                    id: 4,
                    parentID: 1,
                    name: "Tests.swift",
                    url: URL(fileURLWithPath: "/tmp/root/Projects/Tests.swift"),
                    kind: .file,
                    logicalSize: 40,
                    allocatedSize: 40
                )
            ],
            rootID: 0
        )
    }

    private func largeWideSnapshot(fileCount: Int) -> FileTreeSnapshot {
        var nodes = [
            FileNode(
                id: 0,
                parentID: nil,
                name: "root",
                url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                kind: .directory,
                logicalSize: Int64(fileCount),
                allocatedSize: Int64(fileCount),
                children: (1...NodeID(fileCount)).map { $0 }
            )
        ]

        for index in 1...fileCount {
            nodes.append(
                FileNode(
                    id: NodeID(index),
                    parentID: 0,
                    name: "match-\(index).dat",
                    url: URL(fileURLWithPath: "/tmp/root/match-\(index).dat"),
                    kind: .file,
                    logicalSize: Int64(index),
                    allocatedSize: Int64(index)
                )
            )
        }

        return FileTreeSnapshot(nodes: nodes, rootID: 0)
    }
}
