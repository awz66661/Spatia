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

struct SearchResultsOverlay: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Label("Search", systemImage: "magnifyingglass")
                    .font(.callout)
                    .fontWeight(.medium)

                Spacer(minLength: 8)

                if model.isSearchLoading {
                    ProgressView()
                        .controlSize(.mini)
                }

                Button {
                    model.clearSearch()
                } label: {
                    Label("Clear Search", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Clear Search")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)

            Divider()

            if model.isSearchLoading {
                CanvasLoadingRow(text: "Searching...")
                    .padding(12)
            } else if model.searchResultSummaries.isEmpty {
                CanvasEmptyRow(text: "No matches in the current view.")
                    .padding(12)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(model.searchResultSummaries) { item in
                            SearchResultRow(
                                item: item,
                                isSelected: model.selectedID == item.id
                            ) {
                                model.openInsightItem(item.id)
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
                .frame(maxHeight: 320)
            }
        }
        .frame(width: DesignTokens.searchOverlayWidth)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
    }
}

struct InsightsDrawerView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Label("Insights", systemImage: "chart.pie")
                    .font(.headline)

                Spacer(minLength: 8)

                Button {
                    model.isInsightsPanelVisible = false
                } label: {
                    Label("Hide Insights", systemImage: "xmark.circle.fill")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .help("Hide Insights")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    InsightSectionHeader(title: "Largest Files")
                    largestFilesContent

                    Divider()

                    InsightSectionHeader(title: "Type Usage")
                    typeUsageContent
                }
                .padding(14)
            }
        }
        .frame(width: DesignTokens.insightsDrawerWidth)
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(0.12), radius: 18, x: 0, y: 10)
    }

    @ViewBuilder
    private var largestFilesContent: some View {
        if model.isCanvasScopeLoading(.largestFiles) {
            CanvasLoadingRow(text: "Loading large files...")
        } else if model.insightLargestFileItems.isEmpty {
            CanvasEmptyRow(text: "No sizeable files in this view.")
        } else {
            VStack(spacing: 4) {
                ForEach(model.insightLargestFileItems) { item in
                    InsightFileRow(
                        item: item,
                        isSelected: model.selectedID == item.id
                    ) {
                        model.openInsightItem(item.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var typeUsageContent: some View {
        if model.isCanvasScopeLoading(.typeUsage) {
            CanvasLoadingRow(text: "Loading type usage...")
        } else if model.insightCategoryUsageItems.isEmpty {
            CanvasEmptyRow(text: "No type usage in this view.")
        } else {
            VStack(spacing: 4) {
                ForEach(model.insightCategoryUsageItems) { item in
                    CategoryUsageRow(item: item)
                }
            }
        }
    }
}

private struct InsightSectionHeader: View {
    var title: String

    var body: some View {
        Text(title)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }
}

private struct SearchResultRow: View {
    var item: SearchResultSummary
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                CategorySwatch(category: item.category)
                    .frame(width: DesignTokens.rowIconColumnWidth, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.callout)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("\(item.relativePath) - \(item.kind) - \(item.categoryName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
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
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(isSelected ? DesignTokens.selectedRowBackground : Color.clear)
        }
        .buttonStyle(.plain)
        .help(item.relativePath)
    }
}

private struct InsightFileRow: View {
    var item: DescendantFileSummary
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                CategorySwatch(category: item.category)
                    .frame(width: DesignTokens.rowIconColumnWidth, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.callout)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("\(item.relativePath) - \(item.categoryName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .trailing, spacing: 1) {
                    Text(item.sizeText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)

                    Text(item.shareText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
                .frame(width: 66, alignment: .trailing)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(isSelected ? DesignTokens.selectedRowBackground : Color.clear)
        }
        .buttonStyle(.plain)
        .help(item.path ?? item.relativePath)
    }
}

private struct CategoryUsageRow: View {
    var item: CategoryUsageSummary

    var body: some View {
        HStack(spacing: 8) {
            CategorySwatch(category: item.category)
                .frame(width: DesignTokens.rowIconColumnWidth, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.name)
                    .font(.callout)
                    .lineLimit(1)

                Text("\(item.itemCountText) item\(item.itemCount == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                Text(item.sizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                Text(item.shareText)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(width: 66, alignment: .trailing)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .help("\(item.name): \(item.sizeText), \(item.shareText)")
    }
}

private struct CanvasLoadingRow: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct CanvasEmptyRow: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct CategorySwatch: View {
    var category: FileCategory

    var body: some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(CategoryPalette.color(for: category))
            .overlay {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(Color.primary.opacity(0.18), lineWidth: 0.5)
            }
            .frame(width: 12, height: 12)
    }
}
