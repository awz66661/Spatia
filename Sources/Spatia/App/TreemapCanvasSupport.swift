import CoreGraphics
import SpatiaCore

struct MouseDownTarget {
    var nodeID: NodeID
    var rootID: NodeID?
    var point: CGPoint

    func distance(to other: CGPoint) -> CGFloat {
        let dx = point.x - other.x
        let dy = point.y - other.y
        return sqrt(dx * dx + dy * dy)
    }
}

struct SnapshotLayoutIdentity: Hashable {
    var rootID: NodeID
    var revision: UInt64
    var nodeCount: Int
}

struct TreemapLayoutCacheKey: Hashable {
    var snapshotIdentity: SnapshotLayoutIdentity
    var rootID: NodeID
    var expandedNodeIDs: Set<NodeID>
    var boundsMinX: Double
    var boundsMinY: Double
    var boundsWidth: Double
    var boundsHeight: Double
}

struct TreemapLayoutCache {
    var key: TreemapLayoutCacheKey
    var tiles: [Tile]
}

enum KeyboardDirection {
    case left
    case right
    case up
    case down
}
