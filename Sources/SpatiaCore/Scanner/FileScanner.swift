import Foundation

public struct ScanOptions: Sendable {
    public var expandPackages: Bool
    public var includeHiddenFiles: Bool
    public var maxDepth: Int?
    public var cancellationSource: ScanCancellationSource?

    public init(
        expandPackages: Bool = false,
        includeHiddenFiles: Bool = true,
        maxDepth: Int? = nil,
        cancellationSource: ScanCancellationSource? = nil
    ) {
        self.expandPackages = expandPackages
        self.includeHiddenFiles = includeHiddenFiles
        self.maxDepth = maxDepth
        self.cancellationSource = cancellationSource
    }
}

public struct ScanResult: Sendable {
    public var snapshot: FileTreeSnapshot
    public var summary: ScanSummary
    public var issues: [ScanIssue]

    public init(snapshot: FileTreeSnapshot, summary: ScanSummary, issues: [ScanIssue]) {
        self.snapshot = snapshot
        self.summary = summary
        self.issues = issues
    }
}

public struct ScanSummary: Hashable, Sendable {
    public var rootURL: URL
    public var fileCount: Int
    public var folderCount: Int
    public var logicalBytes: Int64
    public var allocatedBytes: Int64
    public var duration: TimeInterval

    public init(
        rootURL: URL,
        fileCount: Int,
        folderCount: Int,
        logicalBytes: Int64,
        allocatedBytes: Int64,
        duration: TimeInterval
    ) {
        self.rootURL = rootURL
        self.fileCount = fileCount
        self.folderCount = folderCount
        self.logicalBytes = logicalBytes
        self.allocatedBytes = allocatedBytes
        self.duration = duration
    }
}

public struct ScanIssue: Hashable, Sendable {
    public var url: URL
    public var kind: ScanIssueKind
    public var message: String

    public init(url: URL, kind: ScanIssueKind, message: String) {
        self.url = url
        self.kind = kind
        self.message = message
    }
}

public enum ScanIssueKind: String, Hashable, Sendable {
    case permissionDenied
    case unreadable
}

public enum ScanEvent: Sendable {
    case started(root: URL, startedAt: Date)
    case nodeDiscovered(FileNode)
    case directoryFinished(FileNode)
    case issue(ScanIssue)
    case finished(ScanSummary)
}

public struct ScanAccumulator: Sendable {
    private var nodes: [FileNode] = []
    private var rootID: NodeID?
    private var revision: UInt64 = 0
    public private(set) var summary: ScanSummary?
    public private(set) var issues: [ScanIssue] = []

    public init() {}

    public var snapshot: FileTreeSnapshot? {
        guard let rootID else { return nil }
        return FileTreeSnapshot(nodes: nodes, rootID: rootID, revision: revision)
    }

    public var result: ScanResult? {
        guard let snapshot, let summary else { return nil }
        return ScanResult(snapshot: snapshot, summary: summary, issues: issues)
    }

    public mutating func consume(_ event: ScanEvent) {
        switch event {
        case .started:
            nodes = []
            rootID = nil
            revision = 0
            summary = nil
            issues = []
        case let .nodeDiscovered(node):
            upsert(node)
        case let .directoryFinished(node):
            upsert(node)
        case let .issue(issue):
            issues.append(issue)
        case let .finished(scanSummary):
            summary = scanSummary
        }
    }

    private mutating func upsert(_ node: FileNode) {
        let index = Int(node.id)
        if rootID == nil {
            rootID = node.id
        }

        if nodes.indices.contains(index) {
            let oldNode = nodes[index]
            nodes[index] = node
            applySizeDelta(
                logical: node.logicalSize - oldNode.logicalSize,
                allocated: node.allocatedSize - oldNode.allocatedSize,
                toAncestorsOf: node.parentID
            )
            revision &+= 1
        } else {
            precondition(index == nodes.count, "Scan events must discover nodes in node ID order.")
            nodes.append(node)
            if let parentID = node.parentID, nodes.indices.contains(Int(parentID)) {
                nodes[Int(parentID)].children.append(node.id)
                applySizeDelta(
                    logical: node.logicalSize,
                    allocated: node.allocatedSize,
                    toAncestorsOf: parentID
                )
            }
            revision &+= 1
        }
    }

    private mutating func applySizeDelta(logical: Int64, allocated: Int64, toAncestorsOf parentID: NodeID?) {
        guard logical != 0 || allocated != 0 else { return }

        var currentID = parentID
        while let id = currentID, nodes.indices.contains(Int(id)) {
            nodes[Int(id)].logicalSize += logical
            nodes[Int(id)].allocatedSize += allocated
            currentID = nodes[Int(id)].parentID
        }
    }
}

typealias ResourceValuesProvider = @Sendable (URL, Set<URLResourceKey>) throws -> URLResourceValues

public struct FileScanner: Sendable {
    public var options: ScanOptions
    private let resourceValuesProvider: ResourceValuesProvider

    public init(options: ScanOptions = ScanOptions()) {
        self.options = options
        self.resourceValuesProvider = { url, keys in
            try url.resourceValues(forKeys: keys)
        }
    }

    init(
        options: ScanOptions = ScanOptions(),
        resourceValuesProvider: @escaping ResourceValuesProvider
    ) {
        self.options = options
        self.resourceValuesProvider = resourceValuesProvider
    }

    public func scan(root: URL) -> ScanResult {
        var accumulator = ScanAccumulator()
        scanEvents(root: root) { event in
            accumulator.consume(event)
        }
        guard let result = accumulator.result else {
            preconditionFailure("Scanner finished without producing a scan result.")
        }
        return result
    }

    public func scanEvents(root: URL, receive: @escaping (ScanEvent) -> Void) {
        var engine = FileScanEngine(
            options: options,
            resourceValuesProvider: resourceValuesProvider,
            receive: receive
        )
        engine.scan(root: root.standardizedFileURL)
    }
}

private struct FileScanEngine {
    private struct DirectoryContents {
        var urls: [URL]
        var issue: ScanIssue?
    }

    private struct ResourceRead {
        var values: URLResourceValues?
        var typeIdentifier: String?
        var issue: ScanIssue?
    }

    private struct ScannedNode {
        var id: NodeID
        var logicalSize: Int64
        var allocatedSize: Int64
    }

    private let options: ScanOptions
    private let fileManager = FileManager.default
    private let resourceValuesProvider: ResourceValuesProvider
    private let receive: (ScanEvent) -> Void
    private var nextID: NodeID = 0
    private var fileCount = 0
    private var folderCount = 0

    private let resourceKeys: Set<URLResourceKey> = [
        .isDirectoryKey,
        .isRegularFileKey,
        .isSymbolicLinkKey,
        .isPackageKey,
        .fileSizeKey,
        .fileAllocatedSizeKey,
        .totalFileAllocatedSizeKey,
        .contentModificationDateKey,
        .isHiddenKey,
        .isSystemImmutableKey,
        .isUserImmutableKey,
        .mayShareFileContentKey,
        .isPurgeableKey,
        .isSparseKey,
        .isUbiquitousItemKey,
        .ubiquitousItemDownloadingStatusKey
    ]

    private let pathRiskPolicy = PathRiskPolicy()

    init(
        options: ScanOptions,
        resourceValuesProvider: @escaping ResourceValuesProvider,
        receive: @escaping (ScanEvent) -> Void
    ) {
        self.options = options
        self.resourceValuesProvider = resourceValuesProvider
        self.receive = receive
    }

    mutating func scan(root: URL) {
        let startedAt = Date()
        receive(.started(root: root, startedAt: startedAt))
        let rootNode = scanNode(at: root, parentID: nil, depth: 0)
        let duration = Date().timeIntervalSince(startedAt)

        let summary = ScanSummary(
            rootURL: root,
            fileCount: fileCount,
            folderCount: folderCount,
            logicalBytes: rootNode.logicalSize,
            allocatedBytes: rootNode.allocatedSize,
            duration: duration
        )
        receive(.finished(summary))
    }

    private mutating func scanNode(at url: URL, parentID: NodeID?, depth: Int) -> ScannedNode {
        let resourceRead = resourceValues(for: url)
        let values = resourceRead.values
        let kind = nodeKind(for: values)
        let id = nextNodeID()
        let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        var flags = nodeFlags(for: values)
        if resourceRead.issue?.kind == .permissionDenied {
            flags.insert(.permissionDenied)
        }

        if pathRiskPolicy.isProtectedSystemPath(url: url) {
            flags.insert(.systemProtected)
        }

        var node = FileNode(
            id: id,
            parentID: parentID,
            name: name,
            url: url,
            kind: kind,
            flags: flags,
            typeIdentifier: resourceRead.typeIdentifier,
            logicalSize: fileLogicalSize(values),
            allocatedSize: fileAllocatedSize(values),
            modifiedAt: values?.contentModificationDate,
            children: [],
            scanState: .scanning
        )

        guard !isCancelled else {
            node.scanState = .skipped
            receive(.nodeDiscovered(node))
            return ScannedNode(id: id, logicalSize: node.logicalSize, allocatedSize: node.allocatedSize)
        }

        if let issue = resourceRead.issue {
            node = metadataReadFailureNode(node, issue: issue)
            receive(.nodeDiscovered(node))
            return ScannedNode(id: id, logicalSize: node.logicalSize, allocatedSize: node.allocatedSize)
        }

        switch kind {
        case .directory:
            folderCount += 1
            receive(.nodeDiscovered(node))
            let finishedNode = scanDirectoryNode(node: node, url: url, depth: depth)
            receive(.directoryFinished(finishedNode))
            return ScannedNode(id: id, logicalSize: finishedNode.logicalSize, allocatedSize: finishedNode.allocatedSize)
        case .package:
            folderCount += 1
            receive(.nodeDiscovered(node))
            if options.expandPackages {
                let finishedNode = scanDirectoryNode(node: node, url: url, depth: depth)
                receive(.directoryFinished(finishedNode))
                return ScannedNode(id: id, logicalSize: finishedNode.logicalSize, allocatedSize: finishedNode.allocatedSize)
            } else {
                let measured = measureOpaqueDirectory(at: url, depth: depth + 1)
                node.logicalSize = measured.logical
                node.allocatedSize = measured.allocated
                node.scanState = isCancelled ? .skipped : .complete
                receive(.directoryFinished(node))
                return ScannedNode(id: id, logicalSize: node.logicalSize, allocatedSize: node.allocatedSize)
            }
        case .file, .symlink, .other:
            fileCount += 1
            node.scanState = .complete
            receive(.nodeDiscovered(node))
            return ScannedNode(id: id, logicalSize: node.logicalSize, allocatedSize: node.allocatedSize)
        }
    }

    private mutating func scanDirectoryNode(node: FileNode, url: URL, depth: Int) -> FileNode {
        var node = node
        guard !isCancelled else {
            node.scanState = .skipped
            return node
        }

        guard shouldDescend(depth: depth) else {
            node.scanState = .skipped
            return node
        }

        let contents = contentsOfDirectory(at: url)
        if let issue = contents.issue {
            return directoryReadFailureNode(node, issue: issue)
        }

        var children: [NodeID] = []
        var logicalSize: Int64 = 0
        var allocatedSize: Int64 = 0

        for childURL in contents.urls {
            guard !isCancelled else {
                node.children = children
                node.logicalSize = logicalSize
                node.allocatedSize = allocatedSize
                node.scanState = .skipped
                return node
            }

            let childID = scanNode(at: childURL, parentID: node.id, depth: depth + 1)
            children.append(childID.id)
            logicalSize += childID.logicalSize
            allocatedSize += childID.allocatedSize
        }

        node.children = children
        node.logicalSize = logicalSize
        node.allocatedSize = allocatedSize
        node.scanState = isCancelled ? .skipped : .complete
        return node
    }

    private mutating func measureOpaqueDirectory(at url: URL, depth: Int) -> (logical: Int64, allocated: Int64) {
        guard !isCancelled else { return (0, 0) }
        guard shouldDescend(depth: depth) else { return (0, 0) }

        var logical: Int64 = 0
        var allocated: Int64 = 0

        let contents = contentsOfDirectory(at: url)
        guard contents.issue == nil else { return (0, 0) }

        for childURL in contents.urls {
            guard !isCancelled else { return (logical, allocated) }

            let resourceRead = resourceValues(for: childURL)
            guard let values = resourceRead.values else { continue }
            let kind = nodeKind(for: values)

            switch kind {
            case .directory, .package:
                folderCount += 1
                let measured = measureOpaqueDirectory(at: childURL, depth: depth + 1)
                logical += measured.logical
                allocated += measured.allocated
            case .file, .symlink, .other:
                fileCount += 1
                logical += fileLogicalSize(values)
                allocated += fileAllocatedSize(values)
            }
        }

        return (logical, allocated)
    }

    private func shouldDescend(depth: Int) -> Bool {
        guard let maxDepth = options.maxDepth else { return true }
        return depth < maxDepth
    }

    private var isCancelled: Bool {
        options.cancellationSource?.isCancelled == true
    }

    private mutating func contentsOfDirectory(at url: URL) -> DirectoryContents {
        var directoryOptions: FileManager.DirectoryEnumerationOptions = []
        if !options.includeHiddenFiles {
            directoryOptions.insert(.skipsHiddenFiles)
        }

        do {
            let urls = try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: directoryOptions
            )
            return DirectoryContents(urls: urls, issue: nil)
        } catch {
            let issue = scanIssue(url: url, error: error)
            receive(.issue(issue))
            return DirectoryContents(urls: [], issue: issue)
        }
    }

    private func directoryReadFailureNode(_ node: FileNode, issue: ScanIssue) -> FileNode {
        var node = node
        if issue.kind == .permissionDenied {
            node.flags.insert(.permissionDenied)
        }
        node.children = []
        node.scanState = .failed
        return node
    }

    private func metadataReadFailureNode(_ node: FileNode, issue: ScanIssue) -> FileNode {
        var node = node
        if issue.kind == .permissionDenied {
            node.flags.insert(.permissionDenied)
        }
        node.children = []
        node.scanState = .failed
        return node
    }

    private mutating func resourceValues(for url: URL) -> ResourceRead {
        do {
            let values = try resourceValuesProvider(url, resourceKeys)
            return ResourceRead(
                values: values,
                typeIdentifier: optionalTypeIdentifier(for: url),
                issue: nil
            )
        } catch {
            let issue = scanIssue(url: url, error: error)
            receive(.issue(issue))
            return ResourceRead(values: nil, typeIdentifier: nil, issue: issue)
        }
    }

    private mutating func nextNodeID() -> NodeID {
        let id = nextID
        nextID += 1
        return id
    }

    private func scanIssue(url: URL, error: Error) -> ScanIssue {
        let nsError = error as NSError
        let kind: ScanIssueKind = nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError
            ? .permissionDenied
            : .unreadable
        return ScanIssue(url: url, kind: kind, message: error.localizedDescription)
    }

    private func optionalTypeIdentifier(for url: URL) -> String? {
        try? resourceValuesProvider(url, [.typeIdentifierKey]).typeIdentifier
    }

    private func nodeKind(for values: URLResourceValues?) -> NodeKind {
        if values?.isSymbolicLink == true { return .symlink }
        if values?.isPackage == true { return .package }
        if values?.isDirectory == true { return .directory }
        if values?.isRegularFile == true { return .file }
        return .other
    }

    private func nodeFlags(for values: URLResourceValues?) -> NodeFlags {
        var flags: NodeFlags = []
        if values?.isHidden == true {
            flags.insert(.hidden)
        }
        if values?.isSystemImmutable == true || values?.isUserImmutable == true {
            flags.insert(.immutable)
        }
        if values?.mayShareFileContent == true || values?.isSparse == true {
            flags.insert(.possiblySharedAPFSBlocks)
        }
        if values?.isPurgeable == true {
            flags.insert(.purgeable)
        }
        if values?.isUbiquitousItem == true
            && values?.ubiquitousItemDownloadingStatus == URLUbiquitousItemDownloadingStatus.notDownloaded {
            flags.insert(.iCloudPlaceholder)
        }
        return flags
    }

    private func fileLogicalSize(_ values: URLResourceValues?) -> Int64 {
        Int64(values?.fileSize ?? 0)
    }

    private func fileAllocatedSize(_ values: URLResourceValues?) -> Int64 {
        Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }

}
