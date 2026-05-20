import AppKit
import SpatiaCore
import SwiftUI

struct TreemapCanvas: NSViewRepresentable {
    var snapshot: FileTreeSnapshot
    var rootID: NodeID
    var expandedNodeIDs: Set<NodeID>
    @Binding var selectedID: NodeID?
    var onActivate: (NodeID) -> Void
    var onPreview: (NodeID) -> Void
    var onExpandPackage: (NodeID) -> Void
    var onReveal: (NodeID) -> Void
    var onCopyPath: (NodeID) -> Void
    var onMoveToTrash: (NodeID) -> Void
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
        view.onSyntheticOtherSelect = onSyntheticOtherSelect
        return view
    }

    func updateNSView(_ nsView: TreemapNSView, context: Context) {
        nsView.snapshot = snapshot
        nsView.rootID = rootID
        nsView.expandedNodeIDs = expandedNodeIDs
        nsView.selectedID = selectedID
        nsView.onSelect = { selectedID = $0 }
        nsView.onActivate = onActivate
        nsView.onPreview = onPreview
        nsView.onExpandPackage = onExpandPackage
        nsView.onReveal = onReveal
        nsView.onCopyPath = onCopyPath
        nsView.onMoveToTrash = onMoveToTrash
        nsView.onSyntheticOtherSelect = onSyntheticOtherSelect
    }
}

private struct MouseDownTarget {
    var nodeID: NodeID
    var rootID: NodeID?
    var point: CGPoint

    func distance(to other: CGPoint) -> CGFloat {
        let dx = point.x - other.x
        let dy = point.y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

private struct SnapshotLayoutIdentity: Hashable {
    var rootID: NodeID
    var nodeCount: Int
    var storageAddress: UInt
}

private struct TreemapLayoutCacheKey: Hashable {
    var snapshotIdentity: SnapshotLayoutIdentity
    var rootID: NodeID
    var expandedNodeIDs: Set<NodeID>
    var boundsMinX: Double
    var boundsMinY: Double
    var boundsWidth: Double
    var boundsHeight: Double
}

private struct TreemapLayoutCache {
    var key: TreemapLayoutCacheKey
    var tiles: [Tile]
}

private enum KeyboardDirection {
    case left
    case right
    case up
    case down
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
    var onSyntheticOtherSelect: ((Int64) -> Void)?

    private var renderedTiles: [Tile] = []
    private var layoutCache: TreemapLayoutCache?
    private var trackingArea: NSTrackingArea?
    private var hoveredTile: Tile? {
        didSet {
            if hoveredTile != oldValue {
                needsDisplay = true
            }
        }
    }

    private let builder = RecursiveTreemapBuilder(
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
    private let hitTester = TreemapHitTester(gapTolerance: 1)
    private let labelPolicy = TreemapLabelPolicy()
    private let doubleClickTargetTolerance: CGFloat = 6
    private var pendingDoubleClickTarget: MouseDownTarget?
    private var contextMenuTile: Tile?

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
        hoveredTile = hitTester.hitTest(point: point, tiles: renderedTiles)
    }

    override func mouseExited(with event: NSEvent) {
        hoveredTile = nil
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

    private func select(_ tile: Tile?) {
        if let tile, tile.nodeID == syntheticOtherNodeID {
            onSelect?(nil)
            onSyntheticOtherSelect?(tile.size)
        } else {
            onSelect?(tile?.nodeID)
        }
    }

    private func moveSelection(_ direction: KeyboardDirection) {
        guard !renderedTiles.isEmpty else { return }

        guard let selectedID,
              let currentTile = renderedTiles.first(where: { $0.nodeID == selectedID }) else {
            select(firstKeyboardTile())
            return
        }

        guard let next = neighboringTile(from: currentTile, direction: direction) else { return }
        select(next)
    }

    private func firstKeyboardTile() -> Tile? {
        renderedTiles
            .filter { $0.nodeID != syntheticOtherNodeID }
            .sorted { lhs, rhs in
                if lhs.rect.minY == rhs.rect.minY {
                    return lhs.rect.minX < rhs.rect.minX
                }
                return lhs.rect.minY < rhs.rect.minY
            }
            .first
    }

    private func neighboringTile(from tile: Tile, direction: KeyboardDirection) -> Tile? {
        let origin = center(of: tile.rect)
        let candidates = renderedTiles.filter { candidate in
            guard candidate.nodeID != tile.nodeID else { return false }
            let candidateCenter = center(of: candidate.rect)
            switch direction {
            case .left:
                return candidateCenter.x < origin.x
            case .right:
                return candidateCenter.x > origin.x
            case .up:
                return candidateCenter.y < origin.y
            case .down:
                return candidateCenter.y > origin.y
            }
        }

        return candidates.min { lhs, rhs in
            score(lhs, from: origin, direction: direction) < score(rhs, from: origin, direction: direction)
        }
    }

    private func score(_ tile: Tile, from origin: CGPoint, direction: KeyboardDirection) -> CGFloat {
        let target = center(of: tile.rect)
        switch direction {
        case .left, .right:
            return abs(target.x - origin.x) + abs(target.y - origin.y) * 0.45
        case .up, .down:
            return abs(target.y - origin.y) + abs(target.x - origin.x) * 0.45
        }
    }

    private func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    private func canActivate(_ tile: Tile) -> Bool {
        tile.nodeID != syntheticOtherNodeID && (tile.kind == .directory || tile.kind == .package)
    }

    private func addMenuItem(
        _ title: String,
        action: Selector,
        to menu: NSMenu,
        enabled: Bool = true
    ) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        item.isEnabled = enabled
        menu.addItem(item)
    }

    @objc private func enterContextMenuTile() {
        guard let contextMenuTile, canActivate(contextMenuTile) else { return }
        onActivate?(contextMenuTile.nodeID)
    }

    @objc private func previewContextMenuTile() {
        guard let contextMenuTile, contextMenuTile.nodeID != syntheticOtherNodeID else { return }
        onPreview?(contextMenuTile.nodeID)
    }

    @objc private func expandContextMenuPackage() {
        guard let contextMenuTile,
              contextMenuTile.nodeID != syntheticOtherNodeID,
              contextMenuTile.kind == .package else {
            return
        }
        onExpandPackage?(contextMenuTile.nodeID)
    }

    @objc private func revealContextMenuTile() {
        guard let contextMenuTile, contextMenuTile.nodeID != syntheticOtherNodeID else { return }
        onReveal?(contextMenuTile.nodeID)
    }

    @objc private func copyContextMenuTilePath() {
        guard let contextMenuTile, contextMenuTile.nodeID != syntheticOtherNodeID else { return }
        onCopyPath?(contextMenuTile.nodeID)
    }

    @objc private func moveContextMenuTileToTrash() {
        guard let contextMenuTile, contextMenuTile.nodeID != syntheticOtherNodeID else { return }
        onMoveToTrash?(contextMenuTile.nodeID)
    }

    private func doubleClickTarget(at point: CGPoint, fallback tile: Tile?) -> Tile? {
        guard let pendingDoubleClickTarget,
              pendingDoubleClickTarget.rootID == rootID,
              pendingDoubleClickTarget.distance(to: point) <= doubleClickTargetTolerance else {
            return tile
        }
        return renderedTiles.first { $0.nodeID == pendingDoubleClickTarget.nodeID } ?? tile
    }

    private func cachedTiles(
        snapshot: FileTreeSnapshot,
        rootID: NodeID,
        in bounds: CGRect,
        expandedNodeIDs: Set<NodeID>
    ) -> [Tile] {
        let key = TreemapLayoutCacheKey(
            snapshotIdentity: snapshotIdentity(for: snapshot),
            rootID: rootID,
            expandedNodeIDs: expandedNodeIDs,
            boundsMinX: Double(bounds.minX),
            boundsMinY: Double(bounds.minY),
            boundsWidth: Double(bounds.width),
            boundsHeight: Double(bounds.height)
        )

        if let layoutCache, layoutCache.key == key {
            return layoutCache.tiles
        }

        let tiles = builder.build(
            snapshot: snapshot,
            rootID: rootID,
            in: bounds,
            expandedNodeIDs: expandedNodeIDs
        )
        layoutCache = TreemapLayoutCache(key: key, tiles: tiles)
        return tiles
    }

    private func snapshotIdentity(for snapshot: FileTreeSnapshot) -> SnapshotLayoutIdentity {
        let storageAddress = snapshot.nodes.withUnsafeBufferPointer { buffer in
            buffer.baseAddress.map { UInt(bitPattern: $0) } ?? 0
        }
        return SnapshotLayoutIdentity(
            rootID: snapshot.rootID,
            nodeCount: snapshot.nodes.count,
            storageAddress: storageAddress
        )
    }

    private func draw(_ tile: Tile, in context: CGContext) {
        let rect = tile.rect
        guard rect.width > 0, rect.height > 0 else { return }

        let isSelected = tile.nodeID == selectedID
        let isHovered = tile == hoveredTile
        let color = fillColor(for: tile)
        let cornerRadius = min(CGFloat(5), max(1, min(rect.width, rect.height) * 0.08))
        let path = CGPath(roundedRect: rect, cornerWidth: cornerRadius, cornerHeight: cornerRadius, transform: nil)
        context.addPath(path)
        context.setFillColor((isHovered ? color.withAlphaComponent(min(color.alphaComponent + 0.16, 0.64)) : color).cgColor)
        context.fillPath()

        let strokeColor: NSColor
        let strokeWidth: CGFloat
        if isSelected {
            strokeColor = .controlAccentColor
            strokeWidth = 2
        } else if isHovered {
            strokeColor = .labelColor.withAlphaComponent(0.45)
            strokeWidth = 1.5
        } else {
            strokeColor = tile.depth == 0
                ? NSColor.separatorColor.withAlphaComponent(0.72)
                : NSColor.separatorColor.withAlphaComponent(0.48)
            strokeWidth = tile.depth == 0 ? 1 : 0.65
        }

        context.addPath(path)
        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.strokePath()

        drawLabel(for: tile, in: rect)
    }

    private func drawLabel(for tile: Tile, in rect: CGRect) {
        let mode = labelPolicy.mode(for: tile)
        guard mode != .none else { return }

        let labelRect: CGRect
        if mode == .containerTitle {
            labelRect = CGRect(
                x: rect.minX + 8,
                y: rect.minY + 4,
                width: max(0, rect.width - 16),
                height: max(0, tile.reservedHeaderHeight - 6)
            )
        } else {
            let inset = tile.depth == 0 ? CGFloat(8) : CGFloat(6)
            labelRect = rect.insetBy(dx: inset, dy: inset - 1)
        }
        guard labelRect.width > 12, labelRect.height > 10 else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        let drawSize = mode == .titleAndSize
        let titleFontSize = fittingFontSize(
            for: tile.label,
            width: labelRect.width,
            minSize: 9,
            maxSize: mode == .containerTitle || tile.depth == 0 ? 12 : 11,
            weight: .medium
        )

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: titleFontSize, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let sizeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]

        let titleHeight = drawSize ? 15 : min(labelRect.height, 15)

        guard titleHeight >= 10 else { return }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: labelRect).setClip()

        NSString(string: tile.label).draw(
            in: CGRect(x: labelRect.minX, y: labelRect.minY, width: labelRect.width, height: titleHeight),
            withAttributes: titleAttributes
        )

        if drawSize {
            NSString(string: ByteCount.string(tile.size)).draw(
                in: CGRect(x: labelRect.minX, y: labelRect.minY + 16, width: labelRect.width, height: 13),
                withAttributes: sizeAttributes
            )
        }

        NSGraphicsContext.restoreGraphicsState()
    }

    private func fittingFontSize(
        for text: String,
        width: CGFloat,
        minSize: CGFloat,
        maxSize: CGFloat,
        weight: NSFont.Weight
    ) -> CGFloat {
        var size = maxSize
        while size > minSize {
            let font = NSFont.systemFont(ofSize: size, weight: weight)
            let measured = NSString(string: text).size(withAttributes: [.font: font])
            if measured.width <= width {
                return size
            }
            size -= 1
        }
        return minSize
    }

    private func fillColor(for tile: Tile) -> NSColor {
        CategoryPalette.nsColor(for: tile.category, kind: tile.kind, flags: tile.flags, depth: tile.depth)
    }
}
