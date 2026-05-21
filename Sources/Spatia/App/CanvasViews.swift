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
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(2)

            if let summary = model.currentViewSummary {
                Spacer(minLength: 8)
                CanvasSummaryMetrics(summary: summary)
                    .layoutPriority(0)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
        .padding(.bottom, 4)
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

    @ViewBuilder
    var body: some View {
        if model.isCanvasScopeLoading(.currentView) {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.mini)
                Text("Loading current view...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 36)
            .padding(.horizontal, 14)
            .padding(.bottom, 4)
        } else if !model.currentViewItems.isEmpty {
            GeometryReader { proxy in
                let itemWidth = CurrentViewStripLayout.itemWidth(for: proxy.size.width)

                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 8) {
                        ForEach(model.currentViewItems) { item in
                            CurrentViewItemButton(
                                item: item,
                                isSelected: model.selectedID == item.id,
                                width: itemWidth
                            ) {
                                model.openCurrentViewItem(item.id)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                }
            }
            .frame(height: DesignTokens.currentViewStripHeight)
            .padding(.bottom, 4)
        }
    }
}

private enum CurrentViewStripLayout {
    static let targetVisibleItemCount: CGFloat = 4

    static func itemWidth(for availableWidth: CGFloat) -> CGFloat {
        max(1, availableWidth / targetVisibleItemCount)
    }
}

private struct CurrentViewItemButton: View {
    var item: CurrentViewItemSummary
    var isSelected: Bool
    var width: CGFloat
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
            .frame(width: width, alignment: .leading)
            .frame(minHeight: 46, alignment: .leading)
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
