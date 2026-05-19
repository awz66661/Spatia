import SpatiaCore
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HSplitView {
            GlassPanel {
                SidebarView()
            }
            .frame(minWidth: 210, idealWidth: 240, maxWidth: 300)

            TreemapDetailView()
                .frame(minWidth: 520)

            GlassPanel(material: .hudWindow) {
                InspectorView()
            }
            .frame(minWidth: 280, idealWidth: 320, maxWidth: 380)
        }
        .toolbar {
            ToolbarItemGroup {
                Button {
                    model.chooseFolder()
                } label: {
                    Label("Choose Folder", systemImage: "folder.badge.plus")
                }

                Button {
                    model.goUp()
                } label: {
                    Label("Up", systemImage: "chevron.up")
                }
                .disabled(model.displayRoot?.parentID == nil)
            }

            ToolbarItem(placement: .principal) {
                VStack(spacing: 1) {
                    BreadcrumbView(nodes: model.breadcrumb)
                    Text(model.statusText)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Locations")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.top, 14)

            VStack(alignment: .leading, spacing: 4) {
                SidebarButton(title: "Downloads", systemImage: "arrow.down.circle", action: model.scanDownloads)
                SidebarButton(title: "Desktop", systemImage: "desktopcomputer", action: model.scanDesktop)
                SidebarButton(title: "Documents", systemImage: "doc.text", action: model.scanDocuments)
                SidebarButton(title: "Applications", systemImage: "app.dashed", action: model.scanApplications)
                SidebarButton(title: "Home", systemImage: "house", action: model.scanHome)
                SidebarButton(title: "Choose Folder", systemImage: "folder.badge.plus", action: model.chooseFolder)
            }

            if let currentScanURL = model.currentScanURL {
                Divider()
                    .padding(.vertical, 2)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Current Scan")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                    Text(currentScanURL.path)
                        .font(.caption)
                        .textSelection(.enabled)
                        .lineLimit(4)
                }
            }

            PermissionSummaryView(issues: model.permissionIssues)

            Spacer()
        }
        .padding(.horizontal, 14)
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
        .padding(.vertical, 5)
        .padding(.horizontal, 8)
        .background(.quaternary.opacity(0.35), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }
}

private struct PermissionSummaryView: View {
    var issues: [ScanIssue]

    var body: some View {
        if !issues.isEmpty {
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
            .padding(.top, 4)
        }
    }
}

private struct TreemapDetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(spacing: 0) {
            if model.isScanning {
                ProgressView()
                    .controlSize(.small)
                    .padding(.top, 10)
            }

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
            } else {
                ContentUnavailableView(
                    "No Scan",
                    systemImage: "square.grid.3x3",
                    description: Text("Choose a folder to build a space map.")
                )
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct InspectorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inspector")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
                .padding(.top, 12)

            if let node = model.selectedNode {
                VStack(alignment: .leading, spacing: 8) {
                    Text(node.name)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .lineLimit(3)

                    InfoRow(label: "Kind", value: node.kind.rawValue)
                    InfoRow(label: "Disk Usage", value: ByteCount.string(node.allocatedSize))
                    InfoRow(label: "File Size", value: ByteCount.string(node.logicalSize))
                    InfoRow(label: "Category", value: FileCategoryClassifier.category(for: node).rawValue)

                    if let modifiedAt = node.modifiedAt {
                        InfoRow(label: "Modified", value: modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    if let url = node.url {
                        Text(url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(5)

                        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
                            GridRow {
                                Button {
                                    model.quickLookSelected()
                                } label: {
                                    Label("Quick Look", systemImage: "eye")
                                }
                                .disabled(!model.canQuickLookSelected)

                                Button {
                                    MacActions.reveal(url)
                                } label: {
                                    Label("Reveal", systemImage: "arrow.up.forward.app")
                                }
                            }

                            GridRow {
                                Button {
                                    MacActions.copyPath(url)
                                } label: {
                                    Label("Copy Path", systemImage: "doc.on.doc")
                                }
                                .gridCellColumns(2)
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
                Text("Select a tile to inspect it.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
    }
}

private struct InfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
                .lineLimit(2)
        }
        .font(.callout)
    }
}

private struct BreadcrumbView: View {
    var nodes: [FileNode]

    var body: some View {
        HStack(spacing: 4) {
            ForEach(nodes, id: \.id) { node in
                Text(node.name)
                    .lineLimit(1)
                if node.id != nodes.last?.id {
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.callout)
        .frame(maxWidth: 560)
    }
}
