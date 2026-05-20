import SpatiaCore
import SwiftUI

struct RightInspectorView: View {
    @EnvironmentObject private var model: AppModel

    private var hasSearchQuery: Bool {
        !model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        List {
            if hasSearchQuery {
                SearchResultsSection()
            }

            Section("Selected Item") {
                if let detail = model.selectedNodeDetail {
                    SelectedItemInspector(detail: detail)
                } else if let detail = model.selectedOtherDetail {
                    OtherSmallFilesInspector(detail: detail)
                } else {
                    InspectorEmptyRow(text: "Select a tile to inspect it.")
                }
            }

            Section("Largest Files") {
                if model.isCanvasScopeLoading(.largestFiles) {
                    InspectorLoadingRow(text: "Loading large files...")
                } else if model.insightLargestFileItems.isEmpty {
                    InspectorEmptyRow(text: "No sizeable files in this view.")
                } else {
                    ForEach(model.insightLargestFileItems) { item in
                        InspectorInsightFileRow(
                            item: item,
                            isSelected: model.selectedID == item.id
                        ) {
                            model.openInsightItem(item.id)
                        }
                    }
                }
            }

            Section("Type Usage") {
                if model.isCanvasScopeLoading(.typeUsage) {
                    InspectorLoadingRow(text: "Loading type usage...")
                } else if model.insightCategoryUsageItems.isEmpty {
                    InspectorEmptyRow(text: "No type usage in this view.")
                } else {
                    ForEach(model.insightCategoryUsageItems) { item in
                        InspectorCategoryRow(item: item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Inspector")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.isRightInspectorVisible = false
                } label: {
                    Label("Hide Inspector", systemImage: "sidebar.trailing")
                }
                .labelStyle(.iconOnly)
                .help("Hide Inspector")
            }
        }
    }
}

private struct SearchResultsSection: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Section("Search Results") {
            Picker("Scope", selection: Binding(
                get: { model.searchScope },
                set: { model.searchScope = $0 }
            )) {
                ForEach(SearchScope.allCases) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)

            if model.isSearchLoading {
                InspectorLoadingRow(text: "Searching...")
            } else if model.searchResultSummaries.isEmpty {
                InspectorEmptyRow(text: model.searchScope == .scan ? "No matches in this scan." : "No matches in this view.")
            } else {
                ForEach(model.searchResultSummaries) { item in
                    InspectorSearchRow(
                        item: item,
                        isSelected: model.selectedID == item.id
                    ) {
                        model.openSearchResult(item.id)
                    }
                }
            }
        }
    }
}

private struct SelectedItemInspector: View {
    var detail: SelectionDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(detail.name)
                        .font(.headline)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .textSelection(.enabled)

                    if let path = detail.path {
                        Text(path)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                SelectionInspectorActions(detail: detail)
            }

            VStack(spacing: 6) {
                InspectorInfoRow(label: "Kind", value: detail.kind)
                InspectorInfoRow(label: "Disk", value: detail.diskUsage)
                InspectorInfoRow(label: "Size", value: detail.fileSize)
                InspectorInfoRow(label: "Current View", value: detail.shareOfCurrentView)
                InspectorInfoRow(label: "Scan", value: detail.shareOfScan)
                InspectorInfoRow(label: "Category", value: detail.category)
                if let modified = detail.modified {
                    InspectorInfoRow(label: "Modified", value: modified)
                }
            }

            if detail.isProtected {
                Label(detail.riskReason ?? "Protected locations are shown with reduced color intensity.", systemImage: "lock")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !detail.canMoveToTrash, let reason = detail.trashDisabledReason {
                Label(reason, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if !detail.trashWarnings.isEmpty {
                Label(detail.trashWarnings.joined(separator: " "), systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct OtherSmallFilesInspector: View {
    var detail: OtherSmallFilesDetail

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Other small files")
                .font(.headline)

            InspectorInfoRow(label: "Disk", value: detail.diskUsage)

            Text(detail.displayRootName.map { "Grouped inside \($0)." } ?? "Grouped small visible items.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 4)
    }
}

private struct SelectionInspectorActions: View {
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

private struct InspectorSearchRow: View {
    var item: SearchResultSummary
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            InspectorFileRowContent(
                category: item.category,
                name: item.name,
                subtitle: "\(item.relativePath) - \(item.kind) - \(item.categoryName)",
                sizeText: item.sizeText,
                shareText: nil,
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
        .help(item.relativePath)
    }
}

private struct InspectorInsightFileRow: View {
    var item: DescendantFileSummary
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            InspectorFileRowContent(
                category: item.category,
                name: item.name,
                subtitle: "\(item.relativePath) - \(item.categoryName)",
                sizeText: item.sizeText,
                shareText: item.shareText,
                isSelected: isSelected
            )
        }
        .buttonStyle(.plain)
        .help(item.path ?? item.relativePath)
    }
}

private struct InspectorFileRowContent: View {
    var category: FileCategory
    var name: String
    var subtitle: String
    var sizeText: String
    var shareText: String?
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            InspectorCategorySwatch(category: category)
                .frame(width: DesignTokens.rowIconColumnWidth, alignment: .center)

            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 1) {
                Text(sizeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if let shareText {
                    Text(shareText)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .monospacedDigit()
                        .lineLimit(1)
                }
            }
            .frame(width: 66, alignment: .trailing)
        }
        .padding(.vertical, 5)
        .contentShape(Rectangle())
        .background(isSelected ? DesignTokens.selectedRowBackground : Color.clear)
    }
}

private struct InspectorCategoryRow: View {
    var item: CategoryUsageSummary

    var body: some View {
        HStack(spacing: 8) {
            InspectorCategorySwatch(category: item.category)
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
        .padding(.vertical, 5)
        .help("\(item.name): \(item.sizeText), \(item.shareText)")
    }
}

private struct InspectorInfoRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 82, alignment: .leading)

            Text(value)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct InspectorLoadingRow: View {
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

private struct InspectorEmptyRow: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct InspectorCategorySwatch: View {
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
