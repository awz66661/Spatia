import SpatiaCore
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            TopBar()
                .frame(height: DesignTokens.topBarHeight)
                .background(DesignTokens.topBarBackground)

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
                    .frame(minWidth: 540)

                InspectorView()
                    .frame(
                        minWidth: DesignTokens.inspectorMinWidth,
                        idealWidth: DesignTokens.inspectorIdealWidth,
                        maxWidth: DesignTokens.inspectorMaxWidth
                    )
                    .background(DesignTokens.sidePanelBackground)
                    .overlay(alignment: .leading) {
                        Divider()
                    }
            }
        }
        .background(DesignTokens.windowBackground)
    }
}

private enum DesignTokens {
    static let topBarHeight: CGFloat = 58
    static let sidebarMinWidth: CGFloat = 220
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat = 260
    static let inspectorMinWidth: CGFloat = 300
    static let inspectorIdealWidth: CGFloat = 320
    static let inspectorMaxWidth: CGFloat = 360
    static let panelPadding: CGFloat = 14
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
        VStack(alignment: .leading, spacing: 16) {
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

            if let currentScanURL = model.currentScanURL {
                SidebarSection(title: "Current Root") {
                    Text(currentScanURL.path)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .lineLimit(5)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            PermissionSummaryView(issues: model.permissionIssues)

            Spacer()
        }
        .padding(.horizontal, DesignTokens.panelPadding)
        .padding(.vertical, 16)
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
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(Color(nsColor: .controlColor).opacity(0.35), in: RoundedRectangle(cornerRadius: DesignTokens.rowCornerRadius))
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
                TreemapCanvas(
                    snapshot: snapshot,
                    rootID: rootID,
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
                .padding(10)
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

private struct InspectorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Selection")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)

                if let node = model.selectedNode {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(node.name)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .lineLimit(4)
                            .textSelection(.enabled)

                        VStack(spacing: 7) {
                            InfoRow(label: "Kind", value: node.kind.rawValue)
                            InfoRow(label: "Disk Usage", value: ByteCount.string(node.allocatedSize))
                            InfoRow(label: "File Size", value: ByteCount.string(node.logicalSize))
                            InfoRow(label: "Category", value: FileCategoryClassifier.category(for: node).rawValue)

                            if let modifiedAt = node.modifiedAt {
                                InfoRow(label: "Modified", value: modifiedAt.formatted(date: .abbreviated, time: .shortened))
                            }
                        }

                        if let url = node.url {
                            Divider()
                                .padding(.vertical, 2)

                            Text(url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .textSelection(.enabled)
                                .lineLimit(6)

                            VStack(spacing: 8) {
                                HStack(spacing: 8) {
                                    Button {
                                        model.quickLookSelected()
                                    } label: {
                                        Label("Quick Look", systemImage: "eye")
                                            .frame(maxWidth: .infinity)
                                    }
                                    .disabled(!model.canQuickLookSelected)

                                    Button {
                                        MacActions.reveal(url)
                                    } label: {
                                        Label("Reveal", systemImage: "arrow.up.forward.app")
                                            .frame(maxWidth: .infinity)
                                    }
                                }

                                Button {
                                    MacActions.copyPath(url)
                                } label: {
                                    Label("Copy Path", systemImage: "doc.on.doc")
                                        .frame(maxWidth: .infinity)
                                }
                            }
                            .controlSize(.small)
                        } else if node.id == syntheticOtherNodeID {
                            Text("Grouped small items are selectable for context, but not navigable.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        if node.flags.contains(.systemProtected) || node.flags.contains(.permissionDenied) {
                            Label("Protected locations are shown with reduced color intensity.", systemImage: "lock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Image(systemName: "cursorarrow.click")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Select a tile to inspect it.")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.panelPadding)
            .padding(.vertical, 16)
        }
        .background(DesignTokens.sidePanelBackground)
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
