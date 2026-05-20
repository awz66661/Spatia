import Foundation
import SpatiaCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var result: ScanResult? {
        didSet {
            scheduleSidebarDerivedRefresh(force: true)
            scheduleSearchRefresh(debounce: false)
        }
    }

    @Published var selectedID: NodeID?
    @Published var displayRootID: NodeID? {
        didSet {
            scheduleSidebarDerivedRefresh(force: true)
            scheduleSearchRefresh(debounce: false)
        }
    }

    @Published var isScanning = false
    @Published var statusText = "Choose a folder to scan."
    @Published var currentScanURL: URL?
    @Published var scanPreferences = ScanPreferences()
    @Published var expandedSidebarSections: Set<SidebarSection> = Set([.browse, .largestFiles]) {
        didSet {
            let lazyDerivedSections: Set<SidebarSection> = [.largestFiles, .typeUsage]
            guard oldValue.intersection(lazyDerivedSections) != expandedSidebarSections.intersection(lazyDerivedSections) else {
                return
            }
            scheduleSidebarDerivedRefresh(force: true)
        }
    }

    @Published var searchQuery = "" {
        didSet {
            scheduleSearchRefresh(debounce: true)
        }
    }

    @Published private(set) var sidebarPanelState = SidebarPanelState.empty
    @Published private(set) var searchState = SearchState.empty(query: "")
    @Published private var partialScanSnapshot: FileTreeSnapshot? {
        didSet {
            scheduleSidebarDerivedRefresh(force: false)
            scheduleSearchRefresh(debounce: false)
        }
    }

    @Published private var partialScanIssues: [ScanIssue] = []
    @Published private var scanProgress: ScanProgress?
    @Published private var syntheticOtherSelection: SyntheticOtherSelection?
    @Published private var expandedTreemapNodeIDsStorage: Set<NodeID> = []

    var confirmMoveToTrash: (TrashConfirmation) -> Bool = MacActions.confirmMoveToTrash
    var moveToTrash: (URL) async -> TrashActionResult = MacActions.moveToTrash
    var quickLookFile: (URL) -> QuickLookResult = MacActions.quickLook
    var revealInFinder: (URL) -> Void = MacActions.reveal
    var copyPathToPasteboard: (URL) -> Void = MacActions.copyPath
    var scanEvents: @Sendable (URL, ScanOptions, @escaping (ScanEvent) -> Void) -> Void = { url, options, receive in
        FileScanner(options: options).scanEvents(root: url, receive: receive)
    }
    var scanExpandedPackage: @Sendable (URL, ScanOptions) -> ScanResult = { url, options in
        FileScanner(options: options).scan(root: url)
    }

    private var scanTask: Task<Void, Never>?
    private var scanCancellationSource: ScanCancellationSource?
    private var activeDerivedTask: Task<Void, Never>?
    private var activeSearchTask: Task<Void, Never>?
    private var derivedGeneration = 0
    private var searchGeneration = 0
    private var lastProgressiveDerivedRefresh = Date.distantPast
    private var searchIndexCache: SearchIndexCache?
    private var hoveredTreemapNodeID: NodeID?
    private var hoverStatusRestoreText: String?
    private let pathRiskPolicy = PathRiskPolicy()
    private let safetyPolicy = SafetyPolicy()

    var snapshot: FileTreeSnapshot? {
        result?.snapshot ?? partialScanSnapshot
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

    var selectedOtherDetail: OtherSmallFilesDetail? {
        guard let syntheticOtherSelection else { return nil }
        return OtherSmallFilesDetail(
            diskUsage: ByteCount.string(syntheticOtherSelection.size),
            displayRootName: displayRoot.map(displayName(for:))
        )
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

    var selectedPathNodeIDs: Set<NodeID> {
        guard let selectedID, let snapshot, let displayRoot else { return [] }
        let path = snapshot.breadcrumb(for: selectedID)
        guard let rootIndex = path.firstIndex(where: { $0.id == displayRoot.id }) else { return [] }
        return Set(path.dropFirst(rootIndex).map(\.id))
    }

    var breadcrumb: [FileNode] {
        guard let snapshot, let displayRoot else { return [] }
        return snapshot.breadcrumb(for: displayRoot.id)
    }

    var permissionIssues: [ScanIssue] {
        result?.issues ?? partialScanIssues
    }

    var scanOverview: ScanOverview? {
        if let summary = result?.summary {
            return ScanOverview(
                sourceName: displayName(for: summary.rootURL),
                sourcePath: summary.rootURL.path,
                diskUsage: ByteCount.string(summary.allocatedBytes),
                fileCount: "\(summary.fileCount)",
                folderCount: "\(summary.folderCount)",
                duration: String(format: "%.1fs", summary.duration)
            )
        }

        guard let progress = scanProgress else { return nil }
        return ScanOverview(
            sourceName: displayName(for: progress.rootURL),
            sourcePath: progress.rootURL.path,
            diskUsage: ByteCount.string(progress.allocatedBytes),
            fileCount: "\(progress.fileCount)",
            folderCount: "\(progress.folderCount)",
            duration: String(format: "%.1fs", progress.elapsedTime),
            currentPath: progress.currentPath
        )
    }

    var sidebarBrowseItems: [SidebarItemSummary] {
        sidebarPanelState.browseItems
    }

    var sidebarLargestFileItems: [DescendantFileSummary] {
        sidebarPanelState.largestFileItems
    }

    var sidebarCategoryUsageItems: [CategoryUsageSummary] {
        sidebarPanelState.categoryUsageItems
    }

    var searchResultSummaries: [SearchResultSummary] {
        searchState.results
    }

    var isSearchLoading: Bool {
        searchState.isLoading
    }

    var selectedNodeDetail: SelectionDetail? {
        guard let node = selectedNode else { return nil }
        let trashState = trashActionState(for: node)
        let risk = pathRiskPolicy.risk(for: node)
        let currentRootSize = displayRoot?.allocatedSize ?? 0
        let scanRootSize = snapshot?.root?.allocatedSize ?? 0
        return SelectionDetail(
            id: node.id,
            name: displayName(for: node),
            kind: displayName(for: node.kind),
            diskUsage: ByteCount.string(node.allocatedSize),
            fileSize: ByteCount.string(node.logicalSize),
            shareOfCurrentView: percentageString(share(node.allocatedSize, of: currentRootSize)),
            shareOfScan: percentageString(share(node.allocatedSize, of: scanRootSize)),
            category: displayName(for: FileCategoryClassifier.category(for: node)),
            modified: node.modifiedAt?.formatted(date: .abbreviated, time: .shortened),
            path: node.url?.path,
            url: node.url,
            canQuickLook: canQuickLook(node),
            canExpandPackage: canExpandPackage(node),
            isProtected: risk.isVisuallyProtected,
            riskReason: risk.blockReason,
            canMoveToTrash: trashState.canMoveToTrash,
            trashDisabledReason: trashState.disabledReason,
            trashWarnings: trashState.warnings
        )
    }

    var canQuickLookSelected: Bool {
        guard let selectedNode else { return false }
        return canQuickLook(selectedNode)
    }

    var canEnterSelectedContainer: Bool {
        guard let selectedID,
              selectedID != syntheticOtherNodeID,
              let node = snapshot?[selectedID] else {
            return false
        }
        return isNavigableContainer(node)
    }

    var canRevealSelected: Bool {
        selectedNode?.url != nil
    }

    var canCopySelectedPath: Bool {
        selectedNode?.url != nil
    }

    var canMoveSelectedToTrash: Bool {
        guard let selectedNode else { return false }
        return trashActionState(for: selectedNode).canMoveToTrash
    }

    var canExpandSelectedPackage: Bool {
        guard let selectedNode else { return false }
        return canExpandPackage(selectedNode)
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

    func rescanCurrentSource() {
        guard let currentScanURL else {
            statusText = "Choose a folder to scan."
            return
        }

        scan(currentScanURL)
    }

    func scan(_ url: URL) {
        scanTask?.cancel()
        scanCancellationSource?.cancel()
        cancelDerivedDataTasks()

        let cancellationSource = ScanCancellationSource()
        scanCancellationSource = cancellationSource
        isScanning = true
        result = nil
        partialScanSnapshot = nil
        partialScanIssues = []
        scanProgress = ScanProgress(rootURL: url, startedAt: Date())
        selectedID = nil
        syntheticOtherSelection = nil
        displayRootID = nil
        expandedTreemapNodeIDsStorage = []
        hoveredTreemapNodeID = nil
        hoverStatusRestoreText = nil
        currentScanURL = url
        statusText = "Scanning \(url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent)..."
        let scanPreferences = scanPreferences
        let scanEvents = scanEvents

        scanTask = Task {
            let options = scanPreferences.scanOptions(cancellationSource: cancellationSource)
            let scanResult = await Task.detached(priority: .userInitiated) { () -> ScanResult? in
                var accumulator = ScanAccumulator()
                var progress = ScanProgress(rootURL: url, startedAt: Date())
                var lastPublish = Date.distantPast
                var didPublishSnapshot = false

                func publish(force: Bool = false) {
                    guard let snapshot = accumulator.snapshot else { return }
                    let now = Date()
                    guard force || !didPublishSnapshot || now.timeIntervalSince(lastPublish) >= 0.25 else {
                        return
                    }

                    lastPublish = now
                    didPublishSnapshot = true
                    let issues = accumulator.issues
                    let progressSnapshot = progress
                    Task { @MainActor in
                        guard !cancellationSource.isCancelled,
                              self.scanCancellationSource === cancellationSource,
                              self.isScanning else {
                            return
                        }
                        self.applyProgressiveScanUpdate(
                            snapshot: snapshot,
                            issues: issues,
                            progress: progressSnapshot
                        )
                    }
                }

                scanEvents(url, options) { event in
                    accumulator.consume(event)
                    progress.consume(event)
                    if let root = accumulator.snapshot?.root {
                        progress.logicalBytes = root.logicalSize
                        progress.allocatedBytes = root.allocatedSize
                    }

                    if case .finished = event {
                        publish(force: true)
                    } else {
                        publish()
                    }
                }

                return accumulator.result
            }.value

            guard !Task.isCancelled, !cancellationSource.isCancelled, scanCancellationSource === cancellationSource else {
                return
            }
            guard let scanResult else { return }

            result = scanResult
            partialScanSnapshot = nil
            partialScanIssues = []
            scanProgress = nil
            displayRootID = scanResult.snapshot.rootID
            isScanning = false
            scanTask = nil
            scanCancellationSource = nil
            statusText = "Scanned \(scanResult.summary.fileCount) files, \(ByteCount.string(scanResult.summary.allocatedBytes))."
        }
    }

    func cancelScan() {
        guard isScanning else { return }

        scanTask?.cancel()
        scanCancellationSource?.cancel()
        cancelDerivedDataTasks()
        scanTask = nil
        scanCancellationSource = nil
        isScanning = false
        result = nil
        partialScanSnapshot = nil
        partialScanIssues = []
        scanProgress = nil
        selectedID = nil
        syntheticOtherSelection = nil
        displayRootID = nil
        expandedTreemapNodeIDsStorage = []
        hoveredTreemapNodeID = nil
        hoverStatusRestoreText = nil

        if let currentScanURL {
            statusText = "Cancelled scanning \(displayName(for: currentScanURL))."
        } else {
            statusText = "Scan cancelled."
        }
    }

    func select(_ id: NodeID?) {
        guard id != syntheticOtherNodeID else {
            selectedID = nil
            return
        }

        let resolvedID = id
        syntheticOtherSelection = nil
        selectedID = resolvedID

        guard let resolvedID else { return }
        expandedTreemapNodeIDsStorage.formUnion(expansionPathNodeIDs(for: resolvedID))
    }

    func selectSyntheticOther(size: Int64) {
        selectedID = nil
        syntheticOtherSelection = SyntheticOtherSelection(size: size)
    }

    func setIncludeHiddenFiles(_ includeHiddenFiles: Bool) {
        var preferences = scanPreferences
        preferences.includeHiddenFiles = includeHiddenFiles
        scanPreferences = preferences
    }

    func setExpandPackages(_ expandPackages: Bool) {
        var preferences = scanPreferences
        preferences.expandPackages = expandPackages
        scanPreferences = preferences
    }

    func setMaxDepth(_ maxDepth: Int?) {
        var preferences = scanPreferences
        preferences.maxDepth = maxDepth
        scanPreferences = preferences
    }

    func enterSelectedDirectory() {
        guard let selectedID else { return }
        enterDirectory(selectedID)
    }

    func enterDirectory(_ id: NodeID) {
        guard id != syntheticOtherNodeID, let node = snapshot?[id], !node.children.isEmpty else { return }
        guard node.kind == .directory || node.kind == .package else { return }
        displayRootID = node.id
        selectedID = nil
        syntheticOtherSelection = nil
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

    func openInsightItem(_ id: NodeID) {
        guard id != syntheticOtherNodeID, snapshot?[id] != nil else { return }
        select(id)
    }

    func hoverTreemapNode(_ id: NodeID?) {
        guard !isScanning else { return }

        guard let id, id != syntheticOtherNodeID else {
            if hoveredTreemapNodeID != nil, let hoverStatusRestoreText {
                statusText = hoverStatusRestoreText
            }
            hoveredTreemapNodeID = nil
            hoverStatusRestoreText = nil
            return
        }

        guard hoveredTreemapNodeID != id else { return }
        if hoveredTreemapNodeID == nil {
            hoverStatusRestoreText = statusText
        }
        hoveredTreemapNodeID = id

        guard let node = snapshot?[id] else { return }
        var components = [
            displayName(for: node),
            ByteCount.string(node.allocatedSize)
        ]
        if let path = node.url?.path {
            components.append(path)
        }
        statusText = components.joined(separator: " · ")
    }

    func quickLookSelected() {
        guard let selectedID else { return }
        quickLook(selectedID)
    }

    func revealSelectedInFinder() {
        guard let node = selectedNode, let url = node.url else {
            statusText = "Choose an item to reveal in Finder."
            return
        }
        revealInFinder(url)
    }

    func copySelectedPath() {
        guard let node = selectedNode, let url = node.url else {
            statusText = "Choose an item to copy its path."
            return
        }
        copyPathToPasteboard(url)
        statusText = "Copied path for \(displayName(for: node))."
    }

    func quickLook(_ id: NodeID) {
        guard id != syntheticOtherNodeID, let node = snapshot?[id], node.kind == .file, let url = node.url else { return }
        switch quickLookFile(url) {
        case .shown:
            break
        case .unavailable:
            statusText = "Quick Look is unavailable for \(displayName(for: node))."
        }
    }

    func moveSelectedItemToTrash() async {
        guard let selectedID,
              selectedID != syntheticOtherNodeID,
              let node = snapshot?[selectedID],
              let url = node.url else {
            statusText = "Choose an item to move to Trash."
            return
        }

        let trashState = trashActionState(for: node)
        guard trashState.canMoveToTrash else {
            statusText = trashState.disabledReason ?? "This item cannot be moved to Trash."
            return
        }

        let confirmation = TrashConfirmation(
            name: displayName(for: node),
            path: url.path,
            sizeText: ByteCount.string(node.allocatedSize),
            itemCount: itemCount(inSubtreeRootedAt: node.id),
            warnings: trashState.warnings
        )

        guard confirmMoveToTrash(confirmation) else {
            statusText = "Move to Trash cancelled."
            return
        }

        statusText = "Moving \(displayName(for: node)) to Trash..."
        let result = await moveToTrash(url)
        handleTrashResult(result, nodeID: selectedID, nodeName: displayName(for: node))
    }

    func expandSelectedPackage() async {
        guard let selectedID,
              selectedID != syntheticOtherNodeID,
              let node = snapshot?[selectedID],
              let url = node.url else {
            statusText = "Choose a package to expand."
            return
        }

        guard canExpandPackage(node) else {
            statusText = "This package is already expanded or cannot be expanded."
            return
        }

        statusText = "Expanding \(displayName(for: node))..."
        let scanExpandedPackage = scanExpandedPackage
        let preferences = scanPreferences
        let options = ScanOptions(
            expandPackages: true,
            includeHiddenFiles: preferences.includeHiddenFiles,
            maxDepth: nil
        )
        let expandedResult = await Task.detached(priority: .userInitiated) {
            scanExpandedPackage(url, options)
        }.value

        reconcileExpandedPackage(
            nodeID: selectedID,
            nodeName: displayName(for: node),
            expandedSnapshot: expandedResult.snapshot
        )
    }

    func goUp() {
        guard let displayRoot, let parentID = displayRoot.parentID else { return }
        displayRootID = parentID
        selectedID = nil
        syntheticOtherSelection = nil
        expandedTreemapNodeIDsStorage = []
    }

    func navigateToBreadcrumb(_ id: NodeID) {
        guard let snapshot, snapshot[id] != nil else { return }
        guard breadcrumb.contains(where: { $0.id == id }) else { return }
        displayRootID = id
        selectedID = nil
        syntheticOtherSelection = nil
        expandedTreemapNodeIDsStorage = []
    }

    func toggleSidebarSection(_ section: SidebarSection) {
        setSidebarSection(section, isExpanded: !expandedSidebarSections.contains(section))
    }

    func setSidebarSection(_ section: SidebarSection, isExpanded: Bool) {
        if isExpanded {
            expandedSidebarSections.insert(section)
        } else {
            expandedSidebarSections.remove(section)
        }
    }

    func isSidebarSectionLoading(_ section: SidebarSection) -> Bool {
        sidebarPanelState.loadingSections.contains(section)
    }

    private func scheduleSidebarDerivedRefresh(force: Bool) {
        guard let snapshot, let displayRoot else {
            activeDerivedTask?.cancel()
            activeDerivedTask = nil
            sidebarPanelState = .empty
            return
        }

        let now = Date()
        if isScanning && !force && now.timeIntervalSince(lastProgressiveDerivedRefresh) < 0.75 {
            return
        }
        lastProgressiveDerivedRefresh = now

        activeDerivedTask?.cancel()
        let key = SnapshotDerivedKey(snapshot: snapshot, displayRootID: displayRoot.id)
        let sections = sidebarSectionsToBuild()
        derivedGeneration += 1
        let generation = derivedGeneration
        sidebarPanelState = .loading(sections: sections)

        activeDerivedTask = Task { [snapshot, displayRoot, sections, key, generation] in
            let state = await Task.detached(priority: .utility) {
                SidebarDerivedBuilder.build(sections: sections, snapshot: snapshot, displayRoot: displayRoot)
            }.value

            guard !Task.isCancelled,
                  generation == derivedGeneration,
                  sections == sidebarSectionsToBuild(),
                  currentSnapshotDerivedKey() == key else {
                return
            }

            sidebarPanelState = state
            activeDerivedTask = nil
        }
    }

    private func scheduleSearchRefresh(debounce: Bool) {
        activeSearchTask?.cancel()

        let query = searchQuery
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let snapshot,
              let displayRoot else {
            searchState = .empty(query: query)
            return
        }

        let key = SnapshotDerivedKey(snapshot: snapshot, displayRootID: displayRoot.id)
        let cachedIndex = searchIndexCache?.key == key ? searchIndexCache?.index : nil
        searchGeneration += 1
        let generation = searchGeneration
        searchState = .loading(query: query)

        activeSearchTask = Task { [snapshot, query, key, cachedIndex, generation] in
            if debounce {
                try? await Task.sleep(nanoseconds: 230_000_000)
            }
            guard !Task.isCancelled else { return }

            let output = await Task.detached(priority: .utility) {
                SearchDerivedBuilder.build(
                    snapshot: snapshot,
                    key: key,
                    query: query,
                    cachedIndex: cachedIndex
                )
            }.value

            guard !Task.isCancelled,
                  generation == searchGeneration,
                  query == searchQuery,
                  currentSnapshotDerivedKey() == key else {
                return
            }

            searchIndexCache = SearchIndexCache(key: key, index: output.index)
            searchState = .ready(query: query, results: output.results)
            activeSearchTask = nil
        }
    }

    private func cancelDerivedDataTasks() {
        activeDerivedTask?.cancel()
        activeSearchTask?.cancel()
        activeDerivedTask = nil
        activeSearchTask = nil
        derivedGeneration += 1
        searchGeneration += 1
        searchIndexCache = nil
        sidebarPanelState = .empty
        searchState = .empty(query: searchQuery)
        lastProgressiveDerivedRefresh = Date.distantPast
    }

    private func sidebarSectionsToBuild() -> Set<SidebarSection> {
        var sections: Set<SidebarSection> = [.browse]
        if expandedSidebarSections.contains(.largestFiles) {
            sections.insert(.largestFiles)
        }
        if expandedSidebarSections.contains(.typeUsage) {
            sections.insert(.typeUsage)
        }
        return sections
    }

    private func currentSnapshotDerivedKey() -> SnapshotDerivedKey? {
        guard let snapshot, let displayRoot else { return nil }
        return SnapshotDerivedKey(snapshot: snapshot, displayRootID: displayRoot.id)
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

    private func canExpandPackage(_ node: FileNode) -> Bool {
        node.id != syntheticOtherNodeID
            && node.kind == .package
            && node.url != nil
            && node.children.isEmpty
            && !isScanning
    }

    private func trashActionState(for node: FileNode) -> TrashActionState {
        guard node.id != syntheticOtherNodeID else {
            return TrashActionState(canMoveToTrash: false, disabledReason: "Grouped small items cannot be moved to Trash.", warnings: [])
        }

        guard node.id != snapshot?.rootID else {
            return TrashActionState(canMoveToTrash: false, disabledReason: "The scanned root cannot be moved to Trash from Spatia.", warnings: [])
        }

        let decision = safetyPolicy.trashDecision(for: node)
        if let reason = decision.blockedReason {
            return TrashActionState(canMoveToTrash: false, disabledReason: reason, warnings: [])
        }

        return TrashActionState(
            canMoveToTrash: node.url != nil,
            disabledReason: node.url == nil ? "This item does not have a filesystem URL." : nil,
            warnings: decision.warnings
        )
    }

    private func itemCount(inSubtreeRootedAt id: NodeID) -> Int {
        snapshot?.subtreeIDs(rootedAt: id).count ?? 0
    }

    private func applyProgressiveScanUpdate(
        snapshot: FileTreeSnapshot,
        issues: [ScanIssue],
        progress: ScanProgress
    ) {
        partialScanSnapshot = snapshot
        partialScanIssues = issues
        scanProgress = progress
        if displayRootID == nil {
            displayRootID = snapshot.rootID
        }
        statusText = "Scanning \(displayName(for: progress.rootURL)): \(ByteCount.string(progress.allocatedBytes))."
    }

    private func share(_ bytes: Int64, of total: Int64) -> Double {
        guard total > 0 else { return 0 }
        return Double(bytes) / Double(total)
    }

    private func percentageString(_ share: Double) -> String {
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

    private func handleTrashResult(_ result: TrashActionResult, nodeID: NodeID, nodeName: String) {
        switch result {
        case .moved:
            reconcileMovedToTrash(nodeID: nodeID, nodeName: nodeName)
        case .cancelled:
            statusText = "Move to Trash cancelled."
        case let .permissionDenied(message):
            statusText = "Permission denied moving \(nodeName) to Trash: \(message)"
        case let .partialFailure(message):
            reconcileMovedToTrash(
                nodeID: nodeID,
                nodeName: nodeName,
                successStatusText: "Moved \(nodeName), but macOS reported a partial failure: \(message)"
            )
        case let .failed(message):
            statusText = "Could not move \(nodeName) to Trash: \(message)"
        }
    }

    private func reconcileMovedToTrash(
        nodeID: NodeID,
        nodeName: String,
        successStatusText: String? = nil
    ) {
        guard var scanResult = result,
              var snapshot = result?.snapshot,
              let removedIDs = result?.snapshot.subtreeIDs(rootedAt: nodeID),
              let removed = snapshot.detachSubtree(rootedAt: nodeID) else {
            statusText = "Moved \(nodeName) to Trash. Rescanning..."
            if let currentScanURL {
                scan(currentScanURL)
            }
            return
        }

        scanResult.snapshot = snapshot
        scanResult.summary.fileCount = max(0, scanResult.summary.fileCount - removed.fileCount)
        scanResult.summary.folderCount = max(0, scanResult.summary.folderCount - removed.folderCount)
        scanResult.summary.logicalBytes = max(0, scanResult.summary.logicalBytes - removed.logicalBytes)
        scanResult.summary.allocatedBytes = max(0, scanResult.summary.allocatedBytes - removed.allocatedBytes)

        result = scanResult
        selectedID = nil
        syntheticOtherSelection = nil
        expandedTreemapNodeIDsStorage.subtract(removedIDs)
        if displayRootID == nodeID {
            displayRootID = snapshot.rootID
        }
        statusText = successStatusText ?? "Moved \(nodeName) to Trash."
    }

    private func reconcileExpandedPackage(
        nodeID: NodeID,
        nodeName: String,
        expandedSnapshot: FileTreeSnapshot
    ) {
        guard var scanResult = result,
              var snapshot = result?.snapshot,
              let expanded = snapshot.expandPackageSubtree(rootedAt: nodeID, with: expandedSnapshot) else {
            statusText = "Could not expand \(nodeName)."
            return
        }

        scanResult.snapshot = snapshot
        scanResult.summary.logicalBytes = max(0, scanResult.summary.logicalBytes + expanded.logicalDelta)
        scanResult.summary.allocatedBytes = max(0, scanResult.summary.allocatedBytes + expanded.allocatedDelta)
        result = scanResult
        selectedID = nodeID
        syntheticOtherSelection = nil
        expandedTreemapNodeIDsStorage.insert(nodeID)
        statusText = expanded.appendedNodeIDs.isEmpty
            ? "\(nodeName) has no visible contents to expand."
            : "Expanded \(nodeName)."
    }

    private func isNavigableContainer(_ node: FileNode) -> Bool {
        guard !node.children.isEmpty else { return false }
        return node.kind == .directory || node.kind == .package
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

private struct SnapshotDerivedKey: Hashable, Sendable {
    var snapshotRootID: NodeID
    var displayRootID: NodeID
    var nodeCount: Int
    var nodeStorageAddress: UInt
    var rootLogicalSize: Int64
    var rootAllocatedSize: Int64
    var displayRootLogicalSize: Int64
    var displayRootAllocatedSize: Int64

    init(snapshot: FileTreeSnapshot, displayRootID: NodeID) {
        self.snapshotRootID = snapshot.rootID
        self.displayRootID = displayRootID
        self.nodeCount = snapshot.nodes.count
        self.nodeStorageAddress = snapshot.nodes.withUnsafeBufferPointer { buffer in
            buffer.baseAddress.map { UInt(bitPattern: $0) } ?? 0
        }
        self.rootLogicalSize = snapshot.root?.logicalSize ?? 0
        self.rootAllocatedSize = snapshot.root?.allocatedSize ?? 0
        self.displayRootLogicalSize = snapshot[displayRootID]?.logicalSize ?? 0
        self.displayRootAllocatedSize = snapshot[displayRootID]?.allocatedSize ?? 0
    }
}

private struct SearchIndexCache {
    var key: SnapshotDerivedKey
    var index: FileSearchIndex
}

private struct SearchBuildOutput: Sendable {
    var index: FileSearchIndex
    var results: [SearchResultSummary]
}

private enum SidebarDerivedBuilder {
    static func build(
        sections: Set<SidebarSection>,
        snapshot: FileTreeSnapshot,
        displayRoot: FileNode
    ) -> SidebarPanelState {
        SidebarPanelState(
            browseItems: buildBrowseItems(snapshot: snapshot, displayRoot: displayRoot),
            largestFileItems: sections.contains(.largestFiles)
                ? buildLargestDescendantFileSummaries(snapshot: snapshot, displayRoot: displayRoot)
                : [],
            categoryUsageItems: sections.contains(.typeUsage)
                ? buildCategoryUsageSummaries(snapshot: snapshot, displayRoot: displayRoot)
                : [],
            loadingSections: [],
            errors: [:]
        )
    }

    private static func buildBrowseItems(
        snapshot: FileTreeSnapshot,
        displayRoot: FileNode
    ) -> [SidebarItemSummary] {
        snapshot.children(of: displayRoot.id)
            .filter { $0.allocatedSize > 0 }
            .sorted { lhs, rhs in
                if lhs.allocatedSize == rhs.allocatedSize {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.allocatedSize > rhs.allocatedSize
            }
            .map { node in
                SidebarItemSummary(
                    id: node.id,
                    name: DerivedFormatting.displayName(for: node),
                    kind: DerivedFormatting.displayName(for: node.kind),
                    sizeText: ByteCount.string(node.allocatedSize),
                    path: node.url?.path,
                    isContainer: isNavigableContainer(node)
                )
            }
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

private enum SearchDerivedBuilder {
    static func build(
        snapshot: FileTreeSnapshot,
        key: SnapshotDerivedKey,
        query: String,
        cachedIndex: FileSearchIndex?
    ) -> SearchBuildOutput {
        let index = cachedIndex ?? FileSearchIndex(
            snapshot: snapshot,
            rootedAt: key.displayRootID,
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

private enum DerivedFormatting {
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

struct SidebarPanelState: Hashable, Sendable {
    var browseItems: [SidebarItemSummary]
    var largestFileItems: [DescendantFileSummary]
    var categoryUsageItems: [CategoryUsageSummary]
    var loadingSections: Set<SidebarSection>
    var errors: [SidebarSection: String]

    static let empty = SidebarPanelState(
        browseItems: [],
        largestFileItems: [],
        categoryUsageItems: [],
        loadingSections: [],
        errors: [:]
    )

    static func loading(sections: Set<SidebarSection>) -> SidebarPanelState {
        SidebarPanelState(
            browseItems: [],
            largestFileItems: [],
            categoryUsageItems: [],
            loadingSections: sections,
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

enum SidebarSection: String, CaseIterable, Hashable, Identifiable, Sendable {
    case browse
    case largestFiles
    case typeUsage
    case access

    var id: Self { self }
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

struct SidebarItemSummary: Identifiable, Hashable, Sendable {
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
