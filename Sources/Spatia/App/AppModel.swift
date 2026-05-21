import Foundation
import SpatiaCore
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var result: ScanResult? {
        didSet {
            scheduleCanvasDerivedRefresh(force: true)
            scheduleSearchRefresh(debounce: false)
        }
    }

    @Published var selectedID: NodeID?
    @Published var displayRootID: NodeID? {
        didSet {
            scheduleCanvasDerivedRefresh(force: true)
            scheduleSearchRefresh(debounce: false)
        }
    }

    @Published var isScanning = false
    @Published var statusText = "Choose a folder to scan."
    @Published var currentScanURL: URL?
    @Published var scanPreferences = ScanPreferences()
    @Published var isRightInspectorVisible = false {
        didSet {
            guard oldValue != isRightInspectorVisible else { return }
            scheduleCanvasDerivedRefresh(force: true)
        }
    }
    @Published var isSearchPresented = false
    @Published var searchScope: SearchScope = .scan {
        didSet {
            guard oldValue != searchScope else { return }
            scheduleSearchRefresh(debounce: false)
        }
    }

    @Published var searchQuery = "" {
        didSet {
            scheduleSearchRefresh(debounce: true)
        }
    }

    @Published private(set) var canvasDerivedState = CanvasDerivedState.empty
    @Published private(set) var searchState = SearchState.empty(query: "")
    @Published private var partialScanSnapshot: FileTreeSnapshot? {
        didSet {
            scheduleCanvasDerivedRefresh(force: false)
            scheduleSearchRefresh(debounce: false)
        }
    }

    @Published private var partialScanIssues: [ScanIssue] = []
    @Published private var scanProgress: ScanProgress?
    @Published private var syntheticOtherSelection: SyntheticOtherSelection?
    @Published private var expandedTreemapNodeIDsStorage: Set<NodeID> = []

    var confirmMoveToTrash: @MainActor (TrashConfirmation) -> Bool = MacActions.confirmMoveToTrash
    var moveToTrash: (URL) async -> TrashActionResult = MacActions.moveToTrash
    var quickLookFile: @MainActor (URL) -> QuickLookResult = MacActions.quickLook
    var revealInFinder: @MainActor (URL) -> Void = MacActions.reveal
    var copyPathToPasteboard: @MainActor (URL) -> Void = MacActions.copyPath
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
    private var fileActionGeneration = 0
    private var lastProgressiveDerivedRefresh = Date.distantPast
    private var searchIndexCache: SearchIndexCache?
    private var hoveredTreemapNodeID: NodeID?
    private var hoverStatusRestoreText: String?
    private let pathRiskPolicy: PathRiskPolicy
    private let safetyPolicy: SafetyPolicy

    init(pathRiskPolicy: PathRiskPolicy = PathRiskPolicy()) {
        self.pathRiskPolicy = pathRiskPolicy
        self.safetyPolicy = SafetyPolicy(pathRiskPolicy: pathRiskPolicy)
    }

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

    var currentViewSummary: CanvasViewSummary? {
        canvasDerivedState.currentViewSummary
    }

    var currentViewItems: [CurrentViewItemSummary] {
        canvasDerivedState.currentViewItems
    }

    var insightLargestFileItems: [DescendantFileSummary] {
        canvasDerivedState.largestFileItems
    }

    var insightCategoryUsageItems: [CategoryUsageSummary] {
        canvasDerivedState.categoryUsageItems
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
        invalidatePendingFileActions()

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
        invalidatePendingFileActions()
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

    func openCurrentViewItem(_ id: NodeID) {
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

    func openSearchResult(_ id: NodeID) {
        guard id != syntheticOtherNodeID,
              let snapshot,
              snapshot[id] != nil else {
            return
        }

        let currentRootID = displayRoot?.id
        if currentRootID == nil || !isNode(id, inSubtreeRootedAt: currentRootID) {
            displayRootID = snapshot.rootID
        }
        select(id)
    }

    func focusSearch() {
        isSearchPresented = true
        isRightInspectorVisible = true
    }

    func clearSearch() {
        searchQuery = ""
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
        let actionGeneration = beginFileAction()
        let result = await moveToTrash(url)
        guard isCurrentFileAction(actionGeneration) else { return }
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
        let actionGeneration = beginFileAction()
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
        guard isCurrentFileAction(actionGeneration) else { return }

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

    func isCanvasScopeLoading(_ scope: CanvasDerivedScope) -> Bool {
        canvasDerivedState.loadingScopes.contains(scope)
    }

    private func scheduleCanvasDerivedRefresh(force: Bool) {
        guard let snapshot, let displayRoot else {
            activeDerivedTask?.cancel()
            activeDerivedTask = nil
            canvasDerivedState = .empty
            return
        }

        let now = Date()
        if isScanning && !force && now.timeIntervalSince(lastProgressiveDerivedRefresh) < 0.75 {
            return
        }
        lastProgressiveDerivedRefresh = now

        activeDerivedTask?.cancel()
        let key = SnapshotDerivedKey(snapshot: snapshot, displayRootID: displayRoot.id)
        let scopes = canvasScopesToBuild()
        derivedGeneration += 1
        let generation = derivedGeneration
        canvasDerivedState = .loading(scopes: scopes)

        activeDerivedTask = Task { [snapshot, displayRoot, scopes, key, generation] in
            let state = await Task.detached(priority: .utility) {
                CanvasDerivedBuilder.build(scopes: scopes, snapshot: snapshot, displayRoot: displayRoot)
            }.value

            guard !Task.isCancelled,
                  generation == derivedGeneration,
                  scopes == canvasScopesToBuild(),
                  currentSnapshotDerivedKey() == key else {
                return
            }

            canvasDerivedState = state
            activeDerivedTask = nil
        }
    }

    private func scheduleSearchRefresh(debounce: Bool) {
        activeSearchTask?.cancel()

        let query = searchQuery
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let snapshot else {
            searchState = .empty(query: query)
            return
        }

        let searchRootID: NodeID
        switch searchScope {
        case .scan:
            searchRootID = snapshot.rootID
        case .currentView:
            guard let displayRoot else {
                searchState = .empty(query: query)
                return
            }
            searchRootID = displayRoot.id
        }

        let key = SnapshotDerivedKey(
            snapshot: snapshot,
            displayRootID: searchRootID,
            searchRootID: searchRootID
        )
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
                  currentSearchDerivedKey() == key else {
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
        canvasDerivedState = .empty
        searchState = .empty(query: searchQuery)
        lastProgressiveDerivedRefresh = Date.distantPast
    }

    private func beginFileAction() -> Int {
        fileActionGeneration += 1
        return fileActionGeneration
    }

    private func invalidatePendingFileActions() {
        fileActionGeneration += 1
    }

    private func isCurrentFileAction(_ generation: Int) -> Bool {
        generation == fileActionGeneration
    }

    private func canvasScopesToBuild() -> Set<CanvasDerivedScope> {
        var scopes: Set<CanvasDerivedScope> = [.currentView]
        if isRightInspectorVisible {
            scopes.insert(.largestFiles)
            scopes.insert(.typeUsage)
        }
        return scopes
    }

    private func currentSnapshotDerivedKey() -> SnapshotDerivedKey? {
        guard let snapshot, let displayRoot else { return nil }
        return SnapshotDerivedKey(snapshot: snapshot, displayRootID: displayRoot.id)
    }

    private func currentSearchDerivedKey() -> SnapshotDerivedKey? {
        guard let snapshot else { return nil }
        switch searchScope {
        case .scan:
            return SnapshotDerivedKey(
                snapshot: snapshot,
                displayRootID: snapshot.rootID,
                searchRootID: snapshot.rootID
            )
        case .currentView:
            guard let displayRoot else { return nil }
            return SnapshotDerivedKey(
                snapshot: snapshot,
                displayRootID: displayRoot.id,
                searchRootID: displayRoot.id
            )
        }
    }

    private func isNode(_ id: NodeID, inSubtreeRootedAt rootID: NodeID?) -> Bool {
        guard let rootID, let snapshot else { return false }
        return snapshot.breadcrumb(for: id).contains { $0.id == rootID }
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
