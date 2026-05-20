import Darwin
import Foundation
@testable import SpatiaCore
import XCTest

final class FileScannerTests: XCTestCase {
    func testAggregatesNestedFileSizesAndCounts() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        try fixture.file("alpha.bin", bytes: 4)
        try fixture.file("nested/beta.bin", bytes: 6)

        let result = FileScanner().scan(root: fixture.rootURL)

        XCTAssertEqual(result.summary.fileCount, 2)
        XCTAssertEqual(result.summary.folderCount, 2)
        XCTAssertEqual(result.summary.logicalBytes, 10)
        XCTAssertEqual(result.snapshot.root?.logicalSize, 10)
        XCTAssertTrue(result.issues.isEmpty)
    }

    func testScanEventsCanBeAccumulatedIntoFinalResult() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        try fixture.file("alpha.bin", bytes: 4)
        try fixture.file("nested/beta.bin", bytes: 6)

        var events: [ScanEvent] = []
        var accumulator = ScanAccumulator()
        FileScanner().scanEvents(root: fixture.rootURL) { event in
            events.append(event)
            accumulator.consume(event)
        }

        let result = try XCTUnwrap(accumulator.result)
        let root = try XCTUnwrap(result.snapshot.root)

        XCTAssertEqual(result.summary.fileCount, 2)
        XCTAssertEqual(result.summary.folderCount, 2)
        XCTAssertEqual(result.summary.logicalBytes, 10)
        XCTAssertEqual(root.logicalSize, 10)
        XCTAssertTrue(events.contains { event in
            if case let .started(rootURL, _) = event {
                return rootURL == fixture.rootURL.standardizedFileURL
            }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case let .directoryFinished(node) = event {
                return node.id == root.id && node.scanState == .complete
            }
            return false
        })
        XCTAssertTrue(events.contains { event in
            if case let .finished(summary) = event {
                return summary.fileCount == 2 && summary.logicalBytes == 10
            }
            return false
        })
    }

    func testCanExcludeHiddenFiles() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        try fixture.file("visible.txt", bytes: 3)
        try fixture.file(".hidden.txt", bytes: 9)

        let result = FileScanner(options: ScanOptions(includeHiddenFiles: false)).scan(root: fixture.rootURL)
        let root = try XCTUnwrap(result.snapshot.root)
        let names = Set(result.snapshot.children(of: root.id).map(\.name))

        XCTAssertEqual(result.summary.fileCount, 1)
        XCTAssertEqual(result.summary.logicalBytes, 3)
        XCTAssertEqual(names, ["visible.txt"])
    }

    func testReadsTypeIdentifierWhenAvailable() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        try fixture.file("photo.png", bytes: 8)

        let result = FileScanner().scan(root: fixture.rootURL)
        let root = try XCTUnwrap(result.snapshot.root)
        let image = try XCTUnwrap(fixture.child(named: "photo.png", in: root, snapshot: result.snapshot))

        XCTAssertNotNil(image.typeIdentifier)
    }

    func testResourceValueFailureProducesUnreadableIssueAndFailedNode() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        let unreadable = try fixture.file("metadata-fails.dat", bytes: 8).standardizedFileURL
        let scanner = FileScanner(resourceValuesProvider: { url, keys in
            if url.standardizedFileURL == unreadable {
                throw NSError(
                    domain: NSCocoaErrorDomain,
                    code: 12_345,
                    userInfo: [NSLocalizedDescriptionKey: "metadata unavailable"]
                )
            }
            return try url.resourceValues(forKeys: keys)
        })

        let result = scanner.scan(root: fixture.rootURL)
        let root = try XCTUnwrap(result.snapshot.root)
        let failedNode = try XCTUnwrap(fixture.child(named: "metadata-fails.dat", in: root, snapshot: result.snapshot))

        XCTAssertEqual(result.summary.fileCount, 0)
        XCTAssertEqual(result.summary.logicalBytes, 0)
        XCTAssertTrue(result.issues.contains { $0.url.standardizedFileURL == unreadable && $0.kind == .unreadable })
        XCTAssertEqual(failedNode.scanState, .failed)
        XCTAssertEqual(failedNode.logicalSize, 0)
        XCTAssertEqual(failedNode.allocatedSize, 0)
    }

    func testMaxDepthSkipsDescendantsBeyondLimit() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        try fixture.file("level1/level2/deep.dat", bytes: 12)

        let result = FileScanner(options: ScanOptions(maxDepth: 1)).scan(root: fixture.rootURL)
        let root = try XCTUnwrap(result.snapshot.root)
        let level1 = try XCTUnwrap(fixture.child(named: "level1", in: root, snapshot: result.snapshot))

        XCTAssertEqual(result.summary.fileCount, 0)
        XCTAssertEqual(result.summary.folderCount, 2)
        XCTAssertEqual(result.summary.logicalBytes, 0)
        XCTAssertTrue(level1.children.isEmpty)
    }

    func testPackagesAreOpaqueByDefaultButStillMeasured() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        try fixture.file("Sample.app/Contents/payload.dat", bytes: 7)

        let result = FileScanner(options: ScanOptions(expandPackages: false)).scan(root: fixture.rootURL)
        let root = try XCTUnwrap(result.snapshot.root)
        let package = try XCTUnwrap(fixture.child(named: "Sample.app", in: root, snapshot: result.snapshot))
        guard package.kind == .package else {
            throw XCTSkip("This platform did not classify .app directories as packages.")
        }

        XCTAssertEqual(package.logicalSize, 7)
        XCTAssertTrue(package.children.isEmpty)
        XCTAssertEqual(result.summary.fileCount, 1)
        XCTAssertEqual(result.summary.folderCount, 3)
        XCTAssertEqual(result.summary.logicalBytes, 7)
    }

    func testPackagesCanBeExpanded() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        try fixture.file("Sample.app/Contents/payload.dat", bytes: 7)

        let result = FileScanner(options: ScanOptions(expandPackages: true)).scan(root: fixture.rootURL)
        let root = try XCTUnwrap(result.snapshot.root)
        let package = try XCTUnwrap(fixture.child(named: "Sample.app", in: root, snapshot: result.snapshot))
        guard package.kind == .package else {
            throw XCTSkip("This platform did not classify .app directories as packages.")
        }
        let contents = try XCTUnwrap(fixture.child(named: "Contents", in: package, snapshot: result.snapshot))

        XCTAssertFalse(package.children.isEmpty)
        XCTAssertNotNil(fixture.child(named: "payload.dat", in: contents, snapshot: result.snapshot))
        XCTAssertEqual(result.summary.fileCount, 1)
        XCTAssertEqual(result.summary.folderCount, 3)
        XCTAssertEqual(result.summary.logicalBytes, 7)
    }

    func testSymlinkIsClassifiedWithoutFollowingTarget() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        let target = try fixture.file("target.dat", bytes: 5)
        do {
            try fixture.symlink("target-link", destination: target)
        } catch {
            throw XCTSkip("Symlink creation is unavailable in this environment: \(error.localizedDescription)")
        }

        let result = FileScanner().scan(root: fixture.rootURL)
        let root = try XCTUnwrap(result.snapshot.root)
        let link = try XCTUnwrap(fixture.child(named: "target-link", in: root, snapshot: result.snapshot))

        XCTAssertEqual(link.kind, .symlink)
        XCTAssertTrue(link.children.isEmpty)
        XCTAssertEqual(result.summary.fileCount, 2)
    }

    func testPreCancelledScanDoesNotDescendIntoFixture() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        for index in 0..<10 {
            try fixture.file("folder-\(index)/nested-\(index)/payload.dat", bytes: 5)
        }

        let cancellationSource = ScanCancellationSource()
        cancellationSource.cancel()

        let result = FileScanner(
            options: ScanOptions(cancellationSource: cancellationSource)
        ).scan(root: fixture.rootURL)
        let root = try XCTUnwrap(result.snapshot.root)

        XCTAssertEqual(result.summary.fileCount, 0)
        XCTAssertEqual(result.summary.folderCount, 0)
        XCTAssertTrue(root.children.isEmpty)
        XCTAssertEqual(root.scanState, .skipped)
    }

    func testUnreadableDirectoryProducesPermissionIssueWhenSupported() throws {
        let fixture = try ScannerFixture()
        defer { try? fixture.tearDown() }

        let locked = try fixture.directory("locked")
        try fixture.file("locked/secret.dat", bytes: 5)

        let chmodResult = chmod(locked.path, 0)
        guard chmodResult == 0 else {
            throw XCTSkip("Could not remove fixture permissions.")
        }
        defer { _ = chmod(locked.path, S_IRWXU) }

        let result = FileScanner().scan(root: fixture.rootURL)
        guard result.issues.contains(where: { $0.url == locked && $0.kind == .permissionDenied }) else {
            throw XCTSkip("This environment allowed reading the chmod 000 fixture directory.")
        }
        let root = try XCTUnwrap(result.snapshot.root)
        let lockedNode = try XCTUnwrap(fixture.child(named: "locked", in: root, snapshot: result.snapshot))

        XCTAssertEqual(result.summary.fileCount, 0)
        XCTAssertTrue(lockedNode.flags.contains(.permissionDenied))
        XCTAssertEqual(lockedNode.scanState, .failed)
        XCTAssertTrue(lockedNode.children.isEmpty)
    }
}
