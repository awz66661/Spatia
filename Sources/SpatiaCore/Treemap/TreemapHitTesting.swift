import CoreGraphics
import Foundation

public struct TreemapHitTester: Sendable {
    public var gapTolerance: CGFloat

    public init(gapTolerance: CGFloat = 1) {
        self.gapTolerance = gapTolerance
    }

    public func hitTest(point: CGPoint, tiles: [Tile]) -> Tile? {
        let candidates = tiles.filter { tile in
            guard tile.rect.width > 0, tile.rect.height > 0 else { return false }
            return tile.rect.insetBy(dx: -gapTolerance, dy: -gapTolerance).contains(point)
        }

        return candidates.min { lhs, rhs in
            let lhsArea = lhs.rect.width * lhs.rect.height
            let rhsArea = rhs.rect.width * rhs.rect.height
            if lhsArea == rhsArea {
                return lhs.nodeID > rhs.nodeID
            }
            return lhsArea < rhsArea
        }
    }
}
