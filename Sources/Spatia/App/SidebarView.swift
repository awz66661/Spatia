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

                Section("Insights") {
                    SidebarInsightsView()
                }

                if !model.permissionIssues.isEmpty {
                    Section("Access") {
                        PermissionSummaryView(issues: model.permissionIssues)
                    }
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)
            .background(Color.clear)
            .safeAreaInset(edge: .top, spacing: 0) {
                Color.clear
                    .frame(height: DesignTokens.sidebarTitlebarInset)
            }
        }
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

private struct SidebarInsightsView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        InsightModePicker(
            selection: Binding(
                get: { model.sidebarInsightMode },
                set: { model.sidebarInsightMode = $0 }
            )
        )
        .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 7, trailing: 14))

        switch model.sidebarInsightMode {
        case .here:
            if model.largestDisplayRootChildren.isEmpty {
                SidebarEmptyInsightView(
                    text: model.snapshot == nil
                        ? "Scan a folder to browse its largest items."
                        : "This location has no sizeable children."
                )
            } else {
                ForEach(model.largestDisplayRootChildren) { item in
                    SidebarLargestRow(
                        item: item,
                        isSelected: model.selectedID == item.id
                    ) {
                        model.openSidebarItem(item.id)
                    }
                    .listRowBackground(model.selectedID == item.id ? DesignTokens.selectedRowBackground : Color.clear)
                }
            }
        case .files:
            if model.largestDescendantFileSummaries.isEmpty {
                SidebarEmptyInsightView(
                    text: model.snapshot == nil
                        ? "Scan a folder to find large files."
                        : "This location has no sizeable files."
                )
            } else {
                ForEach(model.largestDescendantFileSummaries) { item in
                    SidebarDescendantFileRow(
                        item: item,
                        isSelected: model.selectedID == item.id
                    ) {
                        model.openInsightItem(item.id)
                    }
                    .listRowBackground(model.selectedID == item.id ? DesignTokens.selectedRowBackground : Color.clear)
                }
            }
        case .types:
            if model.categoryUsageSummaries.isEmpty {
                SidebarEmptyInsightView(
                    text: model.snapshot == nil
                        ? "Scan a folder to summarize types."
                        : "This location has no sizeable type groups."
                )
            } else {
                ForEach(model.categoryUsageSummaries) { item in
                    SidebarCategoryUsageRow(item: item)
                }
            }
        case .search:
            SearchField(
                text: Binding(
                    get: { model.searchQuery },
                    set: { model.searchQuery = $0 }
                )
            )
            .listRowInsets(EdgeInsets(top: 6, leading: 14, bottom: 7, trailing: 14))

            if model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                SidebarEmptyInsightView(text: "Search names, paths, kinds, or categories in the current view.")
            } else if model.searchResultSummaries.isEmpty {
                SidebarEmptyInsightView(text: "No matches in the current view.")
            } else {
                ForEach(model.searchResultSummaries) { item in
                    SidebarSearchResultRow(
                        item: item,
                        isSelected: model.selectedID == item.id
                    ) {
                        model.openInsightItem(item.id)
                    }
                    .listRowBackground(model.selectedID == item.id ? DesignTokens.selectedRowBackground : Color.clear)
                }
            }
        }
    }
}

private struct SearchField: View {
    @Binding var text: String

    var body: some View {
        TextField("Search", text: $text)
            .textFieldStyle(.roundedBorder)
            .controlSize(.small)
    }
}

private struct InsightModePicker: View {
    @Binding var selection: SidebarInsightMode

    var body: some View {
        Picker("Insight", selection: $selection) {
            ForEach(SidebarInsightMode.allCases) { mode in
                Text(mode.title)
                    .tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .controlSize(.small)
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

private struct SidebarLargestRow: View {
    var item: DisplayRootChildSummary
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

private struct SidebarDescendantFileRow: View {
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

private struct SidebarCategoryUsageRow: View {
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

private struct SidebarSearchResultRow: View {
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

    var body: some View {
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
    }
}
