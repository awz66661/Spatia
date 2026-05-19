import SpatiaCore
import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HSplitView {
            SidebarView()
                .frame(minWidth: 190, idealWidth: 220, maxWidth: 280)

            TreemapDetailView()
                .frame(minWidth: 520)

            InspectorView()
                .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
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
                BreadcrumbView(nodes: model.breadcrumb)
            }
        }
    }
}

private struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Locations")
                .font(.headline)
                .padding(.top, 12)

            Button {
                model.scanDownloads()
            } label: {
                Label("Downloads", systemImage: "arrow.down.circle")
            }
            .buttonStyle(.borderless)

            Button {
                model.scanHome()
            } label: {
                Label("Home", systemImage: "house")
            }
            .buttonStyle(.borderless)

            Button {
                model.chooseFolder()
            } label: {
                Label("Choose Folder", systemImage: "folder")
            }
            .buttonStyle(.borderless)

            Divider()

            Text(model.statusText)
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(4)

            if let issues = model.result?.issues, !issues.isEmpty {
                Label("\(issues.count) unreadable locations", systemImage: "lock")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .background(.bar)
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

            if model.visibleInputs.isEmpty {
                ContentUnavailableView(
                    "No Scan",
                    systemImage: "square.grid.3x3",
                    description: Text("Choose a folder to build a space map.")
                )
            } else {
                TreemapCanvas(
                    inputs: model.visibleInputs,
                    selectedID: Binding(
                        get: { model.selectedID },
                        set: { model.select($0) }
                    ),
                    onActivate: { nodeID in
                        model.enterDirectory(nodeID)
                    }
                )
            }
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

private struct InspectorView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Inspector")
                .font(.headline)
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

                    if let modifiedAt = node.modifiedAt {
                        InfoRow(label: "Modified", value: modifiedAt.formatted(date: .abbreviated, time: .shortened))
                    }

                    if let url = node.url {
                        Text(url.path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .lineLimit(5)

                        HStack {
                            Button {
                                MacActions.reveal(url)
                            } label: {
                                Label("Reveal", systemImage: "arrow.up.forward.app")
                            }

                            Button {
                                MacActions.copyPath(url)
                            } label: {
                                Label("Copy Path", systemImage: "doc.on.doc")
                            }
                        }
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
        .background(.bar)
    }
}

private struct InfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .multilineTextAlignment(.trailing)
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
        .frame(maxWidth: 520)
    }
}
