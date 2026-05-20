import SwiftUI

struct SelectionDetailPanel: View {
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

struct OtherSmallFilesDetailPanel: View {
    var detail: OtherSmallFilesDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Other small files")
                        .font(.headline)
                        .lineLimit(1)

                    Text(detail.displayRootName.map { "Grouped inside \($0)" } ?? "Grouped small visible items")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                InfoPair(label: "Disk", value: detail.diskUsage)
                    .frame(width: 120, alignment: .leading)
            }

            Label(
                "These items are grouped because they are too small to draw as useful individual tiles.",
                systemImage: "square.stack.3d.up"
            )
            .font(.caption)
            .foregroundStyle(.secondary)
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
        ControlGroup {
            Button {
                model.quickLookSelected()
            } label: {
                Label("Quick Look", systemImage: "eye")
                    .labelStyle(.iconOnly)
            }
            .disabled(!detail.canQuickLook)
            .help("Quick Look")

            if detail.url != nil {
                if detail.canExpandPackage {
                    Button {
                        Task {
                            await model.expandSelectedPackage()
                        }
                    } label: {
                        Label("Expand Package", systemImage: "square.stack.3d.down.right")
                            .labelStyle(.iconOnly)
                    }
                    .help("Expand Package")
                }

                Button {
                    model.revealSelectedInFinder()
                } label: {
                    Label("Reveal in Finder", systemImage: "arrow.up.forward.app")
                        .labelStyle(.iconOnly)
                }
                .help("Reveal in Finder")

                Button {
                    model.copySelectedPath()
                } label: {
                    Label("Copy Path", systemImage: "doc.on.doc")
                        .labelStyle(.iconOnly)
                }
                .help("Copy Path")
            }

            Button {
                Task {
                    await model.moveSelectedItemToTrash()
                }
            } label: {
                Label("Move to Trash", systemImage: "trash")
                    .labelStyle(.iconOnly)
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
                InfoPair(label: "Current View", value: detail.shareOfCurrentView)
                InfoPair(label: "Scan", value: detail.shareOfScan)
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
                    InfoPair(label: "Current View", value: detail.shareOfCurrentView)
                    InfoPair(label: "Scan", value: detail.shareOfScan)
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
