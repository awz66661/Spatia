import SpatiaCore
import SwiftUI

struct CanvasNavigationBar: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        HStack(spacing: 10) {
            Button {
                model.goUp()
            } label: {
                Label("Up", systemImage: "chevron.up")
                    .labelStyle(.iconOnly)
            }
            .disabled(model.displayRoot?.parentID == nil)
            .help("Up")

            BreadcrumbPathBar(nodes: model.breadcrumb) { nodeID in
                model.navigateToBreadcrumb(nodeID)
            }
            .frame(maxWidth: 560, alignment: .leading)

            Spacer(minLength: 12)

            if let summary = model.currentViewSummary {
                CanvasSummaryMetrics(summary: summary)
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
}

private struct CanvasSummaryMetrics: View {
    var summary: CanvasViewSummary

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                CanvasMetric(label: "Disk", value: summary.diskUsage)
                CanvasMetric(label: "Files", value: summary.fileCount)
                CanvasMetric(label: "Folders", value: summary.folderCount)
            }

            CanvasMetric(label: "Disk", value: summary.diskUsage)
        }
        .help(summary.path ?? summary.name)
    }
}

private struct CanvasMetric: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .trailing, spacing: 1) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .monospacedDigit()
                .lineLimit(1)
        }
    }
}

struct CurrentViewStrip: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if model.isCanvasScopeLoading(.currentView) {
                HStack(spacing: 8) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Loading current view...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 18)
            } else if model.currentViewItems.isEmpty {
                Text("No sizeable children in this view.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 18)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(model.currentViewItems) { item in
                            CurrentViewItemButton(
                                item: item,
                                isSelected: model.selectedID == item.id
                            ) {
                                model.openCurrentViewItem(item.id)
                            }
                        }
                    }
                    .padding(.horizontal, 18)
                }
            }
        }
        .frame(height: DesignTokens.currentViewStripHeight)
        .padding(.bottom, 6)
    }
}

private struct CurrentViewItemButton: View {
    var item: CurrentViewItemSummary
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: item.isContainer ? "folder" : "doc")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: DesignTokens.rowIconColumnWidth, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.callout)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("\(item.kind) - \(item.sizeText)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 10)
            .frame(width: 190, height: 46, alignment: .leading)
            .contentShape(Rectangle())
            .background {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? DesignTokens.selectedRowBackground : Color.primary.opacity(0.045))
            }
        }
        .buttonStyle(.plain)
        .help(item.path ?? item.name)
    }
}
