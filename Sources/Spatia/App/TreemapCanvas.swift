import AppKit
import SpatiaCore
import SwiftUI

struct TreemapCanvas: NSViewRepresentable {
    var inputs: [TreemapInput]
    @Binding var selectedID: NodeID?
    var onActivate: (NodeID) -> Void

    func makeNSView(context: Context) -> TreemapNSView {
        let view = TreemapNSView()
        view.onSelect = { selectedID = $0 }
        view.onActivate = onActivate
        return view
    }

    func updateNSView(_ nsView: TreemapNSView, context: Context) {
        nsView.inputs = inputs
        nsView.selectedID = selectedID
        nsView.onSelect = { selectedID = $0 }
        nsView.onActivate = onActivate
    }
}

final class TreemapNSView: NSView {
    var inputs: [TreemapInput] = [] {
        didSet { needsDisplay = true }
    }

    var selectedID: NodeID? {
        didSet { needsDisplay = true }
    }

    var onSelect: ((NodeID?) -> Void)?
    var onActivate: ((NodeID) -> Void)?

    private var renderedTiles: [Tile] = []
    private var trackingArea: NSTrackingArea?
    private var hoveredID: NodeID? {
        didSet {
            if hoveredID != oldValue {
                needsDisplay = true
            }
        }
    }

    private let layout = SquarifiedTreemapLayout(minTileArea: 24, maxItems: 450, contentPadding: 4)
    private let hitTester = TreemapHitTester(gapTolerance: 1)

    override var isFlipped: Bool { true }

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
        NSColor.textBackgroundColor.setFill()
        dirtyRect.fill()

        renderedTiles = layout.layout(items: inputs, in: bounds)

        guard let context = NSGraphicsContext.current?.cgContext else { return }
        context.setAllowsAntialiasing(true)

        for tile in renderedTiles {
            draw(tile, in: context)
        }
    }

    override func mouseDown(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        let hit = hitTester.hitTest(point: point, tiles: renderedTiles)
        onSelect?(hit?.nodeID)

        if event.clickCount == 2, let hit, hit.nodeID != syntheticOtherNodeID {
            onActivate?(hit.nodeID)
        }
    }

    override func mouseMoved(with event: NSEvent) {
        let point = convert(event.locationInWindow, from: nil)
        hoveredID = hitTester.hitTest(point: point, tiles: renderedTiles)?.nodeID
    }

    override func mouseExited(with event: NSEvent) {
        hoveredID = nil
    }

    private func draw(_ tile: Tile, in context: CGContext) {
        let rect = tile.rect
        guard rect.width > 0, rect.height > 0 else { return }

        let isSelected = tile.nodeID == selectedID
        let isHovered = tile.nodeID == hoveredID
        let color = fillColor(for: tile)
        context.setFillColor((isHovered ? color.withAlphaComponent(min(color.alphaComponent + 0.14, 0.55)) : color).cgColor)
        context.fill(rect)

        let strokeColor: NSColor
        let strokeWidth: CGFloat
        if isSelected {
            strokeColor = .controlAccentColor
            strokeWidth = 2
        } else if isHovered {
            strokeColor = .labelColor.withAlphaComponent(0.45)
            strokeWidth = 1.5
        } else {
            strokeColor = .separatorColor
            strokeWidth = 0.5
        }

        context.setStrokeColor(strokeColor.cgColor)
        context.setLineWidth(strokeWidth)
        context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))

        guard rect.width >= 46, rect.height >= 18 else { return }
        drawLabel(for: tile, in: rect)
    }

    private func drawLabel(for tile: Tile, in rect: CGRect) {
        let labelRect = rect.insetBy(dx: 7, dy: 5)
        guard labelRect.width > 12, labelRect.height > 12 else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        let titleFontSize = fittingFontSize(
            for: tile.label,
            width: labelRect.width,
            minSize: 9,
            maxSize: 11,
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

        let shouldDrawSize = rect.width >= 68 && rect.height >= 40
        let titleHeight = shouldDrawSize ? 14 : min(labelRect.height, 14)

        guard titleHeight >= 10 else { return }

        NSGraphicsContext.saveGraphicsState()
        NSBezierPath(rect: labelRect).setClip()

        NSString(string: tile.label).draw(
            in: CGRect(x: labelRect.minX, y: labelRect.minY, width: labelRect.width, height: titleHeight),
            withAttributes: titleAttributes
        )

        if shouldDrawSize {
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
        let base: NSColor

        switch tile.kind {
        case .directory:
            base = .systemBlue
        case .package:
            base = .systemIndigo
        case .file:
            base = .systemTeal
        case .symlink:
            base = .systemPurple
        case .volume:
            base = .systemMint
        case .other:
            base = .systemGray
        }

        if tile.flags.contains(.systemProtected) {
            return NSColor.systemGray.withAlphaComponent(0.35)
        }

        return base.withAlphaComponent(0.22)
    }
}
