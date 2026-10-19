import SwiftUI

extension View {
    /// Liquid Glass on macOS 26+, frosted material with a hairline rim before that.
    @ViewBuilder
    func barnGlass<S: InsettableShape>(in shape: S, tint: Color? = nil, interactive: Bool = false) -> some View {
        if #available(macOS 26, *) {
            glassEffect(makeGlass(tint: tint, interactive: interactive), in: shape)
        } else {
            background {
                ZStack {
                    shape.fill(.ultraThinMaterial)
                    if let tint { shape.fill(tint) }
                }
            }
            .overlay(shape.strokeBorder(.white.opacity(0.22), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.18), radius: 12, y: 4)
        }
    }
}

@available(macOS 26, *)
private func makeGlass(tint: Color?, interactive: Bool) -> Glass {
    var glass = Glass.regular
    if let tint { glass = glass.tint(tint) }
    if interactive { glass = glass.interactive() }
    return glass
}

/// Groups glass shapes so they blend and morph together (GlassEffectContainer on macOS 26+).
struct GlassGroup<Content: View>: View {
    var spacing: CGFloat = 8
    @ViewBuilder var content: Content

    var body: some View {
        if #available(macOS 26, *) {
            GlassEffectContainer(spacing: spacing) { content }
        } else {
            content
        }
    }
}
