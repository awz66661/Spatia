import Foundation
import SpatiaCore

private struct BenchmarkRow: Encodable {
    var fixture: String
    var fileCount: Int
    var folderCount: Int
    var logicalBytes: Int64
    var allocatedBytes: Int64
    var durationMilliseconds: Double
    var eventCount: Int
    var firstSnapshotMilliseconds: Double?
    var searchIndexMilliseconds: Double
    var searchQueryMilliseconds: Double
    var categoryUsageMilliseconds: Double
    var largestFilesMilliseconds: Double
    var issueCount: Int
}

private struct BenchmarkFixture {
    var name: String
    var options: ScanOptions
    var build: (URL) throws -> Void
}

private let fileManager = FileManager.default

@main
struct SpatiaBenchmarks {
    static func main() throws {
        let workspace = fileManager.temporaryDirectory
            .appendingPathComponent("SpatiaBenchmarks-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: workspace, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workspace) }

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]

        for fixture in fixtures {
            let root = workspace.appendingPathComponent(fixture.name, isDirectory: true)
            try fileManager.createDirectory(at: root, withIntermediateDirectories: true)
            try fixture.build(root)

            let run = try scanFixture(root: root, options: fixture.options)
            let derived = measureDerivedMetrics(snapshot: run.result.snapshot)
            let row = BenchmarkRow(
                fixture: fixture.name,
                fileCount: run.result.summary.fileCount,
                folderCount: run.result.summary.folderCount,
                logicalBytes: run.result.summary.logicalBytes,
                allocatedBytes: run.result.summary.allocatedBytes,
                durationMilliseconds: run.result.summary.duration * 1_000,
                eventCount: run.eventCount,
                firstSnapshotMilliseconds: run.firstSnapshotMilliseconds,
                searchIndexMilliseconds: derived.searchIndexMilliseconds,
                searchQueryMilliseconds: derived.searchQueryMilliseconds,
                categoryUsageMilliseconds: derived.categoryUsageMilliseconds,
                largestFilesMilliseconds: derived.largestFilesMilliseconds,
                issueCount: run.result.issues.count
            )

            let data = try encoder.encode(row)
            guard let line = String(data: data, encoding: .utf8) else {
                throw BenchmarkError.invalidUTF8
            }
            print(line)
        }
    }
}

private enum BenchmarkError: Error {
    case invalidUTF8
    case missingResult
}

private struct DerivedMetricTimings {
    var searchIndexMilliseconds: Double
    var searchQueryMilliseconds: Double
    var categoryUsageMilliseconds: Double
    var largestFilesMilliseconds: Double
}

private let fixtures: [BenchmarkFixture] = [
    BenchmarkFixture(name: "balanced-tree", options: ScanOptions()) { root in
        try buildBalancedTree(root: root, depth: 3, fanout: 4, filesPerDirectory: 4, fileBytes: 256)
    },
    BenchmarkFixture(name: "wide-directory", options: ScanOptions()) { root in
        try buildWideDirectory(root: root, fileCount: 600, fileBytes: 128)
    },
    BenchmarkFixture(name: "large-balanced-tree", options: ScanOptions()) { root in
        try buildBalancedTree(root: root, depth: 4, fanout: 6, filesPerDirectory: 5, fileBytes: 64)
    },
    BenchmarkFixture(name: "large-wide-directory", options: ScanOptions()) { root in
        try buildWideDirectory(root: root, fileCount: 5_000, fileBytes: 64)
    },
    BenchmarkFixture(name: "package-opaque", options: ScanOptions(expandPackages: false)) { root in
        try buildPackageSet(root: root, packageCount: 20, filesPerPackage: 12, fileBytes: 192)
    },
    BenchmarkFixture(name: "package-expanded", options: ScanOptions(expandPackages: true)) { root in
        try buildPackageSet(root: root, packageCount: 20, filesPerPackage: 12, fileBytes: 192)
    }
]

private func scanFixture(root: URL, options: ScanOptions) throws -> (
    result: ScanResult,
    eventCount: Int,
    firstSnapshotMilliseconds: Double?
) {
    var accumulator = ScanAccumulator()
    var eventCount = 0
    var firstSnapshotMilliseconds: Double?
    let startedAt = Date()

    FileScanner(options: options).scanEvents(root: root) { event in
        eventCount += 1
        accumulator.consume(event)

        if firstSnapshotMilliseconds == nil, accumulator.snapshot != nil {
            firstSnapshotMilliseconds = Date().timeIntervalSince(startedAt) * 1_000
        }
    }

    guard let result = accumulator.result else {
        throw BenchmarkError.missingResult
    }
    return (result, eventCount, firstSnapshotMilliseconds)
}

private func measureDerivedMetrics(snapshot: FileTreeSnapshot) -> DerivedMetricTimings {
    let rootID = snapshot.rootID
    let searchIndex = measure {
        FileSearchIndex(snapshot: snapshot, rootedAt: rootID)
    }
    let searchQuery = measure {
        searchIndex.value.search(query: "a", limit: 30)
    }
    let categoryUsage = measure {
        snapshot.categoryUsage(rootedAt: rootID)
    }
    let largestFiles = measure {
        snapshot.largestDescendantFiles(rootedAt: rootID, limit: 16)
    }

    return DerivedMetricTimings(
        searchIndexMilliseconds: searchIndex.milliseconds,
        searchQueryMilliseconds: searchQuery.milliseconds,
        categoryUsageMilliseconds: categoryUsage.milliseconds,
        largestFilesMilliseconds: largestFiles.milliseconds
    )
}

private func measure<T>(_ work: () -> T) -> (value: T, milliseconds: Double) {
    let startedAt = Date()
    let value = work()
    return (value, Date().timeIntervalSince(startedAt) * 1_000)
}

private func buildBalancedTree(
    root: URL,
    depth: Int,
    fanout: Int,
    filesPerDirectory: Int,
    fileBytes: Int
) throws {
    try populateDirectory(root, level: 0, maxDepth: depth, fanout: fanout, filesPerDirectory: filesPerDirectory, fileBytes: fileBytes)
}

private func populateDirectory(
    _ directory: URL,
    level: Int,
    maxDepth: Int,
    fanout: Int,
    filesPerDirectory: Int,
    fileBytes: Int
) throws {
    for index in 0..<filesPerDirectory {
        try writeFile(
            at: directory.appendingPathComponent("file-\(level)-\(index).dat"),
            bytes: fileBytes + index
        )
    }

    guard level < maxDepth else { return }

    for index in 0..<fanout {
        let child = directory.appendingPathComponent("dir-\(level)-\(index)", isDirectory: true)
        try fileManager.createDirectory(at: child, withIntermediateDirectories: true)
        try populateDirectory(
            child,
            level: level + 1,
            maxDepth: maxDepth,
            fanout: fanout,
            filesPerDirectory: filesPerDirectory,
            fileBytes: fileBytes
        )
    }
}

private func buildWideDirectory(root: URL, fileCount: Int, fileBytes: Int) throws {
    for index in 0..<fileCount {
        try writeFile(at: root.appendingPathComponent("wide-\(index).dat"), bytes: fileBytes + (index % 17))
    }
}

private func buildPackageSet(root: URL, packageCount: Int, filesPerPackage: Int, fileBytes: Int) throws {
    for packageIndex in 0..<packageCount {
        let contents = root
            .appendingPathComponent("Fixture-\(packageIndex).app", isDirectory: true)
            .appendingPathComponent("Contents", isDirectory: true)
        try fileManager.createDirectory(at: contents, withIntermediateDirectories: true)

        for fileIndex in 0..<filesPerPackage {
            try writeFile(
                at: contents.appendingPathComponent("asset-\(fileIndex).bin"),
                bytes: fileBytes + fileIndex
            )
        }
    }
}

private func writeFile(at url: URL, bytes: Int) throws {
    try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    try Data(repeating: 0x5A, count: bytes).write(to: url, options: .atomic)
}
