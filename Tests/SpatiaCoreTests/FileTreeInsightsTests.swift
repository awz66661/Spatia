import Foundation
import SpatiaCore
import XCTest

final class FileTreeInsightsTests: XCTestCase {
    func testLargestDescendantFilesRanksLeavesBySizeAndRelativePath() {
        let snapshot = insightSnapshot()

        let usage = snapshot.largestDescendantFiles(rootedAt: 0, limit: 3)

        XCTAssertEqual(usage.map(\.nodeID), [2, 8, 7])
        XCTAssertEqual(usage.map(\.allocatedBytes), [80, 50, 50])
        XCTAssertEqual(usage.map(\.shareOfRoot), [80.0 / 260.0, 50.0 / 260.0, 50.0 / 260.0])
    }

    func testLargestDescendantFilesExcludesZeroSizeAndDirectories() {
        let snapshot = insightSnapshot()

        let usage = snapshot.largestDescendantFiles(rootedAt: 0, limit: 20)

        XCTAssertFalse(usage.contains { $0.nodeID == 1 })
        XCTAssertFalse(usage.contains { $0.nodeID == 4 })
    }

    func testLargestDescendantFilesCanBeScopedToCurrentRoot() {
        let snapshot = insightSnapshot()

        let usage = snapshot.largestDescendantFiles(rootedAt: 1, limit: 10)

        XCTAssertEqual(usage.map(\.nodeID), [8, 7])
        XCTAssertEqual(usage.map(\.shareOfRoot), [0.5, 0.5])
    }

    func testCategoryUsageAggregatesLeafBytesWithoutDoubleCountingDirectories() {
        let snapshot = insightSnapshot()

        let usage = snapshot.categoryUsage(rootedAt: 0)
        let usageByCategory = Dictionary(uniqueKeysWithValues: usage.map { ($0.category, $0) })

        XCTAssertEqual(usage.reduce(Int64(0)) { $0 + $1.allocatedBytes }, 260)
        XCTAssertEqual(usageByCategory[.other]?.allocatedBytes, 100)
        XCTAssertEqual(usageByCategory[.other]?.itemCount, 2)
        XCTAssertEqual(usageByCategory[.video]?.allocatedBytes, 80)
        XCTAssertEqual(usageByCategory[.archive]?.allocatedBytes, 40)
        XCTAssertEqual(usageByCategory[.appPackage]?.allocatedBytes, 30)
        XCTAssertEqual(usageByCategory[.document]?.allocatedBytes, 10)
        XCTAssertEqual(usage.first?.category, .other)
    }

    func testRelativePathUsesCurrentRoot() {
        let snapshot = insightSnapshot()

        XCTAssertEqual(snapshot.relativePath(from: 0, to: 8), "Projects/a.dat")
        XCTAssertEqual(snapshot.relativePath(from: 1, to: 8), "a.dat")
        XCTAssertNil(snapshot.relativePath(from: 6, to: 8))
    }

    private func insightSnapshot() -> FileTreeSnapshot {
        FileTreeSnapshot(
            nodes: [
                FileNode(
                    id: 0,
                    parentID: nil,
                    name: "root",
                    url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                    kind: .directory,
                    logicalSize: 260,
                    allocatedSize: 260,
                    children: [1, 2, 3, 4, 5, 6]
                ),
                FileNode(
                    id: 1,
                    parentID: 0,
                    name: "Projects",
                    url: URL(fileURLWithPath: "/tmp/root/Projects", isDirectory: true),
                    kind: .directory,
                    logicalSize: 100,
                    allocatedSize: 100,
                    children: [7, 8]
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
                    parentID: 0,
                    name: "Archive.zip",
                    url: URL(fileURLWithPath: "/tmp/root/Archive.zip"),
                    kind: .file,
                    logicalSize: 40,
                    allocatedSize: 40
                ),
                FileNode(
                    id: 4,
                    parentID: 0,
                    name: "empty.dat",
                    url: URL(fileURLWithPath: "/tmp/root/empty.dat"),
                    kind: .file,
                    logicalSize: 0,
                    allocatedSize: 0
                ),
                FileNode(
                    id: 5,
                    parentID: 0,
                    name: "Sample.app",
                    url: URL(fileURLWithPath: "/tmp/root/Sample.app", isDirectory: true),
                    kind: .package,
                    logicalSize: 30,
                    allocatedSize: 30
                ),
                FileNode(
                    id: 6,
                    parentID: 0,
                    name: "Docs",
                    url: URL(fileURLWithPath: "/tmp/root/Docs", isDirectory: true),
                    kind: .directory,
                    logicalSize: 10,
                    allocatedSize: 10,
                    children: [9]
                ),
                FileNode(
                    id: 7,
                    parentID: 1,
                    name: "b.dat",
                    url: URL(fileURLWithPath: "/tmp/root/Projects/b.dat"),
                    kind: .file,
                    logicalSize: 50,
                    allocatedSize: 50
                ),
                FileNode(
                    id: 8,
                    parentID: 1,
                    name: "a.dat",
                    url: URL(fileURLWithPath: "/tmp/root/Projects/a.dat"),
                    kind: .file,
                    logicalSize: 50,
                    allocatedSize: 50
                ),
                FileNode(
                    id: 9,
                    parentID: 6,
                    name: "note.md",
                    url: URL(fileURLWithPath: "/tmp/root/Docs/note.md"),
                    kind: .file,
                    logicalSize: 10,
                    allocatedSize: 10
                )
            ],
            rootID: 0
        )
    }
}
