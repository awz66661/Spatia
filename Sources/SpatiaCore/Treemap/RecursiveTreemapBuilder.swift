import CoreGraphics
import Foundation

public struct RecursiveTreemapBuildOptions: Hashable, Sendable {
    public var maximumTraversalDepth: Int
    public var childInset: CGFloat
    public var minimumExpandableTileArea: CGFloat
    public var minimumChildContentArea: CGFloat
    public var minimumUsefulChildSide: CGFloat
    public var minimumUsefulChildArea: CGFloat
    public var reservedHeaderHeight: CGFloat
    public var maximumTileCount: Int?

    public init(
        maximumTraversalDepth: Int = 12,
        childInset: CGFloat = 8,
        minimumExpandableTileArea: CGFloat = 10_000,
        minimumChildContentArea: CGFloat = 7_500,
        minimumUsefulChildSide: CGFloat = 28,
        minimumUsefulChildArea: CGFloat = 900,
        reservedHeaderHeight: CGFloat = 22,
        maximumTileCount: Int? = nil
    ) {
        self.maximumTraversalDepth = maximumTraversalDepth
        self.childInset = childInset
        self.minimumExpandableTileArea = minimumExpandableTileArea
        self.minimumChildContentArea = minimumChildContentArea
        self.minimumUsefulChildSide = minimumUsefulChildSide
        self.minimumUsefulChildArea = minimumUsefulChildArea
        self.reservedHeaderHeight = reservedHeaderHeight
        self.maximumTileCount = maximumTileCount
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

    public func build(
        snapshot: FileTreeSnapshot,
        rootID: NodeID,
        in bounds: CGRect,
        expandedNodeIDs: Set<NodeID> = []
    ) -> [Tile] {
        guard let root = snapshot[rootID], bounds.width > 1, bounds.height > 1 else { return [] }
        var remainingTileBudget = max(0, options.maximumTileCount ?? Int.max)
        guard remainingTileBudget > 0 else { return [] }

        let children = visibleChildren(of: root, in: snapshot)
        guard !children.isEmpty else {
            remainingTileBudget -= 1
            return [tile(for: root, rect: bounds.insetBy(dx: 2, dy: 2), depth: 0)]
        }

        return buildChildren(
            of: root,
            in: snapshot,
            rect: bounds,
            depth: 0,
            expandedNodeIDs: expandedNodeIDs,
            remainingTileBudget: &remainingTileBudget
        )
    }

    private func buildChildren(
        of parent: FileNode,
        in snapshot: FileTreeSnapshot,
        rect: CGRect,
        depth: Int,
        expandedNodeIDs: Set<NodeID>,
        remainingTileBudget: inout Int
    ) -> [Tile] {
        guard remainingTileBudget > 0 else { return [] }
        guard depth < options.maximumTraversalDepth else { return [] }

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
        if tiles.count > remainingTileBudget {
            tiles = Array(tiles.prefix(remainingTileBudget))
        }
        remainingTileBudget -= tiles.count

        guard remainingTileBudget > 0, depth + 1 < options.maximumTraversalDepth else { return tiles }

        let expandableTileIndices = tiles.indices
            .filter { expandedNodeIDs.contains(tiles[$0].nodeID) && shouldRenderChildren(for: tiles[$0]) }
            .sorted { lhs, rhs in
                let lhsArea = tiles[lhs].rect.width * tiles[lhs].rect.height
                let rhsArea = tiles[rhs].rect.width * tiles[rhs].rect.height
                return lhsArea > rhsArea
            }

        for index in expandableTileIndices {
            guard remainingTileBudget > 0 else { break }
            var tile = tiles[index]
            guard let childNode = snapshot[tile.nodeID], !visibleChildren(of: childNode, in: snapshot).isEmpty else {
                continue
            }

            tile.reservedHeaderHeight = headerHeight(for: tile.rect, depth: depth)
            let childRect = insetForChildren(tile, depth: depth)
            guard shouldExpandChildren(of: childNode, in: snapshot, childRect: childRect, depth: depth + 1) else {
                continue
            }

            let childTiles = buildChildren(
                of: childNode,
                in: snapshot,
                rect: childRect,
                depth: depth + 1,
                expandedNodeIDs: expandedNodeIDs,
                remainingTileBudget: &remainingTileBudget
            )
            guard !childTiles.isEmpty else { continue }

            tiles[index] = tile
            tiles.append(contentsOf: childTiles)
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
        guard tile.kind == .directory || tile.kind == .package else { return false }
        return tile.rect.width * tile.rect.height >= options.minimumExpandableTileArea
    }

    private func shouldExpandChildren(
        of node: FileNode,
        in snapshot: FileTreeSnapshot,
        childRect: CGRect,
        depth: Int
    ) -> Bool {
        guard childRect.width >= options.minimumUsefulChildSide,
              childRect.height >= options.minimumUsefulChildSide,
              childRect.width * childRect.height >= options.minimumChildContentArea else {
            return false
        }

        let inputs = visibleChildren(of: node, in: snapshot).map { child in
            TreemapInput(
                nodeID: child.id,
                label: child.name,
                size: child.allocatedSize,
                kind: child.kind,
                flags: child.flags,
                category: FileCategoryClassifier.category(for: child)
            )
        }
        guard !inputs.isEmpty else { return false }

        let predictedTiles = layout.layout(items: inputs, in: childRect, depth: depth)
        return predictedTiles.contains { tile in
            let area = tile.rect.width * tile.rect.height
            return tile.rect.width >= options.minimumUsefulChildSide
                && tile.rect.height >= options.minimumUsefulChildSide
                && area >= options.minimumUsefulChildArea
        }
    }

    private func insetForChildren(_ tile: Tile, depth: Int) -> CGRect {
        let inset = max(3, options.childInset - CGFloat(depth * 2))
        let insetRect = tile.rect.insetBy(dx: inset, dy: inset)
        let headerHeight = min(tile.reservedHeaderHeight, max(0, insetRect.height - options.minimumUsefulChildSide))
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
