@testable import Spatia
import SpatiaCore
import XCTest

@MainActor
final class AppModelNavigationTests: XCTestCase {
    func testNavigateToBreadcrumbChangesDisplayRootAndClearsSelection() {
        let model = AppModel()
        let snapshot = FileTreeSnapshot(
            nodes: [
                FileNode(
                    id: 0,
                    parentID: nil,
                    name: "projects",
                    url: URL(fileURLWithPath: "/tmp/projects", isDirectory: true),
                    kind: .directory,
                    logicalSize: 100,
                    allocatedSize: 100,
                    children: [1]
                ),
                FileNode(
                    id: 1,
                    parentID: 0,
                    name: "spatia",
                    url: URL(fileURLWithPath: "/tmp/projects/spatia", isDirectory: true),
                    kind: .directory,
                    logicalSize: 100,
                    allocatedSize: 100,
                    children: [2]
                ),
                FileNode(
                    id: 2,
                    parentID: 1,
                    name: ".build",
                    url: URL(fileURLWithPath: "/tmp/projects/spatia/.build", isDirectory: true),
                    kind: .directory,
                    logicalSize: 80,
                    allocatedSize: 80,
                    children: [3]
                ),
                FileNode(
                    id: 3,
                    parentID: 2,
                    name: "artifact.o",
                    url: URL(fileURLWithPath: "/tmp/projects/spatia/.build/artifact.o"),
                    kind: .file,
                    logicalSize: 80,
                    allocatedSize: 80
                )
            ],
            rootID: 0
        )

        model.result = ScanResult(
            snapshot: snapshot,
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/projects", isDirectory: true),
                fileCount: 1,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 0
            ),
            issues: []
        )
        model.displayRootID = 2
        model.selectedID = 3

        model.navigateToBreadcrumb(1)

        XCTAssertEqual(model.displayRootID, 1)
        XCTAssertNil(model.selectedID)
    }

    func testNavigateToBreadcrumbIgnoresNonAncestorNodes() {
        let model = AppModel()
        let snapshot = FileTreeSnapshot(
            nodes: [
                FileNode(
                    id: 0,
                    parentID: nil,
                    name: "root",
                    url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                    kind: .directory,
                    logicalSize: 10,
                    allocatedSize: 10,
                    children: [1, 2]
                ),
                FileNode(
                    id: 1,
                    parentID: 0,
                    name: "current",
                    url: URL(fileURLWithPath: "/tmp/root/current", isDirectory: true),
                    kind: .directory,
                    logicalSize: 5,
                    allocatedSize: 5,
                    children: []
                ),
                FileNode(
                    id: 2,
                    parentID: 0,
                    name: "sibling",
                    url: URL(fileURLWithPath: "/tmp/root/sibling", isDirectory: true),
                    kind: .directory,
                    logicalSize: 5,
                    allocatedSize: 5,
                    children: []
                )
            ],
            rootID: 0
        )

        model.result = ScanResult(
            snapshot: snapshot,
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 0,
                folderCount: 3,
                logicalBytes: 10,
                allocatedBytes: 10,
                duration: 0
            ),
            issues: []
        )
        model.displayRootID = 1
        model.selectedID = 1

        model.navigateToBreadcrumb(2)

        XCTAssertEqual(model.displayRootID, 1)
        XCTAssertEqual(model.selectedID, 1)
    }

    func testLargestDisplayRootChildrenAreSortedByAllocatedSize() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0

        XCTAssertEqual(model.largestDisplayRootChildren.map(\.id), [2, 1, 3])
        XCTAssertEqual(model.largestDisplayRootChildren.map(\.sizeText), [
            ByteCount.string(50),
            ByteCount.string(30),
            ByteCount.string(20)
        ])
    }

    func testOpenSidebarItemEntersDirectoriesAndClearsSelection() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0
        model.selectedID = 4

        model.openSidebarItem(1)

        XCTAssertEqual(model.displayRootID, 1)
        XCTAssertNil(model.selectedID)
    }

    func testOpenSidebarItemSelectsFiles() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0

        model.openSidebarItem(3)

        XCTAssertEqual(model.displayRootID, 0)
        XCTAssertEqual(model.selectedID, 3)
    }

    func testExpandedTreemapNodeIDsAreEmptyWithoutSelection() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0

        XCTAssertTrue(model.expandedTreemapNodeIDs.isEmpty)
    }

    func testExpandedTreemapNodeIDsIncludeSelectedDirectory() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0
        model.select(1)

        XCTAssertEqual(model.expandedTreemapNodeIDs, [1])
    }

    func testExpandedTreemapNodeIDsUseParentPathForLeafSelection() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0
        model.select(4)

        XCTAssertEqual(model.expandedTreemapNodeIDs, [1])
    }

    func testExpandedTreemapNodeIDsAccumulateAcrossSelections() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0

        model.select(1)
        model.select(2)

        XCTAssertEqual(model.expandedTreemapNodeIDs, [1, 2])
    }

    func testSelectingFilePreservesExistingExpandedDirectoriesAndAddsParentPath() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0

        model.select(2)
        model.select(4)

        XCTAssertEqual(model.expandedTreemapNodeIDs, [1, 2])
    }

    func testClearingSelectionDoesNotClearExpandedTreemapNodeIDs() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0
        model.select(1)

        model.select(nil)

        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.expandedTreemapNodeIDs, [1])
    }

    func testSelectingSyntheticOtherDoesNotClearExpandedTreemapNodeIDs() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0
        model.select(1)

        model.select(syntheticOtherNodeID)

        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.expandedTreemapNodeIDs, [1])
    }

    func testEnterDirectoryClearsExpandedTreemapNodeIDs() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 0
        model.select(1)

        model.enterDirectory(1)

        XCTAssertTrue(model.expandedTreemapNodeIDs.isEmpty)
    }

    func testGoUpClearsExpandedTreemapNodeIDs() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 1
        model.select(4)

        model.goUp()

        XCTAssertEqual(model.displayRootID, 0)
        XCTAssertTrue(model.expandedTreemapNodeIDs.isEmpty)
    }

    func testNavigateToBreadcrumbClearsExpandedTreemapNodeIDs() {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 100,
                allocatedBytes: 100,
                duration: 1
            ),
            issues: []
        )
        model.displayRootID = 1
        model.select(4)

        model.navigateToBreadcrumb(0)

        XCTAssertEqual(model.displayRootID, 0)
        XCTAssertTrue(model.expandedTreemapNodeIDs.isEmpty)
    }

    private func sidebarSnapshot() -> FileTreeSnapshot {
        FileTreeSnapshot(
            nodes: [
                FileNode(
                    id: 0,
                    parentID: nil,
                    name: "root",
                    url: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                    kind: .directory,
                    logicalSize: 100,
                    allocatedSize: 100,
                    children: [1, 2, 3]
                ),
                FileNode(
                    id: 1,
                    parentID: 0,
                    name: "medium",
                    url: URL(fileURLWithPath: "/tmp/root/medium", isDirectory: true),
                    kind: .directory,
                    logicalSize: 30,
                    allocatedSize: 30,
                    children: [4]
                ),
                FileNode(
                    id: 2,
                    parentID: 0,
                    name: "large",
                    url: URL(fileURLWithPath: "/tmp/root/large", isDirectory: true),
                    kind: .directory,
                    logicalSize: 50,
                    allocatedSize: 50,
                    children: [5]
                ),
                FileNode(
                    id: 3,
                    parentID: 0,
                    name: "small.txt",
                    url: URL(fileURLWithPath: "/tmp/root/small.txt"),
                    kind: .file,
                    logicalSize: 20,
                    allocatedSize: 20
                ),
                FileNode(
                    id: 4,
                    parentID: 1,
                    name: "medium.bin",
                    url: URL(fileURLWithPath: "/tmp/root/medium/medium.bin"),
                    kind: .file,
                    logicalSize: 30,
                    allocatedSize: 30
                ),
                FileNode(
                    id: 5,
                    parentID: 2,
                    name: "large.bin",
                    url: URL(fileURLWithPath: "/tmp/root/large/large.bin"),
                    kind: .file,
                    logicalSize: 50,
                    allocatedSize: 50
                )
            ],
            rootID: 0
        )
    }
}
