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

    func testRescanCurrentSourceWithoutURLKeepsScanIdle() {
        let model = AppModel()
        model.statusText = "Ready"

        model.rescanCurrentSource()

        XCTAssertFalse(model.isScanning)
        XCTAssertNil(model.currentScanURL)
        XCTAssertEqual(model.statusText, "Choose a folder to scan.")
    }

    func testRescanCurrentSourceScansCurrentURL() async throws {
        let model = AppModel()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "spatia".write(
            to: root.appendingPathComponent("fixture.txt"),
            atomically: true,
            encoding: .utf8
        )
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        model.currentScanURL = root

        model.rescanCurrentSource()
        await waitForScanResult(model)

        XCTAssertEqual(model.currentScanURL?.path, root.path)
        XCTAssertEqual(model.result?.summary.rootURL.path, root.path)
        XCTAssertEqual(model.result?.summary.fileCount, 1)
        XCTAssertFalse(model.isScanning)
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

    func testSelectedNodeDetailBlocksHomeRootTrash() {
        let model = AppModel()
        let home = FileManager.default.homeDirectoryForCurrentUser
        model.result = ScanResult(
            snapshot: FileTreeSnapshot(
                nodes: [
                    FileNode(
                        id: 0,
                        parentID: nil,
                        name: "Users",
                        url: URL(fileURLWithPath: "/Users", isDirectory: true),
                        kind: .directory,
                        logicalSize: 100,
                        allocatedSize: 100,
                        children: [1]
                    ),
                    FileNode(
                        id: 1,
                        parentID: 0,
                        name: home.lastPathComponent,
                        url: home,
                        kind: .directory,
                        logicalSize: 100,
                        allocatedSize: 100
                    )
                ],
                rootID: 0
            ),
            summary: ScanSummary(rootURL: URL(fileURLWithPath: "/Users", isDirectory: true), fileCount: 0, folderCount: 2, logicalBytes: 100, allocatedBytes: 100, duration: 0),
            issues: []
        )
        model.displayRootID = 0
        model.selectedID = 1

        let detail = model.selectedNodeDetail

        XCTAssertEqual(detail?.canMoveToTrash, false)
        XCTAssertTrue(detail?.trashDisabledReason?.contains("home folder") == true)
    }

    func testMoveSelectedItemToTrashConfirmsAndReconcilesSnapshot() async {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true), fileCount: 2, folderCount: 3, logicalBytes: 100, allocatedBytes: 100, duration: 1),
            issues: []
        )
        model.displayRootID = 0
        model.selectedID = 3

        var confirmation: TrashConfirmation?
        var movedURL: URL?
        model.confirmMoveToTrash = {
            confirmation = $0
            return true
        }
        model.moveToTrash = {
            movedURL = $0
            return .moved(resultingURL: URL(fileURLWithPath: "/Users/example/.Trash/small.txt"))
        }

        await model.moveSelectedItemToTrash()

        XCTAssertEqual(confirmation?.name, "small.txt")
        XCTAssertEqual(confirmation?.itemCount, 1)
        XCTAssertEqual(movedURL?.path, "/tmp/root/small.txt")
        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.result?.snapshot.root?.children, [1, 2])
        XCTAssertEqual(model.result?.summary.fileCount, 1)
        XCTAssertEqual(model.result?.summary.allocatedBytes, 80)
        XCTAssertEqual(model.statusText, "Moved small.txt to Trash.")
    }

    func testMoveSelectedDirectoryToTrashIncludesWarningsAndCountsSubtree() async {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true), fileCount: 2, folderCount: 3, logicalBytes: 100, allocatedBytes: 100, duration: 1),
            issues: []
        )
        model.displayRootID = 0
        model.selectedID = 1

        var confirmation: TrashConfirmation?
        model.confirmMoveToTrash = {
            confirmation = $0
            return true
        }
        model.moveToTrash = { _ in .moved(resultingURL: nil) }

        await model.moveSelectedItemToTrash()

        XCTAssertEqual(confirmation?.itemCount, 2)
        XCTAssertTrue(confirmation?.warnings.contains { $0.contains("folder") } == true)
        XCTAssertEqual(model.result?.snapshot.root?.children, [2, 3])
        XCTAssertEqual(model.result?.summary.folderCount, 2)
        XCTAssertEqual(model.result?.summary.fileCount, 1)
    }

    func testMoveSelectedItemToTrashCancellationDoesNotChangeSnapshot() async {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true), fileCount: 2, folderCount: 3, logicalBytes: 100, allocatedBytes: 100, duration: 1),
            issues: []
        )
        model.displayRootID = 0
        model.selectedID = 3
        model.confirmMoveToTrash = { _ in true }
        model.moveToTrash = { _ in .cancelled }

        await model.moveSelectedItemToTrash()

        XCTAssertEqual(model.result?.snapshot.root?.children, [1, 2, 3])
        XCTAssertEqual(model.selectedID, 3)
        XCTAssertEqual(model.statusText, "Move to Trash cancelled.")
    }

    func testMoveSelectedItemToTrashPermissionFailureDoesNotChangeSnapshot() async {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true), fileCount: 2, folderCount: 3, logicalBytes: 100, allocatedBytes: 100, duration: 1),
            issues: []
        )
        model.displayRootID = 0
        model.selectedID = 3
        model.confirmMoveToTrash = { _ in true }
        model.moveToTrash = { _ in .permissionDenied("No permission") }

        await model.moveSelectedItemToTrash()

        XCTAssertEqual(model.result?.snapshot.root?.children, [1, 2, 3])
        XCTAssertEqual(model.selectedID, 3)
        XCTAssertTrue(model.statusText.contains("Permission denied"))
    }

    func testMoveSelectedItemToTrashPartialFailureStillReconciles() async {
        let model = AppModel()
        model.result = ScanResult(
            snapshot: sidebarSnapshot(),
            summary: ScanSummary(rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true), fileCount: 2, folderCount: 3, logicalBytes: 100, allocatedBytes: 100, duration: 1),
            issues: []
        )
        model.displayRootID = 0
        model.selectedID = 3
        model.confirmMoveToTrash = { _ in true }
        model.moveToTrash = { _ in .partialFailure("Finder reported a warning") }

        await model.moveSelectedItemToTrash()

        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.result?.snapshot.root?.children, [1, 2])
        XCTAssertTrue(model.statusText.contains("partial failure"))
    }

    private func waitForScanResult(_ model: AppModel, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while model.result == nil && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
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
