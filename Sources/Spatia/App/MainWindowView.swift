import SpatiaCore
import SwiftUI

private enum DesignTokens {
    static let sidebarMinWidth: CGFloat = 260
    static let sidebarIdealWidth: CGFloat = 300
    static let sidebarMaxWidth: CGFloat = 360
    static let sidebarIconColumnWidth: CGFloat = 24
    static let detailMinWidth: CGFloat = 700
    static let treemapInset: CGFloat = 16
    static let inspectorCornerRadius: CGFloat = 18
    static let sidebarTitlebarInset: CGFloat = 58

    static var windowBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

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
                .navigationSplitViewColumnWidth(
                    min: DesignTokens.sidebarMinWidth,
                    ideal: DesignTokens.sidebarIdealWidth,
                    max: DesignTokens.sidebarMaxWidth
                )
        } detail: {
            TreemapDetailView()
                .frame(minWidth: DesignTokens.detailMinWidth)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .containerBackground(DesignTokens.windowBackground, for: .window)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ScanSourceMenu()
            }

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

            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.rescanCurrentSource()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .disabled(model.currentScanURL == nil || model.isScanning)
                .help("Rescan Current")
            }

            ToolbarItem(placement: .primaryAction) {
                StatusPill(text: model.statusText, isScanning: model.isScanning)
            }
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.thinMaterial)
                .ignoresSafeArea(.container, edges: [.top, .bottom, .leading])

            List {
                Section("Current Scan") {
                    SidebarSourceSummaryView(
                        overview: model.scanOverview,
                        currentScanURL: model.currentScanURL,
                        isScanning: model.isScanning,
                        statusText: model.statusText
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 14))
                }

                Section("Largest Here") {
                    if model.largestDisplayRootChildren.isEmpty {
                        SidebarEmptyNavigationView(hasScan: model.snapshot != nil)
                    } else {
                        ForEach(model.largestDisplayRootChildren) { item in
                            SidebarLargestRow(
                                item: item,
                                isSelected: model.selectedID == item.id
                            ) {
                                model.openSidebarItem(item.id)
                            }
                            .listRowBackground(model.selectedID == item.id ? DesignTokens.selectedRowBackground : Color.clear)
                        }
                    }
                }

                if !model.permissionIssues.isEmpty {
                    Section("Access") {
                        PermissionSummaryView(issues: model.permissionIssues)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: DesignTokens.sidebarTitlebarInset)
            }
        }
    }
}

private struct ScanSourceMenu: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Menu {
            Button("Downloads", systemImage: "arrow.down.circle") {
                model.scanDownloads()
            }

            Button("Desktop", systemImage: "desktopcomputer") {
                model.scanDesktop()
            }

            Button("Documents", systemImage: "doc.text") {
                model.scanDocuments()
            }

            Button("Applications", systemImage: "app.dashed") {
                model.scanApplications()
            }

            Button("Home", systemImage: "house") {
                model.scanHome()
            }

            Divider()

            Button("Choose Folder...", systemImage: "folder.badge.plus") {
                model.chooseFolder()
            }
        } label: {
            Label("Scan Source", systemImage: "folder.badge.plus")
        }
        .labelStyle(.iconOnly)
        .help("Scan Source")
    }
}

private struct SidebarSourceSummaryView: View {
    var overview: ScanOverview?
    var currentScanURL: URL?
    var isScanning: Bool
    var statusText: String

    var body: some View {
        if let overview {
            VStack(alignment: .leading, spacing: 10) {
                Label(overview.sourceName, systemImage: "folder")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                VStack(spacing: 6) {
                    SidebarMetricRow(label: "Disk", value: overview.diskUsage)
                    SidebarMetricRow(label: "Files", value: overview.fileCount)
                    SidebarMetricRow(label: "Folders", value: overview.folderCount)
                    SidebarMetricRow(label: "Scan", value: overview.duration)
                }

                Text(overview.sourcePath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)
            }
        } else if let currentScanURL {
            VStack(alignment: .leading, spacing: 8) {
                Label(sourceName(for: currentScanURL), systemImage: isScanning ? "arrow.triangle.2.circlepath" : "folder")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(currentScanURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("No Scan", systemImage: "square.grid.3x3")
                    .font(.headline)

                Text("Choose a folder from the toolbar scan menu to build a space map.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sourceName(for url: URL) -> String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }
}

private struct SidebarEmptyNavigationView: View {
    var hasScan: Bool

    var body: some View {
        Text(hasScan ? "This location has no sizeable children." : "Scan a folder to browse its largest items.")
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SidebarMetricRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .fontWeight(.medium)
                .frame(width: 92, alignment: .trailing)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}

private struct SidebarLargestRow: View {
    var item: DisplayRootChildSummary
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: item.isContainer ? "folder" : "doc")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: DesignTokens.sidebarIconColumnWidth, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.callout)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.kind)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.sizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 66, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.path ?? item.name)
    }
}

private struct PermissionSummaryView: View {
    var issues: [ScanIssue]

    var body: some View {
        DisclosureGroup {
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(issues.enumerated()), id: \.offset) { _, issue in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.url.path)
                            .font(.caption)
                            .textSelection(.enabled)
                            .lineLimit(3)
                        Text(issue.kind == .permissionDenied ? "Full Disk Access may be required." : issue.message)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                Text("macOS protects some locations. You can keep using partial results or grant Full Disk Access in System Settings.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
        } label: {
            Label("\(issues.count) unreadable location\(issues.count == 1 ? "" : "s")", systemImage: "lock")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
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
                    selectedID: Binding(
                        get: { model.selectedID },
                        set: { model.select($0) }
                    ),
                    onActivate: { nodeID in
                        model.enterDirectory(nodeID)
                    },
                    onPreview: { nodeID in
                        model.quickLook(nodeID)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DesignTokens.treemapInset)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let detail = model.selectedNodeDetail {
                        SelectionDetailPanel(detail: detail)
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                    }
                }
            } else {
                ContentUnavailableView(
                    model.isScanning ? "Scanning" : "No Scan",
                    systemImage: model.isScanning ? "arrow.triangle.2.circlepath" : "square.grid.3x3",
                    description: Text(model.isScanning ? model.statusText : "Choose a folder to build a space map.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DesignTokens.windowBackground)
    }
}

private struct SelectionDetailPanel: View {
    @EnvironmentObject private var model: AppModel
    var detail: SelectionDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.name)
                        .font(.headline)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    if let path = detail.path {
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SelectionActionGroup(detail: detail)
            }

            SelectionInfoStrip(detail: detail)

            if detail.isProtected {
                Label(detail.riskReason ?? "Protected locations are shown with reduced color intensity.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !detail.canMoveToTrash, let reason = detail.trashDisabledReason {
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if !detail.trashWarnings.isEmpty {
                Label(detail.trashWarnings.joined(separator: " "), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: DesignTokens.inspectorCornerRadius, style: .continuous))
    }
}

private struct SelectionActionGroup: View {
    @EnvironmentObject private var model: AppModel
    var detail: SelectionDetail

    var body: some View {
        HStack(spacing: 8) {
            Button {
                model.quickLookSelected()
            } label: {
                Image(systemName: "eye")
            }
            .disabled(!detail.canQuickLook)
            .help("Quick Look")

            if let url = detail.url {
                Button {
                    MacActions.reveal(url)
                } label: {
                    Image(systemName: "arrow.up.forward.app")
                }
                .help("Reveal in Finder")

                Button {
                    MacActions.copyPath(url)
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .help("Copy Path")
            }

            Button {
                Task {
                    await model.moveSelectedItemToTrash()
                }
            } label: {
                Image(systemName: "trash")
            }
            .disabled(!detail.canMoveToTrash)
            .help(detail.canMoveToTrash ? "Move to Trash" : detail.trashDisabledReason ?? "Move to Trash unavailable")
        }
        .controlSize(.small)
    }
}

private struct SelectionInfoStrip: View {
    var detail: SelectionDetail

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                InfoPair(label: "Kind", value: detail.kind)
                InfoPair(label: "Disk", value: detail.diskUsage)
                InfoPair(label: "Size", value: detail.fileSize)
                InfoPair(label: "Category", value: detail.category)
                if let modified = detail.modified {
                    InfoPair(label: "Modified", value: modified)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 12) {
                    InfoPair(label: "Kind", value: detail.kind)
                    InfoPair(label: "Disk", value: detail.diskUsage)
                    InfoPair(label: "Size", value: detail.fileSize)
                }

                HStack(spacing: 12) {
                    InfoPair(label: "Category", value: detail.category)
                    if let modified = detail.modified {
                        InfoPair(label: "Modified", value: modified)
                    }
                }
            }
        }
    }
}

private struct InfoPair: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
        }
        .frame(minWidth: 84, maxWidth: 160, alignment: .leading)
    }
}

private struct StatusPill: View {
    var text: String
    var isScanning: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isScanning {
                ProgressView()
                    .controlSize(.mini)
                    .scaleEffect(0.7)
            }

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .frame(maxWidth: 240)
    }
}

private struct BreadcrumbPathBar: View {
    var nodes: [FileNode]
    var onNavigate: (NodeID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                if nodes.isEmpty {
                    Text("Choose a folder")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                        Button {
                            onNavigate(node.id)
                        } label: {
                            Text(displayName(for: node))
                                .font(.callout)
                                .fontWeight(index == nodes.count - 1 ? .semibold : .regular)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .padding(.horizontal, index == nodes.count - 1 ? 10 : 0)
                                .padding(.vertical, index == nodes.count - 1 ? 4 : 0)
                                .frame(maxWidth: index == nodes.count - 1 ? 240 : 140)
                                .background {
                                    if index == nodes.count - 1 {
                                        Capsule()
                                            .fill(Color.accentColor.opacity(0.14))
                                    }
                                }
                        }
                        .buttonStyle(.plain)
                        .help(node.url?.path ?? node.name)

                        if index != nodes.count - 1 {
                            Image(systemName: "chevron.right")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 5)
        }
    }

    private func displayName(for node: FileNode) -> String {
        if !node.name.isEmpty { return node.name }
        return node.url?.lastPathComponent.isEmpty == false ? node.url?.lastPathComponent ?? node.name : node.url?.path ?? node.name
    }
}
