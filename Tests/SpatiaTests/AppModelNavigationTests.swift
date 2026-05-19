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
}
