import Darwin
import Foundation
import SpatiaCore
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

        XCTAssertEqual(result.summary.fileCount, 0)
    }
}
