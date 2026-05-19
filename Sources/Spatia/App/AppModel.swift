import Foundation
import SpatiaCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var result: ScanResult?
    @Published var selectedID: NodeID?
    @Published var displayRootID: NodeID?
    @Published var isScanning = false
    @Published var statusText = "Choose a folder to scan."
    @Published var currentScanURL: URL?
    @Published private var expandedTreemapNodeIDsStorage: Set<NodeID> = []

    private var scanTask: Task<Void, Never>?
    private var scanCancellationSource: ScanCancellationSource?

    var snapshot: FileTreeSnapshot? {
        result?.snapshot
    }

    var displayRoot: FileNode? {
        guard let snapshot else { return nil }
        if let displayRootID, let node = snapshot[displayRootID] {
            return node
        }
        return snapshot.root
    }

    var selectedNode: FileNode? {
        guard let selectedID else { return nil }
        return snapshot?[selectedID]
    }

    var expandedTreemapNodeIDs: Set<NodeID> {
        guard let snapshot, let displayRoot else { return [] }
        return Set(expandedTreemapNodeIDsStorage.filter { id in
            guard let node = snapshot[id], node.id != displayRoot.id, isNavigableContainer(node) else {
                return false
            }
            return snapshot.breadcrumb(for: id).contains { $0.id == displayRoot.id }
        })
    }

    var breadcrumb: [FileNode] {
        guard let snapshot, let displayRoot else { return [] }
        return snapshot.breadcrumb(for: displayRoot.id)
    }

    var permissionIssues: [ScanIssue] {
        result?.issues ?? []
    }

    var scanOverview: ScanOverview? {
        guard let summary = result?.summary else { return nil }
        return ScanOverview(
            sourceName: displayName(for: summary.rootURL),
            sourcePath: summary.rootURL.path,
            diskUsage: ByteCount.string(summary.allocatedBytes),
            fileCount: "\(summary.fileCount)",
            folderCount: "\(summary.folderCount)",
            duration: String(format: "%.1fs", summary.duration)
        )
    }

    var largestDisplayRootChildren: [DisplayRootChildSummary] {
        guard let snapshot, let displayRoot else { return [] }

        return snapshot.children(of: displayRoot.id)
            .filter { $0.allocatedSize > 0 }
            .sorted { lhs, rhs in
                if lhs.allocatedSize == rhs.allocatedSize {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.allocatedSize > rhs.allocatedSize
            }
            .prefix(8)
            .map { node in
                DisplayRootChildSummary(
                    id: node.id,
                    name: displayName(for: node),
                    kind: displayName(for: node.kind),
                    sizeText: ByteCount.string(node.allocatedSize),
                    path: node.url?.path,
                    isContainer: isNavigableContainer(node)
                )
            }
    }

    var selectedNodeDetail: SelectionDetail? {
        guard let node = selectedNode else { return nil }
        return SelectionDetail(
            id: node.id,
            name: displayName(for: node),
            kind: displayName(for: node.kind),
            diskUsage: ByteCount.string(node.allocatedSize),
            fileSize: ByteCount.string(node.logicalSize),
            category: displayName(for: FileCategoryClassifier.category(for: node)),
            modified: node.modifiedAt?.formatted(date: .abbreviated, time: .shortened),
            path: node.url?.path,
            url: node.url,
            canQuickLook: canQuickLook(node),
            isProtected: node.flags.contains(.systemProtected) || node.flags.contains(.permissionDenied)
        )
    }

    var canQuickLookSelected: Bool {
        guard let selectedNode else { return false }
        return canQuickLook(selectedNode)
    }

    func scanDownloads() {
        let downloads = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Downloads", isDirectory: true)
        scan(downloads)
    }

    func scanDesktop() {
        let desktop = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Desktop", isDirectory: true)
        scan(desktop)
    }

    func scanDocuments() {
        let documents = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents", isDirectory: true)
        scan(documents)
    }

    func scanApplications() {
        scan(URL(fileURLWithPath: "/Applications", isDirectory: true))
    }

    func scanHome() {
        scan(FileManager.default.homeDirectoryForCurrentUser)
    }

    func chooseFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Scan"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        scan(url)
    }

    func scan(_ url: URL) {
        scanTask?.cancel()
        scanCancellationSource?.cancel()

        let cancellationSource = ScanCancellationSource()
        scanCancellationSource = cancellationSource
        isScanning = true
        selectedID = nil
        displayRootID = nil
        expandedTreemapNodeIDsStorage = []
        currentScanURL = url
        statusText = "Scanning \(url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent)..."

        scanTask = Task {
            let options = ScanOptions(
                expandPackages: false,
                includeHiddenFiles: true,
                cancellationSource: cancellationSource
            )
            let scanner = FileScanner(options: options)
            let scanResult = await Task.detached(priority: .userInitiated) {
                scanner.scan(root: url)
            }.value

            guard !Task.isCancelled, !cancellationSource.isCancelled, scanCancellationSource === cancellationSource else {
                return
            }

            result = scanResult
            displayRootID = scanResult.snapshot.rootID
            isScanning = false
            statusText = "Scanned \(scanResult.summary.fileCount) files, \(ByteCount.string(scanResult.summary.allocatedBytes))."
        }
    }

    func select(_ id: NodeID?) {
        let resolvedID = id == syntheticOtherNodeID ? nil : id
        selectedID = resolvedID

        guard let resolvedID else { return }
        expandedTreemapNodeIDsStorage.formUnion(expansionPathNodeIDs(for: resolvedID))
    }

    func enterSelectedDirectory() {
        guard let selectedID else { return }
        enterDirectory(selectedID)
    }

    func enterDirectory(_ id: NodeID) {
        guard id != syntheticOtherNodeID, let node = snapshot?[id], !node.children.isEmpty else { return }
        guard node.kind == .directory || node.kind == .package || node.kind == .volume else { return }
        displayRootID = node.id
        selectedID = nil
        expandedTreemapNodeIDsStorage = []
    }

    func openSidebarItem(_ id: NodeID) {
        guard let node = snapshot?[id], id != syntheticOtherNodeID else { return }
        if isNavigableContainer(node) {
            enterDirectory(id)
        } else {
            select(id)
        }
    }

    func quickLookSelected() {
        guard let selectedID else { return }
        quickLook(selectedID)
    }

    func quickLook(_ id: NodeID) {
        guard id != syntheticOtherNodeID, let node = snapshot?[id], node.kind == .file, let url = node.url else { return }
        MacActions.quickLook(url)
    }

    func goUp() {
        guard let displayRoot, let parentID = displayRoot.parentID else { return }
        displayRootID = parentID
        selectedID = nil
        expandedTreemapNodeIDsStorage = []
    }

    func navigateToBreadcrumb(_ id: NodeID) {
        guard let snapshot, snapshot[id] != nil else { return }
        guard breadcrumb.contains(where: { $0.id == id }) else { return }
        displayRootID = id
        selectedID = nil
        expandedTreemapNodeIDsStorage = []
    }

    private func expansionPathNodeIDs(for id: NodeID) -> Set<NodeID> {
        guard let snapshot, let displayRoot, let selectedNode = snapshot[id] else { return [] }

        let path = snapshot.breadcrumb(for: id)
        guard let rootIndex = path.firstIndex(where: { $0.id == displayRoot.id }) else {
            return []
        }

        let selectedIsContainer = isNavigableContainer(selectedNode)
        let pathAfterRoot = path.dropFirst(rootIndex + 1)
        return Set(pathAfterRoot.compactMap { node in
            if node.id == id {
                return selectedIsContainer ? node.id : nil
            }
            return isNavigableContainer(node) ? node.id : nil
        })
    }

    private func canQuickLook(_ node: FileNode) -> Bool {
        node.id != syntheticOtherNodeID && node.kind == .file && node.url != nil
    }

    private func isNavigableContainer(_ node: FileNode) -> Bool {
        guard !node.children.isEmpty else { return false }
        return node.kind == .directory || node.kind == .package || node.kind == .volume
    }

    private func displayName(for node: FileNode) -> String {
        if !node.name.isEmpty { return node.name }
        return node.url.map(displayName(for:)) ?? node.name
    }

    private func displayName(for url: URL) -> String {
        if !url.lastPathComponent.isEmpty { return url.lastPathComponent }
        return url.path
    }

    private func displayName(for kind: NodeKind) -> String {
        switch kind {
        case .directory:
            return "Folder"
        case .file:
            return "File"
        case .package:
            return "Package"
        case .symlink:
            return "Alias"
        case .volume:
            return "Volume"
        case .other:
            return "Other"
        }
    }

    private func displayName(for category: FileCategory) -> String {
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
}

struct ScanOverview: Hashable {
    var sourceName: String
    var sourcePath: String
    var diskUsage: String
    var fileCount: String
    var folderCount: String
    var duration: String
}

struct DisplayRootChildSummary: Identifiable, Hashable {
    var id: NodeID
    var name: String
    var kind: String
    var sizeText: String
    var path: String?
    var isContainer: Bool
}

struct SelectionDetail: Identifiable, Hashable {
    var id: NodeID
    var name: String
    var kind: String
    var diskUsage: String
    var fileSize: String
    var category: String
    var modified: String?
    var path: String?
    var url: URL?
    var canQuickLook: Bool
    var isProtected: Bool
}
