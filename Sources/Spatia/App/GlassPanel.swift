import AppKit
import SwiftUI

struct GlassPanel<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var material: NSVisualEffectView.Material = .sidebar
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            if reduceTransparency {
                Color(nsColor: .controlBackgroundColor)
            } else {
                VisualEffectBackground(material: material)
            }

            content
        }
    }
}

private struct VisualEffectBackground: NSViewRepresentable {
    var material: NSVisualEffectView.Material

    func makeNSView(context: Context) -> NSView {
        if #available(macOS 26.0, *) {
            let view = NSGlassEffectView()
            view.style = .regular
            view.cornerRadius = 0
            view.tintColor = NSColor.controlBackgroundColor.withAlphaComponent(0.16)
            return view
        }

        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if #available(macOS 26.0, *), let glass = nsView as? NSGlassEffectView {
            glass.style = .regular
            glass.tintColor = NSColor.controlBackgroundColor.withAlphaComponent(0.16)
            return
        }

        guard let visualEffect = nsView as? NSVisualEffectView else { return }
        visualEffect.material = material
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
    }
}
