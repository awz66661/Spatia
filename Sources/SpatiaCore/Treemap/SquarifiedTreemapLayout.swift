import CoreGraphics
import Foundation

public enum TreemapFlow: Hashable, Sendable {
    case rows
    case columns
}

public struct TreemapOrientationPolicy: Hashable, Sendable {
    public enum Strategy: Hashable, Sendable {
        case adaptive
        case columnsFirstAlternating
    }

    public var strategy: Strategy

    public init(strategy: Strategy = .adaptive) {
        self.strategy = strategy
    }

    public static let adaptive = TreemapOrientationPolicy(strategy: .adaptive)
    public static let spaceSniffer = TreemapOrientationPolicy(strategy: .columnsFirstAlternating)

    public func flow(for rect: CGRect, depth: Int) -> TreemapFlow {
        switch strategy {
        case .adaptive:
            return rect.width >= rect.height ? .rows : .columns
        case .columnsFirstAlternating:
            let isWide = rect.width >= rect.height
            let evenDepth = depth.isMultiple(of: 2)
            switch (isWide, evenDepth) {
            case (true, true), (false, false):
                return .columns
            case (true, false), (false, true):
                return .rows
            }
        }
    }
}

public struct SquarifiedTreemapLayout: Sendable {
    public var minTileArea: CGFloat
    public var maxItems: Int
    public var contentPadding: CGFloat
    public var readableWeightExponent: Double
    public var orientationPolicy: TreemapOrientationPolicy

    public init(
        minTileArea: CGFloat = 16,
        maxItems: Int = 500,
        contentPadding: CGFloat = 1,
        readableWeightExponent: Double = 1,
        orientationPolicy: TreemapOrientationPolicy = .adaptive
    ) {
        self.minTileArea = minTileArea
        self.maxItems = maxItems
        self.contentPadding = contentPadding
        self.readableWeightExponent = readableWeightExponent
        self.orientationPolicy = orientationPolicy
    }

    public func layout(items: [TreemapInput], in bounds: CGRect, depth: Int = 0) -> [Tile] {
        guard bounds.width > 1, bounds.height > 1 else { return [] }

        let positiveItems = items
            .filter { $0.size > 0 }
            .sorted { $0.size > $1.size }

        guard !positiveItems.isEmpty else { return [] }

        let totalWeight = positiveItems.reduce(CGFloat(0)) { $0 + layoutWeight(for: $1.size) }
        guard totalWeight > 0 else { return [] }

        let layoutRect = bounds.insetBy(dx: contentPadding, dy: contentPadding)
        guard layoutRect.width > 1, layoutRect.height > 1 else { return [] }

        let areaScale = (layoutRect.width * layoutRect.height) / totalWeight
        var weightedItems: [WeightedItem] = []
        var otherSize: Int64 = 0
        var otherArea: CGFloat = 0

        for (index, item) in positiveItems.enumerated() {
            let area = layoutWeight(for: item.size) * areaScale
            if index >= maxItems || area < minTileArea {
                otherSize += item.size
                otherArea += area
            } else {
                weightedItems.append(WeightedItem(input: item, area: area, depth: depth))
            }
        }

        if otherSize > 0 {
            weightedItems.append(
                WeightedItem(
                    input: TreemapInput(
                        nodeID: syntheticOtherNodeID,
                        label: "Other small files",
                        size: otherSize,
                        kind: .other
                    ),
                    area: otherArea,
                    depth: depth
                )
            )
        }

        return squarify(weightedItems, in: layoutRect, depth: depth)
    }

    public func layoutWeight(for size: Int64) -> CGFloat {
        guard size > 0 else { return 0 }
        let exponent = max(0.25, min(readableWeightExponent, 1))
        return CGFloat(pow(Double(size), exponent))
    }

    private func squarify(_ items: [WeightedItem], in rect: CGRect, depth: Int) -> [Tile] {
        var remaining = items
        var row: [WeightedItem] = []
        var currentRect = rect
        var tiles: [Tile] = []

        while !remaining.isEmpty {
            let next = remaining.removeFirst()
            let side = min(currentRect.width, currentRect.height)
            let currentWorst = worst(row: row, side: side)
            let candidateWorst = worst(row: row + [next], side: side)

            if row.isEmpty || candidateWorst <= currentWorst {
                row.append(next)
            } else {
                tiles.append(contentsOf: layout(row: row, in: &currentRect, depth: depth))
                row = [next]
            }
        }

        if !row.isEmpty {
            tiles.append(contentsOf: layout(row: row, in: &currentRect, depth: depth))
        }

        return tiles
    }

    private func worst(row: [WeightedItem], side: CGFloat) -> CGFloat {
        guard !row.isEmpty, side > 0 else { return .greatestFiniteMagnitude }

        let areas = row.map(\.area).filter { $0 > 0 }
        guard let minArea = areas.min(), let maxArea = areas.max() else {
            return .greatestFiniteMagnitude
        }

        let sum = areas.reduce(0, +)
        guard sum > 0 else { return .greatestFiniteMagnitude }

        let sideSquared = side * side
        return max(
            (sideSquared * maxArea) / (sum * sum),
            (sum * sum) / (sideSquared * minArea)
        )
    }

    private func layout(row: [WeightedItem], in rect: inout CGRect, depth: Int) -> [Tile] {
        guard !row.isEmpty, rect.width > 0, rect.height > 0 else { return [] }

        let areaSum = row.reduce(CGFloat(0)) { $0 + $1.area }
        guard areaSum > 0 else { return [] }

        var tiles: [Tile] = []
        let flow = orientationPolicy.flow(for: rect, depth: depth)

        switch flow {
        case .rows:
            let rowHeight = min(rect.height, areaSum / rect.width)
            var cursorX = rect.minX

            for item in row {
                let width = item.area / max(rowHeight, 1)
                let tileRect = CGRect(x: cursorX, y: rect.minY, width: width, height: rowHeight)
                tiles.append(item.tile(in: polished(tileRect)))
                cursorX += width
            }

            rect.origin.y += rowHeight
            rect.size.height = max(0, rect.height - rowHeight)
        case .columns:
            let columnWidth = min(rect.width, areaSum / rect.height)
            var cursorY = rect.minY

            for item in row {
                let height = item.area / max(columnWidth, 1)
                let tileRect = CGRect(x: rect.minX, y: cursorY, width: columnWidth, height: height)
                tiles.append(item.tile(in: polished(tileRect)))
                cursorY += height
            }

            rect.origin.x += columnWidth
            rect.size.width = max(0, rect.width - columnWidth)
        }

        return tiles
    }

    private func polished(_ rect: CGRect) -> CGRect {
        let inset: CGFloat = rect.width > 8 && rect.height > 8 ? 1 : 0
        return rect.insetBy(dx: inset, dy: inset).integral
    }
}

private struct WeightedItem {
    var input: TreemapInput
    var area: CGFloat
    var depth: Int

    func tile(in rect: CGRect) -> Tile {
        Tile(
            nodeID: input.nodeID,
            rect: rect,
            depth: depth,
            label: input.label,
            size: input.size,
            kind: input.kind,
            flags: input.flags,
            category: input.category
        )
    }
}
