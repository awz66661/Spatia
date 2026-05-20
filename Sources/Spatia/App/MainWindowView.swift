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
    static let rightInspectorMinWidth: CGFloat = 300
    static let rightInspectorIdealWidth: CGFloat = 340
    static let rightInspectorMaxWidth: CGFloat = 430

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
                ScanFolderButton()
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
        }
        .inspector(
            isPresented: Binding(
                get: { model.isRightInspectorVisible && model.snapshot != nil },
                set: { model.isRightInspectorVisible = $0 }
            )
        ) {
            RightInspectorView()
                .inspectorColumnWidth(
                    min: DesignTokens.rightInspectorMinWidth,
                    ideal: DesignTokens.rightInspectorIdealWidth,
                    max: DesignTokens.rightInspectorMaxWidth
                )
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

                        if !model.isRightInspectorVisible {
                            HStack {
                                Spacer(minLength: 0)
                                InspectorRevealButton()
                                    .padding(.trailing, 18)
                                    .padding(.top, 12)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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

private struct InspectorRevealButton: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Button {
            model.isRightInspectorVisible = true
        } label: {
            Label("Show Inspector", systemImage: "sidebar.trailing")
                .labelStyle(.iconOnly)
                .frame(width: 34, height: 34)
        }
        .buttonStyle(.plain)
        .glassEffect(.regular, in: Circle())
        .help("Show Inspector")
    }
}
