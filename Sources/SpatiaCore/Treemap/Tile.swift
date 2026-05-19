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

    public init(
        nodeID: NodeID,
        rect: CGRect,
        depth: Int,
        label: String,
        size: Int64,
        kind: NodeKind,
        flags: NodeFlags = [],
        category: FileCategory = .other
    ) {
        self.nodeID = nodeID
        self.rect = rect
        self.depth = depth
        self.label = label
        self.size = size
        self.kind = kind
        self.flags = flags
        self.category = category
    }
}
