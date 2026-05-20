import Foundation
import SpatiaCore

struct SnapshotDerivedKey: Hashable, Sendable {
    var snapshotRootID: NodeID
    var displayRootID: NodeID
    var searchRootID: NodeID
    var snapshotRevision: UInt64
    var nodeCount: Int
    var rootLogicalSize: Int64
    var rootAllocatedSize: Int64
    var displayRootLogicalSize: Int64
    var displayRootAllocatedSize: Int64

    init(snapshot: FileTreeSnapshot, displayRootID: NodeID, searchRootID: NodeID? = nil) {
        self.snapshotRootID = snapshot.rootID
        self.displayRootID = displayRootID
        self.searchRootID = searchRootID ?? displayRootID
        self.snapshotRevision = snapshot.revision
        self.nodeCount = snapshot.nodes.count
        self.rootLogicalSize = snapshot.root?.logicalSize ?? 0
        self.rootAllocatedSize = snapshot.root?.allocatedSize ?? 0
        self.displayRootLogicalSize = snapshot[displayRootID]?.logicalSize ?? 0
        self.displayRootAllocatedSize = snapshot[displayRootID]?.allocatedSize ?? 0
    }
}

struct SearchIndexCache {
    var key: SnapshotDerivedKey
    var index: FileSearchIndex
}

struct SearchBuildOutput: Sendable {
    var index: FileSearchIndex
    var results: [SearchResultSummary]
}

enum CanvasDerivedBuilder {
    static func build(
        scopes: Set<CanvasDerivedScope>,
        snapshot: FileTreeSnapshot,
        displayRoot: FileNode
    ) -> CanvasDerivedState {
        let currentView = buildCurrentView(snapshot: snapshot, displayRoot: displayRoot)
        return CanvasDerivedState(
            currentViewSummary: currentView.summary,
            currentViewItems: currentView.items,
            largestFileItems: scopes.contains(.largestFiles)
                ? buildLargestDescendantFileSummaries(snapshot: snapshot, displayRoot: displayRoot)
                : [],
            categoryUsageItems: scopes.contains(.typeUsage)
                ? buildCategoryUsageSummaries(snapshot: snapshot, displayRoot: displayRoot)
                : [],
            loadingScopes: [],
            errors: [:]
        )
    }

    private static func buildCurrentView(
        snapshot: FileTreeSnapshot,
        displayRoot: FileNode
    ) -> (summary: CanvasViewSummary, items: [CurrentViewItemSummary]) {
        let children = snapshot.children(of: displayRoot.id)
            .filter { $0.allocatedSize > 0 }
            .sorted { lhs, rhs in
                if lhs.allocatedSize == rhs.allocatedSize {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.allocatedSize > rhs.allocatedSize
            }

        let folderCount = children.filter { $0.kind == .directory || $0.kind == .package }.count
        let fileCount = children.count - folderCount
        let summary = CanvasViewSummary(
            name: DerivedFormatting.displayName(for: displayRoot),
            diskUsage: ByteCount.string(displayRoot.allocatedSize),
            fileCount: "\(fileCount)",
            folderCount: "\(folderCount)",
            path: displayRoot.url?.path
        )
        let items = children.map { node in
            CurrentViewItemSummary(
                id: node.id,
                name: DerivedFormatting.displayName(for: node),
                kind: DerivedFormatting.displayName(for: node.kind),
                sizeText: ByteCount.string(node.allocatedSize),
                path: node.url?.path,
                isContainer: isNavigableContainer(node)
            )
        }
        return (summary, items)
    }

    private static func buildLargestDescendantFileSummaries(
        snapshot: FileTreeSnapshot,
        displayRoot: FileNode
    ) -> [DescendantFileSummary] {
        snapshot.largestDescendantFiles(rootedAt: displayRoot.id, limit: 16)
            .compactMap { usage in
                guard let node = snapshot[usage.nodeID] else { return nil }
                let category = FileCategoryClassifier.category(for: node)
                return DescendantFileSummary(
                    id: node.id,
                    name: DerivedFormatting.displayName(for: node),
                    relativePath: snapshot.relativePath(from: displayRoot.id, to: node.id) ?? DerivedFormatting.displayName(for: node),
                    category: category,
                    categoryName: DerivedFormatting.displayName(for: category),
                    sizeText: ByteCount.string(usage.allocatedBytes),
                    shareText: DerivedFormatting.percentageString(usage.shareOfRoot),
                    shareOfCurrentRoot: usage.shareOfRoot,
                    path: node.url?.path
                )
            }
    }

    private static func buildCategoryUsageSummaries(
        snapshot: FileTreeSnapshot,
        displayRoot: FileNode
    ) -> [CategoryUsageSummary] {
        snapshot.categoryUsage(rootedAt: displayRoot.id)
            .map { usage in
                CategoryUsageSummary(
                    category: usage.category,
                    name: DerivedFormatting.displayName(for: usage.category),
                    sizeText: ByteCount.string(usage.allocatedBytes),
                    itemCountText: "\(usage.itemCount)",
                    shareText: DerivedFormatting.percentageString(usage.shareOfRoot),
                    allocatedBytes: usage.allocatedBytes,
                    itemCount: usage.itemCount,
                    shareOfCurrentRoot: usage.shareOfRoot
                )
            }
    }

    private static func isNavigableContainer(_ node: FileNode) -> Bool {
        guard !node.children.isEmpty else { return false }
        return node.kind == .directory || node.kind == .package
    }
}

enum SearchDerivedBuilder {
    static func build(
        snapshot: FileTreeSnapshot,
        key: SnapshotDerivedKey,
        query: String,
        cachedIndex: FileSearchIndex?
    ) -> SearchBuildOutput {
        let index = cachedIndex ?? FileSearchIndex(
            snapshot: snapshot,
            rootedAt: key.searchRootID,
            isCancelled: { Task.isCancelled }
        )
        let results = index.search(
            query: query,
            limit: 30,
            isCancelled: { Task.isCancelled }
        )
            .map { result in
                SearchResultSummary(
                    id: result.nodeID,
                    name: result.name,
                    relativePath: result.relativePath,
                    kind: DerivedFormatting.displayName(for: result.kind),
                    category: result.category,
                    categoryName: DerivedFormatting.displayName(for: result.category),
                    sizeText: ByteCount.string(result.allocatedBytes)
                )
            }
        return SearchBuildOutput(index: index, results: results)
    }
}

enum DerivedFormatting {
    static func displayName(for node: FileNode) -> String {
        if !node.name.isEmpty { return node.name }
        return node.url?.lastPathComponent.isEmpty == false ? node.url?.lastPathComponent ?? node.name : node.url?.path ?? node.name
    }

    static func displayName(for kind: NodeKind) -> String {
        switch kind {
        case .directory:
            return "Folder"
        case .file:
            return "File"
        case .package:
            return "Package"
        case .symlink:
            return "Alias"
        case .other:
            return "Other"
        }
    }

    static func displayName(for category: FileCategory) -> String {
        switch category {
        case .video:
            return "Video"
        case .image:
            return "Image"
        case .audio:
            return "Audio"
        case .archive:
            return "Archive"
        case .appPackage:
            return "App"
        case .document:
            return "Document"
        case .source:
            return "Source"
        case .cache:
            return "Cache"
        case .system:
            return "System"
        case .other:
            return "Other"
        }
    }

    static func percentageString(_ share: Double) -> String {
        guard share > 0 else { return "0%" }

        let percent = share * 100
        if percent < 0.1 {
            return "<0.1%"
        }
        if percent >= 99.95 {
            return "100%"
        }
        if percent >= 10 || percent.rounded() == percent {
            return String(format: "%.0f%%", percent)
        }
        return String(format: "%.1f%%", percent)
    }
}

struct CanvasDerivedState: Hashable, Sendable {
    var currentViewSummary: CanvasViewSummary?
    var currentViewItems: [CurrentViewItemSummary]
    var largestFileItems: [DescendantFileSummary]
    var categoryUsageItems: [CategoryUsageSummary]
    var loadingScopes: Set<CanvasDerivedScope>
    var errors: [CanvasDerivedScope: String]

    static let empty = CanvasDerivedState(
        currentViewSummary: nil,
        currentViewItems: [],
        largestFileItems: [],
        categoryUsageItems: [],
        loadingScopes: [],
        errors: [:]
    )

    static func loading(scopes: Set<CanvasDerivedScope>) -> CanvasDerivedState {
        CanvasDerivedState(
            currentViewSummary: nil,
            currentViewItems: [],
            largestFileItems: [],
            categoryUsageItems: [],
            loadingScopes: scopes,
            errors: [:]
        )
    }
}

struct SearchState: Hashable, Sendable {
    var query: String
    var isLoading: Bool
    var results: [SearchResultSummary]

    static func empty(query: String) -> SearchState {
        SearchState(query: query, isLoading: false, results: [])
    }

    static func loading(query: String) -> SearchState {
        SearchState(query: query, isLoading: true, results: [])
    }

    static func ready(query: String, results: [SearchResultSummary]) -> SearchState {
        SearchState(query: query, isLoading: false, results: results)
    }
}

struct ScanOverview: Hashable {
    var sourceName: String
    var sourcePath: String
    var diskUsage: String
    var fileCount: String
    var folderCount: String
    var duration: String
    var currentPath: String?

    init(
        sourceName: String,
        sourcePath: String,
        diskUsage: String,
        fileCount: String,
        folderCount: String,
        duration: String,
        currentPath: String? = nil
    ) {
        self.sourceName = sourceName
        self.sourcePath = sourcePath
        self.diskUsage = diskUsage
        self.fileCount = fileCount
        self.folderCount = folderCount
        self.duration = duration
        self.currentPath = currentPath
    }
}

struct ScanProgress: Hashable, Sendable {
    var rootURL: URL
    var startedAt: Date
    var fileCount = 0
    var folderCount = 0
    var logicalBytes: Int64 = 0
    var allocatedBytes: Int64 = 0
    var currentPath: String?

    var elapsedTime: TimeInterval {
        Date().timeIntervalSince(startedAt)
    }

    mutating func consume(_ event: ScanEvent) {
        switch event {
        case let .started(root, startedAt):
            rootURL = root
            self.startedAt = startedAt
            fileCount = 0
            folderCount = 0
            logicalBytes = 0
            allocatedBytes = 0
            currentPath = root.path
        case let .nodeDiscovered(node):
            currentPath = node.url?.path
            switch node.kind {
            case .directory, .package:
                folderCount += 1
            case .file, .symlink, .other:
                fileCount += 1
            }
        case let .directoryFinished(node):
            currentPath = node.url?.path
        case .issue, .finished:
            break
        }
    }
}

enum CanvasDerivedScope: String, CaseIterable, Hashable, Identifiable, Sendable {
    case currentView
    case largestFiles
    case typeUsage

    var id: Self { self }
}

enum SearchScope: String, CaseIterable, Hashable, Identifiable, Sendable {
    case scan
    case currentView

    var id: Self { self }

    var title: String {
        switch self {
        case .scan:
            return "Scan"
        case .currentView:
            return "Current View"
        }
    }
}

struct ScanPreferences: Hashable {
    var expandPackages = false
    var includeHiddenFiles = true
    var maxDepth: Int?

    func scanOptions(cancellationSource: ScanCancellationSource? = nil) -> ScanOptions {
        ScanOptions(
            expandPackages: expandPackages,
            includeHiddenFiles: includeHiddenFiles,
            maxDepth: maxDepth,
            cancellationSource: cancellationSource
        )
    }
}

struct SyntheticOtherSelection: Hashable {
    var size: Int64
}

struct OtherSmallFilesDetail: Hashable {
    var diskUsage: String
    var displayRootName: String?
}

struct CanvasViewSummary: Hashable, Sendable {
    var name: String
    var diskUsage: String
    var fileCount: String
    var folderCount: String
    var path: String?
}

struct CurrentViewItemSummary: Identifiable, Hashable, Sendable {
    var id: NodeID
    var name: String
    var kind: String
    var sizeText: String
    var path: String?
    var isContainer: Bool
}

struct DescendantFileSummary: Identifiable, Hashable, Sendable {
    var id: NodeID
    var name: String
    var relativePath: String
    var category: FileCategory
    var categoryName: String
    var sizeText: String
    var shareText: String
    var shareOfCurrentRoot: Double
    var path: String?
}

struct CategoryUsageSummary: Identifiable, Hashable, Sendable {
    var category: FileCategory
    var name: String
    var sizeText: String
    var itemCountText: String
    var shareText: String
    var allocatedBytes: Int64
    var itemCount: Int
    var shareOfCurrentRoot: Double

    var id: FileCategory { category }
}

struct SearchResultSummary: Identifiable, Hashable, Sendable {
    var id: NodeID
    var name: String
    var relativePath: String
    var kind: String
    var category: FileCategory
    var categoryName: String
    var sizeText: String
}

struct SelectionDetail: Identifiable, Hashable {
    var id: NodeID
    var name: String
    var kind: String
    var diskUsage: String
    var fileSize: String
    var shareOfCurrentView: String
    var shareOfScan: String
    var category: String
    var modified: String?
    var path: String?
    var url: URL?
    var canQuickLook: Bool
    var canExpandPackage: Bool
    var isProtected: Bool
    var riskReason: String?
    var canMoveToTrash: Bool
    var trashDisabledReason: String?
    var trashWarnings: [String]
}

struct TrashActionState: Hashable {
    var canMoveToTrash: Bool
    var disabledReason: String?
    var warnings: [String]
}
