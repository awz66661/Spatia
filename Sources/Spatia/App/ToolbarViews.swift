import SpatiaCore
import SwiftUI

struct ScanFolderButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.chooseFolder()
        } label: {
            Label("Scan Folder", systemImage: "folder.badge.plus")
        }
        .labelStyle(.iconOnly)
        .help("Scan Folder")
    }
}

struct BreadcrumbPathBar: View {
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
