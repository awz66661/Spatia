import CoreGraphics
import Foundation

public enum TreemapLabelMode: Hashable, Sendable {
    case none
    case containerTitle
    case titleOnly
    case titleAndSize
}

public struct TreemapLabelPolicy: Hashable, Sendable {
    public var minimumTitleArea: CGFloat
    public var minimumDetailArea: CGFloat
    public var minimumTitleWidth: CGFloat
    public var minimumTitleHeight: CGFloat
    public var minimumDetailWidth: CGFloat
    public var minimumDetailHeight: CGFloat

    public init(
        minimumTitleArea: CGFloat = 1_800,
        minimumDetailArea: CGFloat = 5_800,
        minimumTitleWidth: CGFloat = 56,
        minimumTitleHeight: CGFloat = 20,
        minimumDetailWidth: CGFloat = 82,
        minimumDetailHeight: CGFloat = 44
    ) {
        self.minimumTitleArea = minimumTitleArea
        self.minimumDetailArea = minimumDetailArea
        self.minimumTitleWidth = minimumTitleWidth
        self.minimumTitleHeight = minimumTitleHeight
        self.minimumDetailWidth = minimumDetailWidth
        self.minimumDetailHeight = minimumDetailHeight
    }

    public func mode(for tile: Tile) -> TreemapLabelMode {
        if tile.reservedHeaderHeight > 0 {
            return tile.rect.width >= minimumTitleWidth && tile.reservedHeaderHeight >= 16
                ? .containerTitle
                : .none
        }

        let area = tile.rect.width * tile.rect.height
        guard area >= minimumTitleArea,
              tile.rect.width >= minimumTitleWidth,
              tile.rect.height >= minimumTitleHeight else {
            return .none
        }

        if area >= minimumDetailArea,
           tile.rect.width >= minimumDetailWidth,
           tile.rect.height >= minimumDetailHeight {
            return .titleAndSize
        }

        return .titleOnly
    }
}
