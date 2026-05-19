import Foundation
import UniformTypeIdentifiers

public struct ScanOptions: Sendable {
    public var expandPackages: Bool
    public var includeHiddenFiles: Bool
    public var maxDepth: Int?

    public init(
        expandPackages: Bool = false,
        includeHiddenFiles: Bool = true,
        maxDepth: Int? = nil
    ) {
        self.expandPackages = expandPackages
        self.includeHiddenFiles = includeHiddenFiles
        self.maxDepth = maxDepth
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

public struct FileScanner: Sendable {
    public var options: ScanOptions

    public init(options: ScanOptions = ScanOptions()) {
        self.options = options
    }

    public func scan(root: URL) -> ScanResult {
        var builder = FileTreeBuilder(options: options)
        return builder.scan(root: root.standardizedFileURL)
    }
}

private struct FileTreeBuilder {
    private let options: ScanOptions
    private let fileManager = FileManager.default
    private var nodes: [FileNode] = []
    private var issues: [ScanIssue] = []
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
        .isHiddenKey
    ]

    init(options: ScanOptions) {
        self.options = options
    }

    mutating func scan(root: URL) -> ScanResult {
        let startedAt = Date()
        let rootID = scanNode(at: root, parentID: nil, depth: 0)
        let rootNode = nodes[Int(rootID)]
        let duration = Date().timeIntervalSince(startedAt)

        let summary = ScanSummary(
            rootURL: root,
            fileCount: fileCount,
            folderCount: folderCount,
            logicalBytes: rootNode.logicalSize,
            allocatedBytes: rootNode.allocatedSize,
            duration: duration
        )

        return ScanResult(
            snapshot: FileTreeSnapshot(nodes: nodes, rootID: rootID),
            summary: summary,
            issues: issues
        )
    }

    private mutating func scanNode(at url: URL, parentID: NodeID?, depth: Int) -> NodeID {
        let values = resourceValues(for: url)
        let kind = nodeKind(for: values)
        let id = NodeID(nodes.count)
        let name = url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
        var flags = nodeFlags(for: values)

        if isProtectedPath(url) {
            flags.insert(.systemProtected)
        }

        nodes.append(
            FileNode(
                id: id,
                parentID: parentID,
                name: name,
                url: url,
                kind: kind,
                flags: flags,
                typeIdentifier: typeIdentifier(for: url),
                logicalSize: fileLogicalSize(values),
                allocatedSize: fileAllocatedSize(values),
                modifiedAt: values?.contentModificationDate,
                children: [],
                scanState: .scanning
            )
        )

        switch kind {
        case .directory, .volume:
            folderCount += 1
            scanDirectoryNode(id: id, url: url, depth: depth)
        case .package:
            folderCount += 1
            if options.expandPackages {
                scanDirectoryNode(id: id, url: url, depth: depth)
            } else {
                let measured = measureOpaqueDirectory(at: url, depth: depth + 1)
                nodes[Int(id)].logicalSize = measured.logical
                nodes[Int(id)].allocatedSize = measured.allocated
            }
        case .file, .symlink, .other:
            fileCount += 1
        }

        nodes[Int(id)].scanState = .complete
        return id
    }

    private mutating func scanDirectoryNode(id: NodeID, url: URL, depth: Int) {
        guard shouldDescend(depth: depth) else {
            nodes[Int(id)].scanState = .skipped
            return
        }

        let childURLs = contentsOfDirectory(at: url)
        var children: [NodeID] = []
        var logicalSize: Int64 = 0
        var allocatedSize: Int64 = 0

        for childURL in childURLs {
            let childID = scanNode(at: childURL, parentID: id, depth: depth + 1)
            children.append(childID)
            let child = nodes[Int(childID)]
            logicalSize += child.logicalSize
            allocatedSize += child.allocatedSize
        }

        nodes[Int(id)].children = children
        nodes[Int(id)].logicalSize = logicalSize
        nodes[Int(id)].allocatedSize = allocatedSize
    }

    private mutating func measureOpaqueDirectory(at url: URL, depth: Int) -> (logical: Int64, allocated: Int64) {
        guard shouldDescend(depth: depth) else { return (0, 0) }

        var logical: Int64 = 0
        var allocated: Int64 = 0

        for childURL in contentsOfDirectory(at: url) {
            let values = resourceValues(for: childURL)
            let kind = nodeKind(for: values)

            switch kind {
            case .directory, .package, .volume:
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

    private mutating func contentsOfDirectory(at url: URL) -> [URL] {
        var directoryOptions: FileManager.DirectoryEnumerationOptions = []
        if !options.includeHiddenFiles {
            directoryOptions.insert(.skipsHiddenFiles)
        }

        do {
            return try fileManager.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: Array(resourceKeys),
                options: directoryOptions
            )
        } catch {
            let nsError = error as NSError
            let kind: ScanIssueKind = nsError.domain == NSCocoaErrorDomain && nsError.code == NSFileReadNoPermissionError
                ? .permissionDenied
                : .unreadable
            issues.append(ScanIssue(url: url, kind: kind, message: error.localizedDescription))
            return []
        }
    }

    private func resourceValues(for url: URL) -> URLResourceValues? {
        try? url.resourceValues(forKeys: resourceKeys)
    }

    private func typeIdentifier(for url: URL) -> String? {
        if let typeIdentifier = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier {
            return typeIdentifier
        }

        let pathExtension = url.pathExtension
        guard !pathExtension.isEmpty else { return nil }
        return UTType(filenameExtension: pathExtension)?.identifier
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
        return flags
    }

    private func fileLogicalSize(_ values: URLResourceValues?) -> Int64 {
        Int64(values?.fileSize ?? 0)
    }

    private func fileAllocatedSize(_ values: URLResourceValues?) -> Int64 {
        Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? values?.fileSize ?? 0)
    }

    private func isProtectedPath(_ url: URL) -> Bool {
        let path = url.standardizedFileURL.path
        return path == "/System"
            || path.hasPrefix("/System/")
            || path == "/bin"
            || path.hasPrefix("/bin/")
            || path == "/sbin"
            || path.hasPrefix("/sbin/")
            || path == "/usr"
            || path.hasPrefix("/usr/")
            || path == "/private"
            || path.hasPrefix("/private/")
    }
}
