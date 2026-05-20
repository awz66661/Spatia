@testable import Spatia
import Foundation
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

    func testLargestDisplayRootChildrenAreSortedByAllocatedSize() async {
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

        await waitForSidebarDerivedState(model, mode: .here) {
            model.largestDisplayRootChildren.count == 3
        }

        XCTAssertEqual(model.largestDisplayRootChildren.map(\.id), [2, 1, 3])
        XCTAssertEqual(model.largestDisplayRootChildren.map(\.sizeText), [
            ByteCount.string(50),
            ByteCount.string(30),
            ByteCount.string(20)
        ])
    }

    func testLargestDescendantFileSummariesAreScopedAndSortedByAllocatedSize() async {
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
        model.sidebarInsightMode = .files

        await waitForSidebarDerivedState(model, mode: .files) {
            model.largestDescendantFileSummaries.count == 3
        }

        XCTAssertEqual(model.largestDescendantFileSummaries.map(\.id), [5, 4, 3])
        XCTAssertEqual(model.largestDescendantFileSummaries.map(\.relativePath), [
            "large/large.bin",
            "medium/medium.bin",
            "small.txt"
        ])
        XCTAssertEqual(model.largestDescendantFileSummaries.map(\.shareText), ["50%", "30%", "20%"])

        model.displayRootID = 1

        await waitForSidebarDerivedState(model, mode: .files) {
            model.largestDescendantFileSummaries.map(\.id) == [4]
        }

        XCTAssertEqual(model.largestDescendantFileSummaries.map(\.id), [4])
        XCTAssertEqual(model.largestDescendantFileSummaries.first?.shareText, "100%")
    }

    func testCategoryUsageSummariesAreScopedToDisplayRoot() async {
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
        model.sidebarInsightMode = .types

        await waitForSidebarDerivedState(model, mode: .types) {
            !model.categoryUsageSummaries.isEmpty
        }

        let rootUsage = Dictionary(uniqueKeysWithValues: model.categoryUsageSummaries.map { ($0.category, $0) })
        XCTAssertEqual(model.categoryUsageSummaries.reduce(Int64(0)) { $0 + $1.allocatedBytes }, 100)
        XCTAssertEqual(rootUsage[.other]?.allocatedBytes, 80)
        XCTAssertEqual(rootUsage[.other]?.itemCount, 2)
        XCTAssertEqual(rootUsage[.other]?.shareText, "80%")
        XCTAssertEqual(rootUsage[.document]?.allocatedBytes, 20)
        XCTAssertEqual(rootUsage[.document]?.itemCount, 1)
        XCTAssertEqual(rootUsage[.document]?.shareText, "20%")

        model.displayRootID = 2

        await waitForSidebarDerivedState(model, mode: .types) {
            model.categoryUsageSummaries.first?.allocatedBytes == 50
        }

        XCTAssertEqual(model.categoryUsageSummaries.first?.allocatedBytes, 50)
        XCTAssertEqual(model.categoryUsageSummaries.first?.itemCount, 1)
    }

    func testSidebarInsightsRefreshWhenSnapshotChanges() async {
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
        model.sidebarInsightMode = .files

        await waitForSidebarDerivedState(model, mode: .files) {
            model.largestDescendantFileSummaries.first?.id == 5
        }
        XCTAssertEqual(model.largestDescendantFileSummaries.first?.id, 5)

        model.sidebarInsightMode = .types
        await waitForSidebarDerivedState(model, mode: .types) {
            model.categoryUsageSummaries.first?.allocatedBytes == 80
        }
        XCTAssertEqual(model.categoryUsageSummaries.first?.allocatedBytes, 80)

        var snapshot = sidebarSnapshot()
        snapshot.nodes[0].logicalSize = 160
        snapshot.nodes[0].allocatedSize = 160
        snapshot.nodes[1].logicalSize = 90
        snapshot.nodes[1].allocatedSize = 90
        snapshot.nodes[4].logicalSize = 90
        snapshot.nodes[4].allocatedSize = 90
        model.result = ScanResult(
            snapshot: snapshot,
            summary: ScanSummary(
                rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true),
                fileCount: 2,
                folderCount: 3,
                logicalBytes: 160,
                allocatedBytes: 160,
                duration: 1
            ),
            issues: []
        )

        model.sidebarInsightMode = .files
        await waitForSidebarDerivedState(model, mode: .files) {
            model.largestDescendantFileSummaries.first?.id == 4
        }
        XCTAssertEqual(model.largestDescendantFileSummaries.first?.id, 4)

        model.sidebarInsightMode = .types
        await waitForSidebarDerivedState(model, mode: .types) {
            Dictionary(uniqueKeysWithValues: model.categoryUsageSummaries.map { ($0.category, $0) })[.other]?.allocatedBytes == 140
        }
        let usage = Dictionary(uniqueKeysWithValues: model.categoryUsageSummaries.map { ($0.category, $0) })
        XCTAssertEqual(usage[.other]?.allocatedBytes, 140)
    }

    func testOpenInsightItemSelectsDeepNodeAndExpandsParentPathWithoutEnteringDirectory() {
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

        model.openInsightItem(5)

        XCTAssertEqual(model.displayRootID, 0)
        XCTAssertEqual(model.selectedID, 5)
        XCTAssertEqual(model.expandedTreemapNodeIDs, [2])
    }

    func testSearchResultsAreScopedToDisplayRootAndOpenBySelectingNode() async {
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
        model.searchQuery = "large"

        await waitForSearchResults(model, query: "large") {
            model.searchResultSummaries.map(\.id) == [2, 5]
        }

        XCTAssertEqual(model.searchResultSummaries.map(\.id), [2, 5])

        model.openInsightItem(5)

        XCTAssertEqual(model.selectedID, 5)
        XCTAssertEqual(model.expandedTreemapNodeIDs, [2])

        model.displayRootID = 1

        await waitForSearchResults(model, query: "large") {
            model.searchResultSummaries.isEmpty
        }

        XCTAssertTrue(model.searchResultSummaries.isEmpty)
    }

    func testSearchDebouncesAndOnlyPublishesLatestQuery() async {
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

        model.searchQuery = "large"
        XCTAssertTrue(model.searchState.isLoading)
        XCTAssertTrue(model.searchResultSummaries.isEmpty)

        model.searchQuery = "small"

        await waitForSearchResults(model, query: "small") {
            model.searchResultSummaries.map(\.id) == [3]
        }

        XCTAssertEqual(model.searchResultSummaries.map(\.id), [3])
        XCTAssertEqual(model.searchState.query, "small")
    }

    func testStartingScanCancelsPendingSearchWriteback() async {
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
        model.searchQuery = "large"
        model.scanEvents = { _, options, _ in
            while options.cancellationSource?.isCancelled == false {
                Thread.sleep(forTimeInterval: 0.01)
            }
        }

        model.scan(URL(fileURLWithPath: "/tmp/slow-root", isDirectory: true))
        try? await Task.sleep(nanoseconds: 320_000_000)

        XCTAssertTrue(model.searchResultSummaries.isEmpty)
        XCTAssertEqual(model.searchState.query, "large")

        model.cancelScan()
    }

    func testSidebarDerivedStateOnlyComputesActiveMode() async {
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
        model.sidebarInsightMode = .files

        await waitForSidebarDerivedState(model, mode: .files) {
            model.largestDescendantFileSummaries.count == 3
        }

        XCTAssertTrue(model.largestDisplayRootChildren.isEmpty)
        XCTAssertTrue(model.categoryUsageSummaries.isEmpty)
        XCTAssertEqual(model.largestDescendantFileSummaries.map(\.id), [5, 4, 3])
    }

    func testSelectedNodeDetailIncludesUsageShares() {
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
        model.displayRootID = 2
        model.selectedID = 5

        XCTAssertEqual(model.selectedNodeDetail?.shareOfCurrentView, "100%")
        XCTAssertEqual(model.selectedNodeDetail?.shareOfScan, "50%")
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

    func testQuickLookUnavailableUpdatesStatusWithoutOpeningFile() {
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
        model.selectedID = 3

        var previewedURL: URL?
        model.quickLookFile = {
            previewedURL = $0
            return .unavailable
        }

        model.quickLookSelected()

        XCTAssertEqual(previewedURL?.path, "/tmp/root/small.txt")
        XCTAssertEqual(model.statusText, "Quick Look is unavailable for small.txt.")
    }

    func testSelectedItemCommandAvailabilityReflectsSelection() {
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

        XCTAssertFalse(model.canEnterSelectedContainer)
        XCTAssertFalse(model.canQuickLookSelected)
        XCTAssertFalse(model.canCopySelectedPath)

        model.selectedID = 1

        XCTAssertTrue(model.canEnterSelectedContainer)
        XCTAssertFalse(model.canQuickLookSelected)
        XCTAssertTrue(model.canCopySelectedPath)
        XCTAssertTrue(model.canRevealSelected)
        XCTAssertTrue(model.canMoveSelectedToTrash)

        model.selectedID = 3

        XCTAssertFalse(model.canEnterSelectedContainer)
        XCTAssertTrue(model.canQuickLookSelected)
        XCTAssertTrue(model.canCopySelectedPath)
    }

    func testExpandSelectedPackageAppendsChildrenAndKeepsPackageSelected() async {
        let model = AppModel()
        let packageURL = URL(fileURLWithPath: "/tmp/root/Sample.app", isDirectory: true)
        model.result = ScanResult(
            snapshot: FileTreeSnapshot(
                nodes: [
                    FileNode(id: 0, parentID: nil, name: "root", url: URL(fileURLWithPath: "/tmp/root", isDirectory: true), kind: .directory, logicalSize: 100, allocatedSize: 100, children: [1]),
                    FileNode(id: 1, parentID: 0, name: "Sample.app", url: packageURL, kind: .package, logicalSize: 100, allocatedSize: 100)
                ],
                rootID: 0
            ),
            summary: ScanSummary(rootURL: URL(fileURLWithPath: "/tmp/root", isDirectory: true), fileCount: 1, folderCount: 2, logicalBytes: 100, allocatedBytes: 100, duration: 1),
            issues: []
        )
        model.displayRootID = 0
        model.selectedID = 1

        let scanRecorder = ScanPackageRecorder()
        model.scanExpandedPackage = { url, options in
            scanRecorder.record(url: url, options: options)
            return ScanResult(
                snapshot: FileTreeSnapshot(
                    nodes: [
                        FileNode(id: 0, parentID: nil, name: "Sample.app", url: packageURL, kind: .package, logicalSize: 120, allocatedSize: 120, children: [1]),
                        FileNode(id: 1, parentID: 0, name: "Contents", url: packageURL.appendingPathComponent("Contents", isDirectory: true), kind: .directory, logicalSize: 120, allocatedSize: 120, children: [2]),
                        FileNode(id: 2, parentID: 1, name: "payload.dat", url: packageURL.appendingPathComponent("Contents/payload.dat"), kind: .file, logicalSize: 120, allocatedSize: 120)
                    ],
                    rootID: 0
                ),
                summary: ScanSummary(rootURL: packageURL, fileCount: 1, folderCount: 2, logicalBytes: 120, allocatedBytes: 120, duration: 0),
                issues: []
            )
        }

        await model.expandSelectedPackage()

        XCTAssertEqual(scanRecorder.scannedURL, packageURL)
        XCTAssertTrue(scanRecorder.usedOptions?.expandPackages == true)
        XCTAssertEqual(model.selectedID, 1)
        XCTAssertEqual(model.result?.summary.allocatedBytes, 120)
        XCTAssertEqual(model.result?.snapshot[1]?.children, [2])
        XCTAssertEqual(model.result?.snapshot[2]?.parentID, 1)
        XCTAssertEqual(model.expandedTreemapNodeIDs, [1])
        XCTAssertEqual(model.statusText, "Expanded Sample.app.")
    }

    func testCopySelectedPathUsesSelectedURLAndUpdatesStatus() {
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
        model.selectedID = 3

        var copiedURL: URL?
        model.copyPathToPasteboard = {
            copiedURL = $0
        }

        model.copySelectedPath()

        XCTAssertEqual(copiedURL?.path, "/tmp/root/small.txt")
        XCTAssertEqual(model.statusText, "Copied path for small.txt.")
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

    func testSelectedPathNodeIDsFollowSelectionWithinDisplayRoot() {
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

        XCTAssertEqual(model.selectedPathNodeIDs, [0, 1, 4])

        model.displayRootID = 1

        XCTAssertEqual(model.selectedPathNodeIDs, [1, 4])
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

    func testSelectingSyntheticOtherShowsReadOnlyDetail() {
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

        model.selectSyntheticOther(size: 40)

        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.expandedTreemapNodeIDs, [1])
        XCTAssertEqual(model.selectedOtherDetail?.diskUsage, ByteCount.string(40))
        XCTAssertEqual(model.selectedOtherDetail?.displayRootName, "root")

        model.select(nil)

        XCTAssertNil(model.selectedOtherDetail)
    }

    func testHoverTreemapNodeShowsSizePathAndRestoresPreviousStatus() {
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
        model.statusText = "Ready"

        model.hoverTreemapNode(4)

        XCTAssertTrue(model.statusText.contains("medium.bin"))
        XCTAssertTrue(model.statusText.contains(ByteCount.string(30)))
        XCTAssertTrue(model.statusText.contains("/tmp/root/medium/medium.bin"))

        model.hoverTreemapNode(nil)

        XCTAssertEqual(model.statusText, "Ready")
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

    func testScanPreferencesBuildScannerOptions() {
        let cancellationSource = ScanCancellationSource()
        let preferences = ScanPreferences(
            expandPackages: true,
            includeHiddenFiles: false,
            maxDepth: 2
        )

        let options = preferences.scanOptions(cancellationSource: cancellationSource)

        XCTAssertTrue(options.expandPackages)
        XCTAssertFalse(options.includeHiddenFiles)
        XCTAssertEqual(options.maxDepth, 2)
        XCTAssertTrue(options.cancellationSource === cancellationSource)
    }

    func testScanUsesCurrentPreferences() async throws {
        let model = AppModel()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try "visible".write(
            to: root.appendingPathComponent("visible.txt"),
            atomically: true,
            encoding: .utf8
        )
        try "hidden".write(
            to: root.appendingPathComponent(".hidden.txt"),
            atomically: true,
            encoding: .utf8
        )
        let nested = root.appendingPathComponent("nested", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        try "deep".write(
            to: nested.appendingPathComponent("deep.txt"),
            atomically: true,
            encoding: .utf8
        )
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        model.setIncludeHiddenFiles(false)
        model.setMaxDepth(1)

        model.scan(root)
        await waitForScanResult(model)

        XCTAssertEqual(model.result?.summary.fileCount, 1)
        XCTAssertEqual(model.result?.summary.folderCount, 2)
        XCTAssertEqual(model.result?.summary.logicalBytes, 7)
        XCTAssertEqual(model.result?.snapshot.root?.children.count, 2)
    }

    func testStartingNewScanClearsPreviousResultImmediately() async throws {
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
        model.selectedID = 3

        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        model.scan(root)

        XCTAssertTrue(model.isScanning)
        XCTAssertNil(model.result)
        XCTAssertNil(model.displayRootID)
        XCTAssertNil(model.selectedID)
        XCTAssertEqual(model.currentScanURL?.path, root.path)

        await waitForScanResult(model)
    }

    func testCancelScanStopsCurrentScanAndIgnoresLateResult() async throws {
        let model = AppModel()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        model.scanEvents = { url, options, receive in
            receive(.started(root: url.standardizedFileURL, startedAt: Date()))
            while options.cancellationSource?.isCancelled == false {
                Thread.sleep(forTimeInterval: 0.001)
            }

            let node = FileNode(
                id: 0,
                parentID: nil,
                name: url.lastPathComponent,
                url: url,
                kind: .directory,
                logicalSize: 1,
                allocatedSize: 1
            )
            receive(.nodeDiscovered(node))
            receive(
                .finished(
                    ScanSummary(
                        rootURL: url,
                        fileCount: 1,
                        folderCount: 1,
                        logicalBytes: 1,
                        allocatedBytes: 1,
                        duration: 0
                    )
                )
            )
        }

        model.scan(root)

        XCTAssertTrue(model.isScanning)

        model.cancelScan()
        try? await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertFalse(model.isScanning)
        XCTAssertNil(model.result)
        XCTAssertNil(model.selectedID)
        XCTAssertNil(model.displayRootID)
        XCTAssertEqual(model.statusText, "Cancelled scanning \(root.lastPathComponent).")
    }

    func testScanPublishesProgressiveSnapshotBeforeFinish() async throws {
        let model = AppModel()
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer {
            try? FileManager.default.removeItem(at: root)
        }

        model.scanEvents = { url, _, receive in
            receive(.started(root: url.standardizedFileURL, startedAt: Date()))
            let scanningRoot = FileNode(
                id: 0,
                parentID: nil,
                name: url.lastPathComponent,
                url: url,
                kind: .directory,
                logicalSize: 0,
                allocatedSize: 0,
                scanState: .scanning
            )
            receive(.nodeDiscovered(scanningRoot))
            Thread.sleep(forTimeInterval: 0.35)
            var completeRoot = scanningRoot
            completeRoot.scanState = .complete
            receive(.directoryFinished(completeRoot))
            receive(
                .finished(
                    ScanSummary(
                        rootURL: url,
                        fileCount: 0,
                        folderCount: 1,
                        logicalBytes: 0,
                        allocatedBytes: 0,
                        duration: 0.35
                    )
                )
            )
        }

        model.scan(root)
        await waitForProgressiveSnapshot(model)

        XCTAssertTrue(model.isScanning)
        XCTAssertNil(model.result)
        XCTAssertEqual(model.snapshot?.rootID, 0)
        XCTAssertEqual(model.displayRootID, 0)

        await waitForScanResult(model)

        XCTAssertFalse(model.isScanning)
        XCTAssertEqual(model.result?.summary.folderCount, 1)
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

    private func waitForProgressiveSnapshot(_ model: AppModel, timeout: TimeInterval = 2) async {
        let deadline = Date().addingTimeInterval(timeout)
        while (model.snapshot == nil || model.result != nil) && Date() < deadline {
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func waitForSidebarDerivedState(
        _ model: AppModel,
        mode: SidebarInsightMode,
        timeout: TimeInterval = 2,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if model.sidebarDerivedState.mode == mode,
               !model.sidebarDerivedState.isLoading,
               condition() {
                return
            }
            try? await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    private func waitForSearchResults(
        _ model: AppModel,
        query: String,
        timeout: TimeInterval = 2,
        condition: @escaping () -> Bool
    ) async {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if model.searchState.query == query,
               !model.searchState.isLoading,
               condition() {
                return
            }
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

    private final class ScanPackageRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var recordedURL: URL?
        private var recordedOptions: ScanOptions?

        var scannedURL: URL? {
            lock.lock()
            defer { lock.unlock() }
            return recordedURL
        }

        var usedOptions: ScanOptions? {
            lock.lock()
            defer { lock.unlock() }
            return recordedOptions
        }

        func record(url: URL, options: ScanOptions) {
            lock.lock()
            defer { lock.unlock() }
            recordedURL = url
            recordedOptions = options
        }
    }
}
