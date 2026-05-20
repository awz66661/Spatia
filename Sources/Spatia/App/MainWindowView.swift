import SpatiaCore
import SwiftUI

enum DesignTokens {
    static let sidebarMinWidth: CGFloat = 210
    static let sidebarIdealWidth: CGFloat = 235
    static let sidebarMaxWidth: CGFloat = 280
    static let rowIconColumnWidth: CGFloat = 24
    static let detailMinWidth: CGFloat = 760
    static let treemapInset: CGFloat = 16
    static let inspectorCornerRadius: CGFloat = 18
    static let sidebarTitlebarInset: CGFloat = 58
    static let currentViewStripHeight: CGFloat = 58
    static let searchOverlayWidth: CGFloat = 430
    static let insightsDrawerWidth: CGFloat = 330

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
                Button {
                    model.isInsightsPanelVisible.toggle()
                } label: {
                    Label("Insights", systemImage: model.isInsightsPanelVisible ? "chart.pie.fill" : "chart.pie")
                }
                .labelStyle(.iconOnly)
                .disabled(model.snapshot == nil)
                .help(model.isInsightsPanelVisible ? "Hide Insights" : "Show Insights")
            }

            ToolbarItem(placement: .primaryAction) {
                StatusPill(text: model.statusText, isScanning: model.isScanning)
            }
        }
        .searchable(
            text: Binding(
                get: { model.searchQuery },
                set: { model.searchQuery = $0 }
            ),
            isPresented: Binding(
                get: { model.isSearchPresented },
                set: { model.isSearchPresented = $0 }
            ),
            placement: .toolbar,
            prompt: "Name, path, kind, or category"
        )
    }
}

private struct TreemapDetailView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            if let snapshot = model.snapshot, let rootID = model.displayRoot?.id {
                VStack(spacing: 0) {
                    CanvasNavigationBar()
                    CurrentViewStrip()

                    ZStack(alignment: .topLeading) {
                        TreemapCanvas(
                            snapshot: snapshot,
                            rootID: rootID,
                            expandedNodeIDs: model.expandedTreemapNodeIDs,
                            highlightedNodeIDs: model.selectedPathNodeIDs,
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
                            onExpandPackage: { nodeID in
                                model.select(nodeID)
                                Task {
                                    await model.expandSelectedPackage()
                                }
                            },
                            onReveal: { nodeID in
                                model.select(nodeID)
                                model.revealSelectedInFinder()
                            },
                            onCopyPath: { nodeID in
                                model.select(nodeID)
                                model.copySelectedPath()
                            },
                            onMoveToTrash: { nodeID in
                                model.select(nodeID)
                                Task {
                                    await model.moveSelectedItemToTrash()
                                }
                            },
                            onHover: { nodeID in
                                model.hoverTreemapNode(nodeID)
                            },
                            onSyntheticOtherSelect: { size in
                                model.selectSyntheticOther(size: size)
                            }
                        )
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(DesignTokens.treemapInset)

                        if !model.searchQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            SearchResultsOverlay()
                                .padding(.leading, 18)
                                .padding(.top, 12)
                        }

                        if model.isInsightsPanelVisible {
                            HStack {
                                Spacer(minLength: 0)
                                InsightsDrawerView()
                                    .padding(.trailing, 18)
                                    .padding(.top, 12)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
