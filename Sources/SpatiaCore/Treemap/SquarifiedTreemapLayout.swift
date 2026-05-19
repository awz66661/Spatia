import CoreGraphics
import Foundation

public struct SquarifiedTreemapLayout: Sendable {
    public var minTileArea: CGFloat
    public var maxItems: Int
    public var contentPadding: CGFloat

    public init(
        minTileArea: CGFloat = 16,
        maxItems: Int = 500,
        contentPadding: CGFloat = 1
    ) {
        self.minTileArea = minTileArea
        self.maxItems = maxItems
        self.contentPadding = contentPadding
    }

    public func layout(items: [TreemapInput], in bounds: CGRect) -> [Tile] {
        guard bounds.width > 1, bounds.height > 1 else { return [] }

        let positiveItems = items
            .filter { $0.size > 0 }
            .sorted { $0.size > $1.size }

        guard !positiveItems.isEmpty else { return [] }

        let totalSize = positiveItems.reduce(Int64(0)) { $0 + $1.size }
        guard totalSize > 0 else { return [] }

        let layoutRect = bounds.insetBy(dx: contentPadding, dy: contentPadding)
        guard layoutRect.width > 1, layoutRect.height > 1 else { return [] }

        let areaScale = (layoutRect.width * layoutRect.height) / CGFloat(totalSize)
        var weightedItems: [WeightedItem] = []
        var otherSize: Int64 = 0

        for (index, item) in positiveItems.enumerated() {
            let area = CGFloat(item.size) * areaScale
            if index >= maxItems || area < minTileArea {
                otherSize += item.size
            } else {
                weightedItems.append(WeightedItem(input: item, area: area))
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
                    area: CGFloat(otherSize) * areaScale
                )
            )
        }

        return squarify(weightedItems, in: layoutRect)
    }

    private func squarify(_ items: [WeightedItem], in rect: CGRect) -> [Tile] {
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
                tiles.append(contentsOf: layout(row: row, in: &currentRect))
                row = [next]
            }
        }

        if !row.isEmpty {
            tiles.append(contentsOf: layout(row: row, in: &currentRect))
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

    private func layout(row: [WeightedItem], in rect: inout CGRect) -> [Tile] {
        guard !row.isEmpty, rect.width > 0, rect.height > 0 else { return [] }

        let areaSum = row.reduce(CGFloat(0)) { $0 + $1.area }
        guard areaSum > 0 else { return [] }

        var tiles: [Tile] = []

        if rect.width >= rect.height {
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
        } else {
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

    func tile(in rect: CGRect) -> Tile {
        Tile(
            nodeID: input.nodeID,
            rect: rect,
            depth: 0,
            label: input.label,
            size: input.size,
            kind: input.kind,
            flags: input.flags
        )
    }
}
