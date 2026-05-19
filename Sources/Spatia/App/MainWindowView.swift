import SpatiaCore
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
                .frame(height: DesignTokens.topBarHeight)
                .background(DesignTokens.topBarBackground)
                .overlay(alignment: .bottom) {
                    Divider()
                }

            HSplitView {
                SidebarView()
                    .frame(
                        minWidth: DesignTokens.sidebarMinWidth,
                        idealWidth: DesignTokens.sidebarIdealWidth,
                        maxWidth: DesignTokens.sidebarMaxWidth
                    )
                    .background(DesignTokens.sidePanelBackground)
                    .overlay(alignment: .trailing) {
                        Divider()
                    }

                TreemapDetailView()
                    .frame(minWidth: 620)
            }
        }
        .background(DesignTokens.windowBackground)
    }
}

private enum DesignTokens {
    static let topBarHeight: CGFloat = 58
    static let sidebarMinWidth: CGFloat = 180
    static let sidebarIdealWidth: CGFloat = 204
    static let sidebarMaxWidth: CGFloat = 230
    static let panelPadding: CGFloat = 12
    static let sidebarIconColumnWidth: CGFloat = 26
    static let sidebarIconSize: CGFloat = 22
    static let sidebarButtonHeight: CGFloat = 34
    static let sidebarItemHeight: CGFloat = 44
    static let rowCornerRadius: CGFloat = 6

    static var windowBackground: Color {
        Color(nsColor: .windowBackgroundColor)
    }

    static var topBarBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var sidePanelBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }

    static var detailPanelBackground: Color {
        Color(nsColor: .controlBackgroundColor)
    }
}

private struct TopBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.chooseFolder()
            } label: {
                Label("Choose Folder", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button {
                model.goUp()
            } label: {
                Label("Up", systemImage: "chevron.up")
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(model.displayRoot?.parentID == nil)

            Divider()
                .frame(height: 22)
                .padding(.horizontal, 2)

            BreadcrumbPathBar(nodes: model.breadcrumb) { nodeID in
                model.navigateToBreadcrumb(nodeID)
            }
            .layoutPriority(1)

            Spacer(minLength: 10)

            StatusPill(text: model.statusText, isScanning: model.isScanning)
        }
        .padding(.horizontal, 14)
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 14) {
                SidebarSection(title: "Scan") {
                    VStack(alignment: .leading, spacing: 2) {
                        SidebarButton(title: "Downloads", systemImage: "arrow.down.circle", action: model.scanDownloads)
                        SidebarButton(title: "Desktop", systemImage: "desktopcomputer", action: model.scanDesktop)
                        SidebarButton(title: "Documents", systemImage: "doc.text", action: model.scanDocuments)
                        SidebarButton(title: "Applications", systemImage: "app.dashed", action: model.scanApplications)
                        SidebarButton(title: "Home", systemImage: "house", action: model.scanHome)
                        SidebarButton(title: "Choose Folder", systemImage: "folder.badge.plus", action: model.chooseFolder)
                    }
                }

                if let overview = model.scanOverview {
                    SidebarSection(title: "Overview") {
                        VStack(spacing: 6) {
                            SidebarMetricRow(label: "Source", value: overview.sourceName)
                            SidebarMetricRow(label: "Disk", value: overview.diskUsage)
                            SidebarMetricRow(label: "Files", value: overview.fileCount)
                            SidebarMetricRow(label: "Folders", value: overview.folderCount)
                            SidebarMetricRow(label: "Scan", value: overview.duration)
                        }

                        Text(overview.sourcePath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 2)
                    }
                } else if let currentScanURL = model.currentScanURL {
                    SidebarSection(title: "Source") {
                        Text(currentScanURL.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !model.largestDisplayRootChildren.isEmpty {
                    SidebarSection(title: "Largest Here") {
                        VStack(alignment: .leading, spacing: 3) {
                            ForEach(model.largestDisplayRootChildren) { item in
                                SidebarItemButton(item: item) {
                                    model.openSidebarItem(item.id)
                                }
                            }
                        }
                    }
                }

                PermissionSummaryView(issues: model.permissionIssues)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(.horizontal, DesignTokens.panelPadding)
            .padding(.vertical, 14)
            .background(DesignTokens.sidePanelBackground)
        }
        .scrollContentBackground(.hidden)
        .background(DesignTokens.sidePanelBackground)
    }
}

private struct SidebarSection<Content: View>: View {
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            content
        }
    }
}

private struct SidebarButton: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundStyle(.primary)
                    .frame(
                        width: DesignTokens.sidebarIconColumnWidth,
                        height: DesignTokens.sidebarIconSize,
                        alignment: .center
                    )

                Text(title)
                    .font(.callout)
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: DesignTokens.sidebarButtonHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 7)
        .background(Color(nsColor: .controlColor).opacity(0.35), in: RoundedRectangle(cornerRadius: DesignTokens.rowCornerRadius))
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
        .frame(maxWidth: .infinity, minHeight: 17, alignment: .center)
    }
}

private struct SidebarItemButton: View {
    var item: DisplayRootChildSummary
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: item.isContainer ? "folder" : "doc")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(
                        width: DesignTokens.sidebarIconColumnWidth,
                        height: DesignTokens.sidebarIconSize,
                        alignment: .center
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.kind)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Text(item.sizeText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .frame(width: 62, alignment: .trailing)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: DesignTokens.sidebarItemHeight, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 7)
        .background(Color(nsColor: .controlColor).opacity(0.28), in: RoundedRectangle(cornerRadius: DesignTokens.rowCornerRadius))
        .help(item.path ?? item.name)
    }
}

private struct PermissionSummaryView: View {
    var issues: [ScanIssue]

    var body: some View {
        if !issues.isEmpty {
            SidebarSection(title: "Access") {
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
    }
}

private struct TreemapDetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if let snapshot = model.snapshot, let rootID = model.displayRoot?.id {
                VStack(spacing: 0) {
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
                    .padding(4)

                    if let detail = model.selectedNodeDetail {
                        Divider()
                        SelectionDetailPanel(detail: detail)
                            .background(DesignTokens.detailPanelBackground)
                    }
                }
            } else {
                ContentUnavailableView(
                    "No Scan",
                    systemImage: "square.grid.3x3",
                    description: Text("Choose a folder to build a space map.")
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
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 16) {
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

                VStack(alignment: .leading, spacing: 5) {
                    InfoRow(label: "Kind", value: detail.kind)
                    InfoRow(label: "Disk", value: detail.diskUsage)
                    InfoRow(label: "Size", value: detail.fileSize)
                }
                .frame(width: 170)

                VStack(alignment: .leading, spacing: 5) {
                    InfoRow(label: "Category", value: detail.category)
                    if let modified = detail.modified {
                        InfoRow(label: "Modified", value: modified)
                    }
                }
                .frame(width: 185)

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
                }
                .controlSize(.small)
            }

            if detail.isProtected {
                Label("Protected locations are shown with reduced color intensity.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }
}

private struct InfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 12)
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .font(.callout)
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
        .background(Color(nsColor: .controlColor).opacity(0.45), in: Capsule())
        .frame(maxWidth: 260)
    }
}

private struct BreadcrumbPathBar: View {
    var nodes: [FileNode]
    var onNavigate: (NodeID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                ForEach(Array(nodes.enumerated()), id: \.element.id) { index, node in
                    Button {
                        onNavigate(node.id)
                    } label: {
                        Text(displayName(for: node))
                            .font(.callout)
                            .fontWeight(index == nodes.count - 1 ? .semibold : .regular)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 4)
                            .frame(maxWidth: index == nodes.count - 1 ? 260 : 150)
                            .background(
                                index == nodes.count - 1
                                    ? Color.accentColor.opacity(0.14)
                                    : Color(nsColor: .controlColor).opacity(0.42),
                                in: Capsule()
                            )
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
            .padding(.horizontal, 1)
        }
    }

    private func displayName(for node: FileNode) -> String {
        if !node.name.isEmpty { return node.name }
        return node.url?.lastPathComponent.isEmpty == false ? node.url?.lastPathComponent ?? node.name : node.url?.path ?? node.name
    }
}
