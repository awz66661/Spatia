import AppKit
import SpatiaCore

extension TreemapNSView {
    func cachedTiles(
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

    func snapshotIdentity(for snapshot: FileTreeSnapshot) -> SnapshotLayoutIdentity {
        return SnapshotLayoutIdentity(
            rootID: snapshot.rootID,
            revision: snapshot.revision,
            nodeCount: snapshot.nodes.count
        )
    }

    func draw(_ tile: Tile, in context: CGContext) {
        let rect = tile.rect
        guard rect.width > 0, rect.height > 0 else { return }

        let isSelected = tile.nodeID == selectedID
        let isHovered = tile == hoveredTile
        let isHighlightedPath = highlightedNodeIDs.contains(tile.nodeID)
            && !isSelected
            && tile.nodeID != syntheticOtherNodeID
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
        } else if isHighlightedPath {
            strokeColor = .controlAccentColor.withAlphaComponent(0.7)
            strokeWidth = 1.2
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

    func drawLabel(for tile: Tile, in rect: CGRect) {
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

    func fittingFontSize(
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

    func fillColor(for tile: Tile) -> NSColor {
        CategoryPalette.nsColor(for: tile.category, kind: tile.kind, flags: tile.flags, depth: tile.depth)
    }
}
