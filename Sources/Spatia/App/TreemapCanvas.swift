import AppKit
import SpatiaCore
import SwiftUI

struct TreemapCanvas: NSViewRepresentable {
    var snapshot: FileTreeSnapshot
    var rootID: NodeID
    @Binding var selectedID: NodeID?
    var onActivate: (NodeID) -> Void
    var onPreview: (NodeID) -> Void

    func makeNSView(context: Context) -> TreemapNSView {
        let view = TreemapNSView()
        view.onSelect = { selectedID = $0 }
        view.onActivate = onActivate
        view.onPreview = onPreview
        return view
    }

    func updateNSView(_ nsView: TreemapNSView, context: Context) {
        nsView.snapshot = snapshot
        nsView.rootID = rootID
        nsView.selectedID = selectedID
        nsView.onSelect = { selectedID = $0 }
        nsView.onActivate = onActivate
        nsView.onPreview = onPreview
    }
}

final class TreemapNSView: NSView {
    var snapshot: FileTreeSnapshot? {
        didSet { needsDisplay = true }
    }

    var rootID: NodeID? {
        didSet { needsDisplay = true }
    }

    var selectedID: NodeID? {
        didSet { needsDisplay = true }
    }

    var onSelect: ((NodeID?) -> Void)?
    var onActivate: ((NodeID) -> Void)?
    var onPreview: ((NodeID) -> Void)?

    private var renderedTiles: [Tile] = []
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
            minTileArea: 30,
            maxItems: 420,
            contentPadding: 2,
            readableWeightExponent: 0.88,
            orientationPolicy: .spaceSniffer
        ),
        options: RecursiveTreemapBuildOptions(maxDepth: 3, childInset: 8, minimumParentArea: 1_600)
    )
    private let hitTester = TreemapHitTester(gapTolerance: 1)

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
            return
        }

        renderedTiles = builder.build(snapshot: snapshot, rootID: rootID, in: bounds.insetBy(dx: 8, dy: 8))

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
        onSelect?(hit?.nodeID)

        if event.clickCount == 2, let hit, hit.nodeID != syntheticOtherNodeID {
            onActivate?(hit.nodeID)
        }
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
        super.keyDown(with: event)
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
        let area = rect.width * rect.height
        guard area >= 1_500, rect.width >= 52, rect.height >= 20 else { return }

        let inset = tile.depth == 0 ? CGFloat(8) : CGFloat(6)
        let labelRect = rect.insetBy(dx: inset, dy: inset - 1)
        guard labelRect.width > 12, labelRect.height > 12 else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        let drawSize = area >= 5_400 && rect.width >= 76 && rect.height >= 42
        let titleFontSize = fittingFontSize(
            for: tile.label,
            width: labelRect.width,
            minSize: 9,
            maxSize: tile.depth == 0 ? 12 : 11,
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
        NSBezierPath(roundedRect: labelRect, xRadius: 2, yRadius: 2).setClip()

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
        if tile.flags.contains(.systemProtected) || tile.flags.contains(.permissionDenied) {
            return NSColor.systemGray.withAlphaComponent(0.28)
        }

        let base: NSColor = switch tile.category {
        case .video:
            .systemOrange
        case .image:
            .systemGreen
        case .audio:
            .systemPurple
        case .archive:
            .systemYellow
        case .appPackage:
            .systemIndigo
        case .document:
            .systemBlue
        case .source:
            .systemTeal
        case .cache:
            .systemGray
        case .system:
            .systemGray
        case .other:
            tile.kind == .directory || tile.kind == .volume ? .systemCyan : .systemMint
        }

        let alpha = max(0.18, 0.42 - CGFloat(tile.depth) * 0.055)
        return base.withAlphaComponent(alpha)
    }
}
