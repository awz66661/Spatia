import SpatiaCore
import SwiftUI

struct SidebarView: View {
    @EnvironmentObject private var model: AppModel
    @State private var isAccessExpanded = false

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

                Section("Quick Scan") {
                    SourceActionRow(title: "Downloads", systemImage: "arrow.down.circle") {
                        model.scanDownloads()
                    }
                    SourceActionRow(title: "Desktop", systemImage: "desktopcomputer") {
                        model.scanDesktop()
                    }
                    SourceActionRow(title: "Documents", systemImage: "doc.text") {
                        model.scanDocuments()
                    }
                    SourceActionRow(title: "Applications", systemImage: "app.dashed") {
                        model.scanApplications()
                    }
                    SourceActionRow(title: "Home", systemImage: "house") {
                        model.scanHome()
                    }
                    SourceActionRow(title: "Choose Folder...", systemImage: "folder.badge.plus") {
                        model.chooseFolder()
                    }
                }

                Section("Scan Options") {
                    Toggle(isOn: Binding(
                        get: { model.scanPreferences.includeHiddenFiles },
                        set: { model.setIncludeHiddenFiles($0) }
                    )) {
                        Label("Hidden Files", systemImage: "eye")
                    }

                    Toggle(isOn: Binding(
                        get: { model.scanPreferences.expandPackages },
                        set: { model.setExpandPackages($0) }
                    )) {
                        Label("Expand Packages", systemImage: "shippingbox")
                    }

                    Picker("Depth Limit", selection: Binding(
                        get: { model.scanPreferences.maxDepth },
                        set: { model.setMaxDepth($0) }
                    )) {
                        Text("No Limit").tag(Optional<Int>.none)
                        Text("1 Level").tag(Optional(1))
                        Text("2 Levels").tag(Optional(2))
                        Text("3 Levels").tag(Optional(3))
                        Text("5 Levels").tag(Optional(5))
                    }
                    .pickerStyle(.menu)

                    Text("Options apply to the next scan.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                PermissionSummaryView(
                    issues: model.permissionIssues,
                    isExpanded: $isAccessExpanded
                )
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

                Text("Choose a folder from Quick Scan or the toolbar to build a space map.")
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

private struct SourceActionRow: View {
    var title: String
    var systemImage: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .buttonStyle(.plain)
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
                .frame(width: 88, alignment: .trailing)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .font(.caption)
    }
}

private struct PermissionSummaryView: View {
    var issues: [ScanIssue]
    @Binding var isExpanded: Bool

    var body: some View {
        Section("Access") {
            if issues.isEmpty {
                Label("No skipped locations", systemImage: "checkmark.circle")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
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
}
