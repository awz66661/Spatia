import SpatiaCore
import SwiftUI

struct ScanSourceMenu: View {
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

            Menu("Scan Options", systemImage: "slider.horizontal.3") {
                Toggle(isOn: Binding(
                    get: { model.scanPreferences.includeHiddenFiles },
                    set: { model.setIncludeHiddenFiles($0) }
                )) {
                    Label("Include Hidden Files", systemImage: "eye")
                }

                Toggle(isOn: Binding(
                    get: { model.scanPreferences.expandPackages },
                    set: { model.setExpandPackages($0) }
                )) {
                    Label("Expand Packages", systemImage: "shippingbox")
                }

                Divider()

                Menu("Depth Limit", systemImage: "square.stack.3d.down.right") {
                    DepthLimitButton(title: "No Limit", depth: nil)
                    DepthLimitButton(title: "1 Level", depth: 1)
                    DepthLimitButton(title: "2 Levels", depth: 2)
                    DepthLimitButton(title: "3 Levels", depth: 3)
                    DepthLimitButton(title: "5 Levels", depth: 5)
                }
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

private struct DepthLimitButton: View {
    @EnvironmentObject private var model: AppModel
    var title: String
    var depth: Int?

    var body: some View {
        Button {
            model.setMaxDepth(depth)
        } label: {
            if model.scanPreferences.maxDepth == depth {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}

struct StatusPill: View {
    var text: String
    var isScanning: Bool

    var body: some View {
        HStack(spacing: 6) {
            if isScanning {
                ProgressView()
                    .controlSize(.mini)
            }

            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(maxWidth: 260, alignment: .trailing)
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
