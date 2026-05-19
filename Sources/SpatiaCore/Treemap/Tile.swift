import CoreGraphics
import Foundation

public struct TreemapInput: Hashable, Sendable {
    public var nodeID: NodeID
    public var label: String
    public var size: Int64
    public var kind: NodeKind
    public var flags: NodeFlags
    public var category: FileCategory

    public init(
        nodeID: NodeID,
        label: String,
        size: Int64,
        kind: NodeKind,
        flags: NodeFlags = [],
        category: FileCategory = .other
    ) {
        self.nodeID = nodeID
        self.label = label
        self.size = size
        self.kind = kind
        self.flags = flags
        self.category = category
    }
}

public struct Tile: Hashable, Sendable {
    public var nodeID: NodeID
    public var rect: CGRect
    public var depth: Int
    public var label: String
    public var size: Int64
    public var kind: NodeKind
    public var flags: NodeFlags
    public var category: FileCategory
    public var reservedHeaderHeight: CGFloat

    public init(
        nodeID: NodeID,
        rect: CGRect,
        depth: Int,
        label: String,
        size: Int64,
        kind: NodeKind,
        flags: NodeFlags = [],
        category: FileCategory = .other,
        reservedHeaderHeight: CGFloat = 0
    ) {
        self.nodeID = nodeID
        self.rect = rect
        self.depth = depth
        self.label = label
        self.size = size
        self.kind = kind
        self.flags = flags
        self.category = category
        self.reservedHeaderHeight = reservedHeaderHeight
    }

    public var reservedHeaderRect: CGRect {
        guard reservedHeaderHeight > 0 else { return .null }
        return CGRect(
            x: rect.minX,
            y: rect.minY,
            width: rect.width,
            height: min(reservedHeaderHeight, rect.height)
        )
    }

    public static func == (lhs: Tile, rhs: Tile) -> Bool {
        lhs.nodeID == rhs.nodeID &&
            lhs.rect.origin.x == rhs.rect.origin.x &&
            lhs.rect.origin.y == rhs.rect.origin.y &&
            lhs.rect.size.width == rhs.rect.size.width &&
            lhs.rect.size.height == rhs.rect.size.height &&
            lhs.depth == rhs.depth &&
            lhs.label == rhs.label &&
            lhs.size == rhs.size &&
            lhs.kind == rhs.kind &&
            lhs.flags == rhs.flags &&
            lhs.category == rhs.category &&
            lhs.reservedHeaderHeight == rhs.reservedHeaderHeight
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(nodeID)
        hasher.combine(Double(rect.origin.x))
        hasher.combine(Double(rect.origin.y))
        hasher.combine(Double(rect.size.width))
        hasher.combine(Double(rect.size.height))
        hasher.combine(depth)
        hasher.combine(label)
        hasher.combine(size)
        hasher.combine(kind)
        hasher.combine(flags)
        hasher.combine(category)
        hasher.combine(Double(reservedHeaderHeight))
    }
}
