import SpatiaCore
import SwiftUI

enum DesignTokens {
    static let sidebarMinWidth: CGFloat = 260
    static let sidebarIdealWidth: CGFloat = 300
    static let sidebarMaxWidth: CGFloat = 360
    static let sidebarIconColumnWidth: CGFloat = 24
    static let detailMinWidth: CGFloat = 700
    static let treemapInset: CGFloat = 16
    static let inspectorCornerRadius: CGFloat = 18
    static let sidebarTitlebarInset: CGFloat = 58

    static var windowBackground: Color {
        Color(nsColor: .textBackgroundColor)
    }

    static var selectedRowBackground: Color {
        Color(nsColor: .selectedContentBackgroundColor).opacity(0.16)
    }
}

struct MainWindowView: View {
    @EnvironmentObject private var model: AppModel
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            SidebarView()
                .navigationSplitViewColumnWidth(
                    min: DesignTokens.sidebarMinWidth,
                    ideal: DesignTokens.sidebarIdealWidth,
                    max: DesignTokens.sidebarMaxWidth
                )
        } detail: {
            TreemapDetailView()
                .frame(minWidth: DesignTokens.detailMinWidth)
        }
        .navigationSplitViewStyle(.prominentDetail)
        .containerBackground(DesignTokens.windowBackground, for: .window)
        .toolbar {
            ToolbarItem(placement: .navigation) {
                ScanSourceMenu()
            }

            ToolbarItem(placement: .navigation) {
                Button {
                    model.goUp()
                } label: {
                    Label("Up", systemImage: "chevron.up")
                }
                .labelStyle(.iconOnly)
                .disabled(model.displayRoot?.parentID == nil)
                .help("Up")
            }

            ToolbarItem(placement: .principal) {
                BreadcrumbPathBar(nodes: model.breadcrumb) { nodeID in
                    model.navigateToBreadcrumb(nodeID)
                }
                .frame(maxWidth: 560)
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.rescanCurrentSource()
                } label: {
                    Label("Rescan", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .disabled(model.currentScanURL == nil || model.isScanning)
                .help("Rescan Current")
            }

            ToolbarItem(placement: .primaryAction) {
                if model.isScanning {
                    Button {
                        model.cancelScan()
                    } label: {
                        Label("Cancel Scan", systemImage: "xmark.circle")
                    }
                    .labelStyle(.iconOnly)
                    .help("Cancel Scan")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                StatusPill(text: model.statusText, isScanning: model.isScanning)
            }
        }
    }
}

private struct TreemapDetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let snapshot = model.snapshot, let rootID = model.displayRoot?.id {
                TreemapCanvas(
                    snapshot: snapshot,
                    rootID: rootID,
                    expandedNodeIDs: model.expandedTreemapNodeIDs,
                    selectedID: Binding(
                        get: { model.selectedID },
                        set: { model.select($0) }
                    ),
                    onActivate: { nodeID in
                        model.enterDirectory(nodeID)
                    },
                    onPreview: { nodeID in
                        model.quickLook(nodeID)
                    },
                    onSyntheticOtherSelect: { size in
                        model.selectSyntheticOther(size: size)
                    }
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(DesignTokens.treemapInset)
                .safeAreaInset(edge: .bottom, spacing: 0) {
                    if let detail = model.selectedNodeDetail {
                        SelectionDetailPanel(detail: detail)
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                    } else if let detail = model.selectedOtherDetail {
                        OtherSmallFilesDetailPanel(detail: detail)
                            .padding(.horizontal, 18)
                            .padding(.top, 8)
                            .padding(.bottom, 16)
                    }
                }
            } else {
                ContentUnavailableView(
                    model.isScanning ? "Scanning" : "No Scan",
                    systemImage: model.isScanning ? "arrow.triangle.2.circlepath" : "square.grid.3x3",
                    description: Text(model.isScanning ? model.statusText : "Choose a folder to build a space map.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(DesignTokens.windowBackground)
    }
}
