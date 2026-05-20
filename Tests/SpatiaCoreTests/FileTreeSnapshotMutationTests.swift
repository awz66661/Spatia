import Foundation
import SpatiaCore
import XCTest

final class FileTreeSnapshotMutationTests: XCTestCase {
    func testDetachSubtreeRemovesChildAndUpdatesAncestorSizes() {
        var snapshot = FileTreeSnapshot(
            nodes: [
                FileNode(id: 0, parentID: nil, name: "root", url: URL(fileURLWithPath: "/tmp/root", isDirectory: true), kind: .directory, logicalSize: 100, allocatedSize: 100, children: [1, 2]),
                FileNode(id: 1, parentID: 0, name: "folder", url: URL(fileURLWithPath: "/tmp/root/folder", isDirectory: true), kind: .directory, logicalSize: 70, allocatedSize: 70, children: [3]),
                FileNode(id: 2, parentID: 0, name: "keep.dat", url: URL(fileURLWithPath: "/tmp/root/keep.dat"), kind: .file, logicalSize: 30, allocatedSize: 30),
                FileNode(id: 3, parentID: 1, name: "remove.dat", url: URL(fileURLWithPath: "/tmp/root/folder/remove.dat"), kind: .file, logicalSize: 70, allocatedSize: 70)
            ],
            rootID: 0
        )

        let removed = snapshot.detachSubtree(rootedAt: 1)

        XCTAssertEqual(removed?.fileCount, 1)
        XCTAssertEqual(removed?.folderCount, 1)
        XCTAssertEqual(removed?.allocatedBytes, 70)
        XCTAssertEqual(snapshot.root?.children, [2])
        XCTAssertEqual(snapshot.root?.allocatedSize, 30)
        XCTAssertEqual(snapshot[1]?.scanState, .skipped)
    }

    func testDetachRootIsRefused() {
        var snapshot = FileTreeSnapshot(
            nodes: [
                FileNode(id: 0, parentID: nil, name: "root", url: URL(fileURLWithPath: "/tmp/root", isDirectory: true), kind: .directory)
            ],
            rootID: 0
        )

        XCTAssertNil(snapshot.detachSubtree(rootedAt: 0))
    }

    func testExpandPackageAppendsRemappedChildrenAndUpdatesAncestorSizes() {
        var snapshot = FileTreeSnapshot(
            nodes: [
                FileNode(id: 0, parentID: nil, name: "root", url: URL(fileURLWithPath: "/tmp/root", isDirectory: true), kind: .directory, logicalSize: 100, allocatedSize: 100, children: [1]),
                FileNode(id: 1, parentID: 0, name: "App.app", url: URL(fileURLWithPath: "/tmp/root/App.app", isDirectory: true), kind: .package, logicalSize: 100, allocatedSize: 100)
            ],
            rootID: 0
        )
        let expandedSnapshot = FileTreeSnapshot(
            nodes: [
                FileNode(id: 0, parentID: nil, name: "App.app", url: URL(fileURLWithPath: "/tmp/root/App.app", isDirectory: true), kind: .package, logicalSize: 120, allocatedSize: 120, children: [1]),
                FileNode(id: 1, parentID: 0, name: "Contents", url: URL(fileURLWithPath: "/tmp/root/App.app/Contents", isDirectory: true), kind: .directory, logicalSize: 120, allocatedSize: 120, children: [2]),
                FileNode(id: 2, parentID: 1, name: "payload.dat", url: URL(fileURLWithPath: "/tmp/root/App.app/Contents/payload.dat"), kind: .file, logicalSize: 120, allocatedSize: 120)
            ],
            rootID: 0
        )

        let expanded = snapshot.expandPackageSubtree(rootedAt: 1, with: expandedSnapshot)

        XCTAssertEqual(expanded?.appendedNodeIDs, [2, 3])
        XCTAssertEqual(expanded?.allocatedDelta, 20)
        XCTAssertEqual(snapshot.root?.allocatedSize, 120)
        XCTAssertEqual(snapshot[1]?.children, [2])
        XCTAssertEqual(snapshot[2]?.parentID, 1)
        XCTAssertEqual(snapshot[2]?.children, [3])
        XCTAssertEqual(snapshot[3]?.parentID, 2)
    }
}
