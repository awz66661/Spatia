import AppKit
import SpatiaCore
import SwiftUI

struct TreemapCanvas: NSViewRepresentable {
    var inputs: [TreemapInput]
    @Binding var selectedID: NodeID?
    var onActivate: () -> Void

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
    var onActivate: (() -> Void)?

    private var renderedTiles: [Tile] = []
    private let layout = SquarifiedTreemapLayout(minTileArea: 24, maxItems: 450, contentPadding: 4)

    override var isFlipped: Bool { true }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
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
        let hit = renderedTiles.reversed().first { $0.rect.contains(point) }
        onSelect?(hit?.nodeID)

        if event.clickCount == 2, hit?.nodeID != syntheticOtherNodeID {
            onActivate?()
        }
    }

    private func draw(_ tile: Tile, in context: CGContext) {
        let rect = tile.rect
        guard rect.width > 0, rect.height > 0 else { return }

        let isSelected = tile.nodeID == selectedID
        let color = fillColor(for: tile)
        context.setFillColor(color.cgColor)
        context.fill(rect)

        context.setStrokeColor((isSelected ? NSColor.controlAccentColor : NSColor.separatorColor).cgColor)
        context.setLineWidth(isSelected ? 2 : 0.5)
        context.stroke(rect.insetBy(dx: 0.5, dy: 0.5))

        guard rect.width >= 54, rect.height >= 24 else { return }
        drawLabel(for: tile, in: rect)
    }

    private func drawLabel(for tile: Tile, in rect: CGRect) {
        let labelRect = rect.insetBy(dx: 7, dy: 5)
        guard labelRect.width > 12, labelRect.height > 12 else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byTruncatingTail

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11, weight: .medium),
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let sizeAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: paragraph
        ]

        NSString(string: tile.label).draw(
            in: CGRect(x: labelRect.minX, y: labelRect.minY, width: labelRect.width, height: 14),
            withAttributes: titleAttributes
        )

        if rect.height >= 42 {
            NSString(string: ByteCount.string(tile.size)).draw(
                in: CGRect(x: labelRect.minX, y: labelRect.minY + 16, width: labelRect.width, height: 13),
                withAttributes: sizeAttributes
            )
        }
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
