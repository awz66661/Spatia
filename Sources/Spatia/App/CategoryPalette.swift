import AppKit
import SpatiaCore
import SwiftUI

enum CategoryPalette {
    static func color(for category: FileCategory) -> Color {
        Color(nsColor: nsColor(for: category, kind: .file, flags: [], depth: 0))
    }

    static func nsColor(for category: FileCategory, kind: NodeKind, flags: NodeFlags, depth: Int) -> NSColor {
        if flags.contains(.systemProtected) || flags.contains(.immutable) || flags.contains(.permissionDenied) {
            return NSColor.systemGray.withAlphaComponent(0.28)
        }

        let base: NSColor = switch category {
        case .video:
            .systemOrange
        case .image:
            .systemGreen
        case .audio:
            .systemPurple
        case .archive:
            .systemYellow
        case .appPackage:
            .systemIndigo
        case .document:
            .systemBlue
        case .source:
            .systemTeal
        case .cache:
            .systemGray
        case .system:
            .systemGray
        case .other:
            kind == .directory ? .systemCyan : .systemMint
        }

        let alpha = max(0.18, 0.42 - CGFloat(depth) * 0.055)
        return base.withAlphaComponent(alpha)
    }
}
