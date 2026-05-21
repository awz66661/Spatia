import SpatiaCore
import SwiftUI

enum DesignTokens {
    static let rowIconColumnWidth: CGFloat = 24
    static let treemapInset: CGFloat = 10
    static let currentViewStripHeight: CGFloat = 52
    static let minimumWindowHeight: CGFloat = 700

    static var selectedRowBackground: Color {
        Color(nsColor: .selectedContentBackgroundColor).opacity(0.16)
    }
}

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
        } detail: {
            DetailWorkspaceView()
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            model.goUp()
                        } label: {
                            Label("Up", systemImage: "chevron.up")
                        }
                        .labelStyle(.iconOnly)
                        .disabled(model.displayRoot?.parentID == nil)
                        .help("Up")
                    }

                    ToolbarItem(placement: .principal) {
                        BreadcrumbPathBar(nodes: model.breadcrumb) { nodeID in
                            model.navigateToBreadcrumb(nodeID)
                        }
                        .frame(maxWidth: 560)
                    }

                    ToolbarItemGroup(placement: .primaryAction) {
                        ControlGroup {
                            ScanFolderButton()

                            Button {
                                model.rescanCurrentSource()
                            } label: {
                                Label("Rescan", systemImage: "arrow.clockwise")
                            }
                            .labelStyle(.iconOnly)
                            .disabled(model.currentScanURL == nil || model.isScanning)
                            .help("Rescan Current")
                        }
                    }

                    if model.isScanning {
                        ToolbarItem(placement: .cancellationAction) {
                            Button {
                                model.cancelScan()
                            } label: {
                                Label("Cancel Scan", systemImage: "xmark.circle")
                            }
                            .labelStyle(.iconOnly)
                            .help("Cancel Scan")
                        }
                    }

                    ToolbarItem(placement: .primaryAction) {
                        Button {
                            model.isRightInspectorVisible.toggle()
                        } label: {
                            Label(
                                model.isRightInspectorVisible ? "Hide Inspector" : "Show Inspector",
                                systemImage: "sidebar.trailing"
                            )
                        }
                        .labelStyle(.iconOnly)
                        .help(model.isRightInspectorVisible ? "Hide Inspector" : "Show Inspector")
                    }
                }
        }
        .navigationSplitViewStyle(.prominentDetail)
        .searchable(
            text: Binding(
                get: { model.searchQuery },
                set: { model.searchQuery = $0 }
            ),
            isPresented: Binding(
                get: { model.isSearchPresented },
                set: { model.isSearchPresented = $0 }
            ),
            placement: .toolbar,
            prompt: "Name, path, kind, or category"
        )
        .onSubmit(of: .search) {
            if let firstResult = model.searchResultSummaries.first {
                model.openSearchResult(firstResult.id)
            }
        }
    }
}

private struct DetailWorkspaceView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkspaceColumnLayout(
                availableWidth: proxy.size.width,
                showsInspector: model.isRightInspectorVisible
            )

            ZStack(alignment: .topTrailing) {
                HStack(spacing: 0) {
                    TreemapDetailView()
                        .frame(width: layout.canvasWidth, height: proxy.size.height)

                    if layout.showsInspector {
                        Divider()

                        RightInspectorView()
                            .frame(width: layout.inspectorWidth, height: proxy.size.height)
                            .background(Color(nsColor: .controlBackgroundColor))
                    }
                }

                if model.isSearchPresented {
                    SearchResultsPanel()
                        .padding(.top, 10)
                        .padding(.trailing, 14)
                }
            }
        }
    }
}

private struct WorkspaceColumnLayout {
    private static let inspectorTargetShare: CGFloat = 0.30
    private static let inspectorMaximumShare: CGFloat = 0.42
    private static let inspectorMaximumWidth: CGFloat = 360
    private static let dividerWidth: CGFloat = 1

    let availableWidth: CGFloat
    let showsInspector: Bool

    var inspectorWidth: CGFloat {
        guard showsInspector else { return 0 }
        let targetWidth = availableWidth * Self.inspectorTargetShare
        let maximumWidth = min(Self.inspectorMaximumWidth, availableWidth * Self.inspectorMaximumShare)
        return min(targetWidth, maximumWidth)
    }

    var canvasWidth: CGFloat {
        guard showsInspector else { return availableWidth }
        return max(0, availableWidth - inspectorWidth - Self.dividerWidth)
    }
}

private struct TreemapDetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let snapshot = model.snapshot, let rootID = model.displayRoot?.id {
                TreemapCanvas(
                    snapshot: snapshot,
                    rootID: rootID,
                    expandedNodeIDs: model.expandedTreemapNodeIDs,
                    highlightedNodeIDs: model.selectedPathNodeIDs,
                    selectedID: Binding(
                        get: { model.selectedID },
                        set: { model.select($0) }
                    ),
                    onActivate: { nodeID in
                        model.enterDirectory(nodeID)
                    },
                    onPreview: { nodeID in
                        model.quickLook(nodeID)
                    },
                    onExpandPackage: { nodeID in
                        model.select(nodeID)
                        Task {
                            await model.expandSelectedPackage()
                        }
                    },
                    onReveal: { nodeID in
                        model.select(nodeID)
                        model.revealSelectedInFinder()
                    },
                    onCopyPath: { nodeID in
                        model.select(nodeID)
                        model.copySelectedPath()
                    },
                    onMoveToTrash: { nodeID in
                        model.select(nodeID)
                        Task {
                            await model.moveSelectedItemToTrash()
                        }
                    },
                    onHover: { nodeID in
                        model.hoverTreemapNode(nodeID)
                    },
                    onSyntheticOtherSelect: { size in
                        model.selectSyntheticOther(size: size)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DesignTokens.treemapInset)
            } else {
                ContentUnavailableView(
                    model.isScanning ? "Scanning" : "No Scan",
                    systemImage: model.isScanning ? "arrow.triangle.2.circlepath" : "square.grid.3x3",
                    description: Text(model.isScanning ? model.statusText : "Choose a folder to build a space map.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

private struct SearchResultsPanel: View {
    @EnvironmentObject private var model: AppModel

    private var hasQuery: Bool {
        !model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        if hasQuery {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Scope", selection: Binding(
                    get: { model.searchScope },
                    set: { model.searchScope = $0 }
                )) {
                    ForEach(SearchScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()

                if model.isSearchLoading {
                    SearchPanelStatusRow(text: "Searching...", systemImage: "magnifyingglass")
                } else if model.searchResultSummaries.isEmpty {
                    SearchPanelStatusRow(
                        text: model.searchScope == .scan ? "No matches in this scan." : "No matches in this view.",
                        systemImage: "magnifyingglass"
                    )
                } else {
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 2) {
                            ForEach(model.searchResultSummaries) { item in
                                Button {
                                    model.openSearchResult(item.id)
                                    model.isSearchPresented = false
                                } label: {
                                    SearchResultPanelRow(
                                        item: item,
                                        isSelected: model.selectedID == item.id
                                    )
                                }
                                .buttonStyle(.plain)
                                .help(item.relativePath)
                            }
                        }
                    }
                    .frame(maxHeight: 360)
                }
            }
            .padding(10)
            .frame(width: 430)
            .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 10)
        }
    }
}

private struct SearchPanelStatusRow: View {
    var text: String
    var systemImage: String

    var body: some View {
        Label(text, systemImage: systemImage)
            .font(.callout)
            .foregroundStyle(.secondary)
            .padding(.vertical, 4)
    }
}

private struct SearchResultPanelRow: View {
    var item: SearchResultSummary
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 9) {
            RoundedRectangle(cornerRadius: 3, style: .continuous)
                .fill(CategoryPalette.color(for: item.category))
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text("\(item.relativePath) - \(item.kind) - \(item.categoryName)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text(item.sizeText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .lineLimit(1)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isSelected ? DesignTokens.selectedRowBackground : Color.clear)
        }
        .contentShape(Rectangle())
    }
}
