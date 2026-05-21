import SpatiaCore
import SwiftUI

enum DesignTokens {
    static let rowIconColumnWidth: CGFloat = 24
    static let treemapInset: CGFloat = 10
    static let currentViewStripHeight: CGFloat = 52
    static let minimumWindowHeight: CGFloat = 700

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
        } detail: {
            DetailWorkspaceView()
                .toolbar {
                    ToolbarItemGroup(placement: .primaryAction) {
                        ControlGroup {
                            ScanFolderButton()

                            Button {
                                model.rescanCurrentSource()
                            } label: {
                                Label("Rescan", systemImage: "arrow.clockwise")
                            }
                            .labelStyle(.iconOnly)
                            .disabled(model.currentScanURL == nil || model.isScanning)
                            .help("Rescan Current")
                        }
                    }

                    if model.isScanning {
                        ToolbarItem(placement: .cancellationAction) {
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
                            model.isRightInspectorVisible.toggle()
                        } label: {
                            Label(
                                model.isRightInspectorVisible ? "Hide Inspector" : "Show Inspector",
                                systemImage: "sidebar.trailing"
                            )
                        }
                        .labelStyle(.iconOnly)
                        .help(model.isRightInspectorVisible ? "Hide Inspector" : "Show Inspector")
                    }
                }
        }
        .navigationSplitViewStyle(.prominentDetail)
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

private struct DetailWorkspaceView: View {
    @EnvironmentObject private var model: AppModel

    var body: some View {
        GeometryReader { proxy in
            let layout = WorkspaceColumnLayout(
                availableWidth: proxy.size.width,
                showsInspector: model.isRightInspectorVisible
            )

            HStack(spacing: 0) {
                TreemapDetailView()
                    .frame(width: layout.canvasWidth, height: proxy.size.height)

                if layout.showsInspector {
                    Divider()

                    RightInspectorView()
                        .frame(width: layout.inspectorWidth, height: proxy.size.height)
                        .background(Color(nsColor: .controlBackgroundColor))
                }
            }
        }
    }
}

private struct WorkspaceColumnLayout {
    private static let inspectorTargetShare: CGFloat = 0.30
    private static let inspectorMaximumShare: CGFloat = 0.42
    private static let inspectorMaximumWidth: CGFloat = 360
    private static let dividerWidth: CGFloat = 1

    let availableWidth: CGFloat
    let showsInspector: Bool

    var inspectorWidth: CGFloat {
        guard showsInspector else { return 0 }
        let targetWidth = availableWidth * Self.inspectorTargetShare
        let maximumWidth = min(Self.inspectorMaximumWidth, availableWidth * Self.inspectorMaximumShare)
        return min(targetWidth, maximumWidth)
    }

    var canvasWidth: CGFloat {
        guard showsInspector else { return availableWidth }
        return max(0, availableWidth - inspectorWidth - Self.dividerWidth)
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
    }
}
