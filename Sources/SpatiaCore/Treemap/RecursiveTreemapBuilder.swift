import CoreGraphics
import Foundation

public struct RecursiveTreemapBuildOptions: Hashable, Sendable {
    public var maxDepth: Int
    public var childInset: CGFloat
    public var minimumParentArea: CGFloat
    public var minimumChildSide: CGFloat
    public var reservedHeaderHeight: CGFloat

    public init(
        maxDepth: Int = 3,
        childInset: CGFloat = 8,
        minimumParentArea: CGFloat = 1_800,
        minimumChildSide: CGFloat = 26,
        reservedHeaderHeight: CGFloat = 22
    ) {
        self.maxDepth = maxDepth
        self.childInset = childInset
        self.minimumParentArea = minimumParentArea
        self.minimumChildSide = minimumChildSide
        self.reservedHeaderHeight = reservedHeaderHeight
    }
}

public struct RecursiveTreemapBuilder: Sendable {
    public var layout: SquarifiedTreemapLayout
    public var options: RecursiveTreemapBuildOptions

    public init(
        layout: SquarifiedTreemapLayout = SquarifiedTreemapLayout(
            minTileArea: 24,
            maxItems: 450,
            contentPadding: 2,
            readableWeightExponent: 0.88,
            orientationPolicy: .spaceSniffer
        ),
        options: RecursiveTreemapBuildOptions = RecursiveTreemapBuildOptions()
    ) {
        self.layout = layout
        self.options = options
    }

    public func build(snapshot: FileTreeSnapshot, rootID: NodeID, in bounds: CGRect) -> [Tile] {
        guard let root = snapshot[rootID], bounds.width > 1, bounds.height > 1 else { return [] }

        let children = visibleChildren(of: root, in: snapshot)
        guard !children.isEmpty else {
            return [tile(for: root, rect: bounds.insetBy(dx: 2, dy: 2), depth: 0)]
        }

        return buildChildren(of: root, in: snapshot, rect: bounds, depth: 0)
    }

    private func buildChildren(
        of parent: FileNode,
        in snapshot: FileTreeSnapshot,
        rect: CGRect,
        depth: Int
    ) -> [Tile] {
        guard depth < options.maxDepth else { return [] }

        let children = visibleChildren(of: parent, in: snapshot)
        guard !children.isEmpty else { return [] }

        let inputs = children.map { node in
            TreemapInput(
                nodeID: node.id,
                label: node.name,
                size: node.allocatedSize,
                kind: node.kind,
                flags: node.flags,
                category: FileCategoryClassifier.category(for: node)
            )
        }

        var tiles = layout.layout(items: inputs, in: rect, depth: depth)

        guard depth + 1 < options.maxDepth else { return tiles }

        for index in tiles.indices where shouldRenderChildren(for: tiles[index]) {
            var tile = tiles[index]
            guard let childNode = snapshot[tile.nodeID], !visibleChildren(of: childNode, in: snapshot).isEmpty else {
                continue
            }

            tile.reservedHeaderHeight = headerHeight(for: tile.rect, depth: depth)
            let childRect = insetForChildren(tile, depth: depth)
            guard childRect.width >= options.minimumChildSide, childRect.height >= options.minimumChildSide else {
                continue
            }

            tiles[index] = tile
            tiles.append(contentsOf: buildChildren(of: childNode, in: snapshot, rect: childRect, depth: depth + 1))
        }

        return tiles
    }

    private func visibleChildren(of node: FileNode, in snapshot: FileTreeSnapshot) -> [FileNode] {
        snapshot.children(of: node.id)
            .filter { $0.allocatedSize > 0 }
            .sorted { lhs, rhs in
                if lhs.allocatedSize == rhs.allocatedSize {
                    return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
                }
                return lhs.allocatedSize > rhs.allocatedSize
            }
    }

    private func shouldRenderChildren(for tile: Tile) -> Bool {
        guard tile.nodeID != syntheticOtherNodeID else { return false }
        guard tile.kind == .directory || tile.kind == .package || tile.kind == .volume else { return false }
        return tile.rect.width * tile.rect.height >= options.minimumParentArea
    }

    private func insetForChildren(_ tile: Tile, depth: Int) -> CGRect {
        let inset = max(3, options.childInset - CGFloat(depth * 2))
        let insetRect = tile.rect.insetBy(dx: inset, dy: inset)
        let headerHeight = min(tile.reservedHeaderHeight, max(0, insetRect.height - options.minimumChildSide))
        return CGRect(
            x: insetRect.minX,
            y: insetRect.minY + headerHeight,
            width: insetRect.width,
            height: max(0, insetRect.height - headerHeight)
        )
    }

    private func headerHeight(for rect: CGRect, depth: Int) -> CGFloat {
        guard rect.width >= 72, rect.height >= 44 else { return 0 }
        return max(18, options.reservedHeaderHeight - CGFloat(depth * 2))
    }

    private func tile(for node: FileNode, rect: CGRect, depth: Int) -> Tile {
        Tile(
            nodeID: node.id,
            rect: rect,
            depth: depth,
            label: node.name,
            size: node.allocatedSize,
            kind: node.kind,
            flags: node.flags,
            category: FileCategoryClassifier.category(for: node)
        )
    }
}
