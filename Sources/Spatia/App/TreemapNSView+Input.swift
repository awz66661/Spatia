import AppKit
import SpatiaCore

extension TreemapNSView {
    func select(_ tile: Tile?) {
        if let tile, tile.nodeID == syntheticOtherNodeID {
            onSelect?(nil)
            onSyntheticOtherSelect?(tile.size)
        } else {
            onSelect?(tile?.nodeID)
        }
    }

    func updateHover(_ tile: Tile?) {
        guard hoveredTile != tile else { return }
        hoveredTile = tile
        toolTip = tooltip(for: tile)
        onHover?(tile?.nodeID)
    }

    func tooltip(for tile: Tile?) -> String? {
        guard let tile else { return nil }

        var lines = [
            tile.label,
            ByteCount.string(tile.size)
        ]
        if tile.nodeID != syntheticOtherNodeID,
           let path = snapshot?[tile.nodeID]?.url?.path {
            lines.append(path)
        }
        return lines.joined(separator: "\n")
    }

    func moveSelection(_ direction: KeyboardDirection) {
        guard !renderedTiles.isEmpty else { return }

        guard let selectedID,
              let currentTile = renderedTiles.first(where: { $0.nodeID == selectedID }) else {
            select(firstKeyboardTile())
            return
        }

        guard let next = neighboringTile(from: currentTile, direction: direction) else { return }
        select(next)
    }

    func firstKeyboardTile() -> Tile? {
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

    func neighboringTile(from tile: Tile, direction: KeyboardDirection) -> Tile? {
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

    func score(_ tile: Tile, from origin: CGPoint, direction: KeyboardDirection) -> CGFloat {
        let target = center(of: tile.rect)
        switch direction {
        case .left, .right:
            return abs(target.x - origin.x) + abs(target.y - origin.y) * 0.45
        case .up, .down:
            return abs(target.y - origin.y) + abs(target.x - origin.x) * 0.45
        }
    }

    func center(of rect: CGRect) -> CGPoint {
        CGPoint(x: rect.midX, y: rect.midY)
    }

    func canActivate(_ tile: Tile) -> Bool {
        tile.nodeID != syntheticOtherNodeID && (tile.kind == .directory || tile.kind == .package)
    }

    func addMenuItem(
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

    @objc func enterContextMenuTile() {
        guard let contextMenuTile, canActivate(contextMenuTile) else { return }
        onActivate?(contextMenuTile.nodeID)
    }

    @objc func previewContextMenuTile() {
        guard let contextMenuTile, contextMenuTile.nodeID != syntheticOtherNodeID else { return }
        onPreview?(contextMenuTile.nodeID)
    }

    @objc func expandContextMenuPackage() {
        guard let contextMenuTile,
              contextMenuTile.nodeID != syntheticOtherNodeID,
              contextMenuTile.kind == .package else {
            return
        }
        onExpandPackage?(contextMenuTile.nodeID)
    }

    @objc func revealContextMenuTile() {
        guard let contextMenuTile, contextMenuTile.nodeID != syntheticOtherNodeID else { return }
        onReveal?(contextMenuTile.nodeID)
    }

    @objc func copyContextMenuTilePath() {
        guard let contextMenuTile, contextMenuTile.nodeID != syntheticOtherNodeID else { return }
        onCopyPath?(contextMenuTile.nodeID)
    }

    @objc func moveContextMenuTileToTrash() {
        guard let contextMenuTile, contextMenuTile.nodeID != syntheticOtherNodeID else { return }
        onMoveToTrash?(contextMenuTile.nodeID)
    }

    func doubleClickTarget(at point: CGPoint, fallback tile: Tile?) -> Tile? {
        guard let pendingDoubleClickTarget,
              pendingDoubleClickTarget.rootID == rootID,
              pendingDoubleClickTarget.distance(to: point) <= doubleClickTargetTolerance else {
            return tile
        }
        return renderedTiles.first { $0.nodeID == pendingDoubleClickTarget.nodeID } ?? tile
    }
}
