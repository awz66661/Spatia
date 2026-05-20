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
}
