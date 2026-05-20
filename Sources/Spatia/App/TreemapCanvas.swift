import AppKit
import SpatiaCore
import SwiftUI

struct TreemapCanvas: NSViewRepresentable {
    var snapshot: FileTreeSnapshot
    var rootID: NodeID
    var expandedNodeIDs: Set<NodeID>
    var highlightedNodeIDs: Set<NodeID>
    @Binding var selectedID: NodeID?
    var onActivate: (NodeID) -> Void
    var onPreview: (NodeID) -> Void
    var onExpandPackage: (NodeID) -> Void
    var onReveal: (NodeID) -> Void
    var onCopyPath: (NodeID) -> Void
    var onMoveToTrash: (NodeID) -> Void
    var onHover: (NodeID?) -> Void
    var onSyntheticOtherSelect: (Int64) -> Void

    func makeNSView(context: Context) -> TreemapNSView {
        let view = TreemapNSView()
        view.onSelect = { selectedID = $0 }
        view.onActivate = onActivate
        view.onPreview = onPreview
        view.onExpandPackage = onExpandPackage
        view.onReveal = onReveal
        view.onCopyPath = onCopyPath
        view.onMoveToTrash = onMoveToTrash
        view.onHover = onHover
        view.onSyntheticOtherSelect = onSyntheticOtherSelect
        return view
    }

    func updateNSView(_ nsView: TreemapNSView, context: Context) {
        nsView.snapshot = snapshot
        nsView.rootID = rootID
        nsView.expandedNodeIDs = expandedNodeIDs
        nsView.highlightedNodeIDs = highlightedNodeIDs
        nsView.selectedID = selectedID
        nsView.onSelect = { selectedID = $0 }
        nsView.onActivate = onActivate
        nsView.onPreview = onPreview
        nsView.onExpandPackage = onExpandPackage
        nsView.onReveal = onReveal
        nsView.onCopyPath = onCopyPath
        nsView.onMoveToTrash = onMoveToTrash
        nsView.onHover = onHover
        nsView.onSyntheticOtherSelect = onSyntheticOtherSelect
    }
}

final class TreemapNSView: NSView {
    var snapshot: FileTreeSnapshot? {
        didSet { needsDisplay = true }
    }

    var rootID: NodeID? {
        didSet {
            if rootID != oldValue {
                pendingDoubleClickTarget = nil
            }
            needsDisplay = true
        }
    }

    var expandedNodeIDs: Set<NodeID> = [] {
        didSet { needsDisplay = true }
    }

    var highlightedNodeIDs: Set<NodeID> = [] {
        didSet { needsDisplay = true }
    }

    var selectedID: NodeID? {
        didSet { needsDisplay = true }
    }

    var onSelect: ((NodeID?) -> Void)?
    var onActivate: ((NodeID) -> Void)?
    var onPreview: ((NodeID) -> Void)?
    var onExpandPackage: ((NodeID) -> Void)?
    var onReveal: ((NodeID) -> Void)?
    var onCopyPath: ((NodeID) -> Void)?
    var onMoveToTrash: ((NodeID) -> Void)?
    var onHover: ((NodeID?) -> Void)?
    var onSyntheticOtherSelect: ((Int64) -> Void)?

    var renderedTiles: [Tile] = []
    var layoutCache: TreemapLayoutCache?
    private var trackingArea: NSTrackingArea?
    var hoveredTile: Tile? {
        didSet {
            if hoveredTile != oldValue {
                needsDisplay = true
            }
        }
    }

    let builder = RecursiveTreemapBuilder(
        layout: SquarifiedTreemapLayout(
            minTileArea: 80,
            maxItems: 520,
            contentPadding: 1,
            readableWeightExponent: 0.58,
            orientationPolicy: .spaceSniffer
        ),
        options: RecursiveTreemapBuildOptions(
            maximumTraversalDepth: 12,
            childInset: 6,
            minimumExpandableTileArea: 10_000,
            minimumChildContentArea: 7_500,
            minimumUsefulChildSide: 28,
            minimumUsefulChildArea: 900,
            reservedHeaderHeight: 20,
            maximumTileCount: 1_100
        )
    )
    let hitTester = TreemapHitTester(gapTolerance: 1)
    let labelPolicy = TreemapLabelPolicy()
    let doubleClickTargetTolerance: CGFloat = 6
    var pendingDoubleClickTarget: MouseDownTarget?
    var contextMenuTile: Tile?

    override var isFlipped: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let trackingArea {
            removeTrackingArea(trackingArea)
        }

        let newArea = NSTrackingArea(
            rect: .zero,
            options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
            owner: self
        )
        addTrackingArea(newArea)
        trackingArea = newArea
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.windowBackgroundColor.setFill()
        dirtyRect.fill()

        guard let snapshot, let rootID else {
            renderedTiles = []
            layoutCache = nil
            return
        }

        let layoutBounds = bounds.insetBy(dx: 3, dy: 3)
        renderedTiles = cachedTiles(
            snapshot: snapshot,
            rootID: rootID,
            in: layoutBounds,
            expandedNodeIDs: expandedNodeIDs
        )

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setAllowsAntialiasing(true)

        for tile in renderedTiles {
            draw(tile, in: context)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        let point = convert(event.locationInWindow, from: nil)
        let hit = hitTester.hitTest(point: point, tiles: renderedTiles)

        if event.clickCount == 2 {
            let targetTile = doubleClickTarget(at: point, fallback: hit)
            select(targetTile)
            if let targetID = targetTile?.nodeID, targetID != syntheticOtherNodeID {
                onActivate?(targetID)
            }
            pendingDoubleClickTarget = nil
            return
        }

        select(hit)
        pendingDoubleClickTarget = hit.map { MouseDownTarget(nodeID: $0.nodeID, rootID: rootID, point: point) }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        updateHover(hitTester.hitTest(point: point, tiles: renderedTiles))
    }

    override func mouseExited(with event: NSEvent) {
        updateHover(nil)
    }

    override func keyDown(with event: NSEvent) {
        if event.charactersIgnoringModifiers == " ", let selectedID, selectedID != syntheticOtherNodeID {
            onPreview?(selectedID)
            return
        }

        switch event.specialKey {
        case .leftArrow:
            moveSelection(.left)
            return
        case .rightArrow:
            moveSelection(.right)
            return
        case .upArrow:
            moveSelection(.up)
            return
        case .downArrow:
            moveSelection(.down)
            return
        default:
            break
        }

        switch event.charactersIgnoringModifiers {
        case "\r", "\u{3}":
            if let selectedTile = renderedTiles.first(where: { $0.nodeID == selectedID }),
               canActivate(selectedTile) {
                onActivate?(selectedTile.nodeID)
                return
            }
        case "\u{7F}":
            if let selectedID, selectedID != syntheticOtherNodeID {
                onMoveToTrash?(selectedID)
                return
            }
        case "\u{1B}":
            select(nil)
            return
        default:
            break
        }

        super.keyDown(with: event)
    }

    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        guard let tile = hitTester.hitTest(point: point, tiles: renderedTiles),
              tile.nodeID != syntheticOtherNodeID else {
            contextMenuTile = nil
            return nil
        }

        select(tile)
        contextMenuTile = tile

        let menu = NSMenu()
        addMenuItem("Enter", action: #selector(enterContextMenuTile), to: menu, enabled: canActivate(tile))
        addMenuItem("Quick Look", action: #selector(previewContextMenuTile), to: menu, enabled: tile.kind == .file)
        addMenuItem("Expand Package", action: #selector(expandContextMenuPackage), to: menu, enabled: tile.kind == .package)
        addMenuItem("Reveal in Finder", action: #selector(revealContextMenuTile), to: menu)
        addMenuItem("Copy Path", action: #selector(copyContextMenuTilePath), to: menu)
        menu.addItem(.separator())
        addMenuItem("Move to Trash", action: #selector(moveContextMenuTileToTrash), to: menu)
        return menu
    }

}
