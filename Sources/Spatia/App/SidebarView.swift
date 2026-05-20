import SpatiaCore
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.thinMaterial)
                .ignoresSafeArea(.container, edges: [.top, .bottom, .leading])

            List {
                Section("Current Scan") {
                    SidebarSourceSummaryView(
                        overview: model.scanOverview,
                        currentScanURL: model.currentScanURL,
                        isScanning: model.isScanning,
                        statusText: model.statusText
                    )
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 10, trailing: 14))
                }

                SidebarPanelView()

                if !model.permissionIssues.isEmpty {
                    PermissionSummaryView(
                        issues: model.permissionIssues,
                        isExpanded: sectionBinding(.access)
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: DesignTokens.sidebarTitlebarInset)
            }
            .searchable(
                text: Binding(
                    get: { model.searchQuery },
                    set: { model.searchQuery = $0 }
                ),
                placement: .sidebar,
                prompt: "Name, path, kind, or category"
            )
        }
    }

    private func sectionBinding(_ section: SidebarSection) -> Binding<Bool> {
        Binding(
            get: { model.expandedSidebarSections.contains(section) },
            set: { model.setSidebarSection(section, isExpanded: $0) }
        )
    }
}

private struct SidebarSourceSummaryView: View {
    var overview: ScanOverview?
    var currentScanURL: URL?
    var isScanning: Bool
    var statusText: String

    var body: some View {
        if let overview {
            VStack(alignment: .leading, spacing: 10) {
                Label(overview.sourceName, systemImage: "folder")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                VStack(spacing: 6) {
                    SidebarMetricRow(label: "Disk", value: overview.diskUsage)
                    SidebarMetricRow(label: "Files", value: overview.fileCount)
                    SidebarMetricRow(label: "Folders", value: overview.folderCount)
                    SidebarMetricRow(label: "Scan", value: overview.duration)
                }

                Text(overview.sourcePath)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                if let currentPath = overview.currentPath {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Scanning")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(currentPath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
            }
        } else if let currentScanURL {
            VStack(alignment: .leading, spacing: 8) {
                Label(sourceName(for: currentScanURL), systemImage: isScanning ? "arrow.triangle.2.circlepath" : "folder")
                    .font(.headline)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Text(currentScanURL.path)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
                    .textSelection(.enabled)

                Text(statusText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Label("No Scan", systemImage: "square.grid.3x3")
                    .font(.headline)

                Text("Choose a folder from the toolbar scan menu to build a space map.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sourceName(for url: URL) -> String {
        url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
    }
}

private struct SidebarMetricRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer(minLength: 0)
            Text(value)
                .fontWeight(.medium)
                .frame(width: 92, alignment: .trailing)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}

private struct SidebarPanelView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        if !trimmedSearchQuery.isEmpty {
            Section("Search Results") {
                searchContent
            }
        }

        Section {
            DisclosureGroup(isExpanded: sectionBinding(.browse)) {
                browseContent
            } label: {
                SidebarSectionLabel(title: "Browse", systemImage: "folder")
            }
        }

        Section {
            DisclosureGroup(isExpanded: sectionBinding(.largestFiles)) {
                largestFilesContent
            } label: {
                SidebarSectionLabel(title: "Largest Files", systemImage: "doc.text.magnifyingglass")
            }
        }

        Section {
            DisclosureGroup(isExpanded: sectionBinding(.typeUsage)) {
                typeUsageContent
            } label: {
                SidebarSectionLabel(title: "Type Usage", systemImage: "chart.pie")
            }
        }
    }

    private var trimmedSearchQuery: String {
        model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @ViewBuilder
    private var searchContent: some View {
        if model.isSearchLoading {
            SidebarLoadingInsightView(text: "Searching...")
        } else if model.searchResultSummaries.isEmpty {
            SidebarEmptyInsightView(text: "No matches in the current view.")
        } else {
            ForEach(model.searchResultSummaries) { item in
                SidebarSearchRow(
                    item: item,
                    isSelected: model.selectedID == item.id
                ) {
                    model.openInsightItem(item.id)
                }
                .listRowBackground(model.selectedID == item.id ? DesignTokens.selectedRowBackground : Color.clear)
            }
        }
    }

    @ViewBuilder
    private var browseContent: some View {
        if model.isSidebarSectionLoading(.browse) {
            SidebarLoadingInsightView(text: "Loading current view...")
        } else if model.sidebarBrowseItems.isEmpty {
            SidebarEmptyInsightView(
                text: model.snapshot == nil
                    ? "No scan yet."
                    : "This location has no sizeable children."
            )
        } else {
            ForEach(model.sidebarBrowseItems) { item in
                SidebarBrowseRow(
                    item: item,
                    isSelected: model.selectedID == item.id
                ) {
                    model.openSidebarItem(item.id)
                }
                .listRowBackground(model.selectedID == item.id ? DesignTokens.selectedRowBackground : Color.clear)
            }
        }
    }

    @ViewBuilder
    private var largestFilesContent: some View {
        if model.isSidebarSectionLoading(.largestFiles) {
            SidebarLoadingInsightView(text: "Loading large files...")
        } else if model.sidebarLargestFileItems.isEmpty {
            SidebarEmptyInsightView(
                text: model.snapshot == nil
                    ? "No scan yet."
                    : "This location has no sizeable files."
            )
        } else {
            ForEach(model.sidebarLargestFileItems) { item in
                SidebarInsightFileRow(
                    item: item,
                    isSelected: model.selectedID == item.id
                ) {
                    model.openInsightItem(item.id)
                }
                .listRowBackground(model.selectedID == item.id ? DesignTokens.selectedRowBackground : Color.clear)
            }
        }
    }

    @ViewBuilder
    private var typeUsageContent: some View {
        if model.isSidebarSectionLoading(.typeUsage) {
            SidebarLoadingInsightView(text: "Loading type usage...")
        } else if model.sidebarCategoryUsageItems.isEmpty {
            SidebarEmptyInsightView(
                text: model.snapshot == nil
                    ? "No scan yet."
                    : "This location has no sizeable type groups."
            )
        } else {
            ForEach(model.sidebarCategoryUsageItems) { item in
                SidebarCategoryRow(item: item)
            }
        }
    }

    private func sectionBinding(_ section: SidebarSection) -> Binding<Bool> {
        Binding(
            get: { model.expandedSidebarSections.contains(section) },
            set: { model.setSidebarSection(section, isExpanded: $0) }
        )
    }
}

private struct SidebarSectionLabel: View {
    var title: String
    var systemImage: String

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.callout)
    }
}

private struct SidebarEmptyInsightView: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct SidebarLoadingInsightView: View {
    var text: String

    var body: some View {
        HStack(spacing: 8) {
            ProgressView()
                .controlSize(.mini)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

private struct SidebarBrowseRow: View {
    var item: SidebarItemSummary
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: item.isContainer ? "folder" : "doc")
                    .font(.system(size: 15, weight: .regular))
                    .foregroundStyle(.secondary)
                    .frame(width: DesignTokens.sidebarIconColumnWidth, alignment: .center)

                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.callout)
                        .fontWeight(isSelected ? .semibold : .regular)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text(item.kind)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
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
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.path ?? item.name)
    }
}

private struct SidebarInsightFileRow: View {
    var item: DescendantFileSummary
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                CategorySwatch(category: item.category)
                    .frame(width: DesignTokens.sidebarIconColumnWidth, alignment: .center)

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
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.path ?? item.relativePath)
    }
}

private struct SidebarCategoryRow: View {
    var item: CategoryUsageSummary

    var body: some View {
        HStack(spacing: 8) {
            CategorySwatch(category: item.category)
                .frame(width: DesignTokens.sidebarIconColumnWidth, alignment: .center)

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
        .padding(.vertical, 3)
        .help("\(item.name): \(item.sizeText), \(item.shareText)")
    }
}

private struct SidebarSearchRow: View {
    var item: SearchResultSummary
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                CategorySwatch(category: item.category)
                    .frame(width: DesignTokens.sidebarIconColumnWidth, alignment: .center)

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
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(item.relativePath)
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

private struct PermissionSummaryView: View {
    var issues: [ScanIssue]
    @Binding var isExpanded: Bool

    var body: some View {
        Section {
            DisclosureGroup(isExpanded: $isExpanded) {
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

                    Text("Some locations were skipped.")
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
