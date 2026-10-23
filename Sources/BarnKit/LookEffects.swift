import SwiftUI

extension View {
    /// Draws a state's look on a card: glass tinted with its color plus its effects.
    /// `motion: false` skips effects that move the card (the switcher's list rows).
    /// `sideways` makes wiggle a side-to-side shake, for wide shapes that look broken tilted.
    func stateLook<S: InsettableShape>(_ style: StateStyle, in shape: S, motion: Bool = true,
                                       sideways: Bool = false) -> some View {
        modifier(StateLookModifier(style: style, shape: shape, motion: motion, sideways: sideways))
    }
}

private struct StateLookModifier<S: InsettableShape>: ViewModifier {
    var style: StateStyle
    var shape: S
    var motion: Bool
    var sideways: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion


    /// Flashing faster than 3 Hz can trigger seizures (WCAG 2.3.1), whatever the speed says.
    static var maxFlashHz: Double { 3 }

    private var effects: [Effect] {
        style.effects.filter { !$0.moves || (motion && !reduceMotion) }
    }

    func body(content: Content) -> some View {
        if effects.isEmpty {
            content
        } else if reduceMotion {
            // Hold the effects still: a steady border or halo instead of animation.
            content.overlay { frame(at: 0, still: true) }
        } else {
            TimelineView(.animation(minimumInterval: 1 / 30)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                content
                    .overlay { frame(at: t, still: false) }
                    .rotationEffect(.degrees(sideways ? 0 : wiggle(t)))
                    .offset(x: sideways ? wiggle(t) * 0.8 : 0, y: bounce(t))
            }
        }
    }

    // MARK: The layers

    @ViewBuilder
    private func frame(at t: Double, still: Bool) -> some View {
        let k = style.intensity
        let color = style.swiftColor
        ZStack {
            if effects.contains(.strobe) {
                shape.fill(color.opacity(0.6 * k * (still ? 0.5 : square(t, hz: 2))))
            }
            if effects.contains(.shimmer), !still {
                shape.fill(shimmer(t, color: color))
            }
            if effects.contains(.lines), !still {
                ForEach(0..<3, id: \.self) { i in shape.fill(line(t, index: i, color: color)) }
            }
            if effects.contains(.orbit) {
                orbit(t, still: still, color: color)
            }
            if effects.contains(.pulse) {
                shape.strokeBorder(color, lineWidth: 1.5)
                    .opacity(still ? k : 0.2 + 0.8 * k * wave(t, period: 1.6))
            }
            if effects.contains(.flash) {
                shape.strokeBorder(color, lineWidth: 2.5)
                    .opacity(still ? k : k * square(t, hz: 1.5))
            }
            if effects.contains(.rainbow) {
                shape.strokeBorder(AngularGradient(colors: Self.rainbow, center: .center,
                                                   angle: .degrees(still ? 0 : t * 120 * style.speed)),
                                   lineWidth: 2.5)
                    .opacity(0.4 + 0.6 * k)
            }
            if effects.contains(.glow) {
                let w = still ? 0.6 : wave(t, period: 2.4)
                shape.strokeBorder(color.opacity(0.9), lineWidth: 1)
                    .shadow(color: color.opacity(0.9 * k * w), radius: 4 + 10 * k * w)
                    .shadow(color: color.opacity(0.5 * k * w), radius: 2)
            }
        }
        .allowsHitTesting(false)
    }

    /// A soft band of light along the diagonal, sweeping corner to corner and then resting, so
    /// it reads as a glint rather than a scanner. Painted into the card's own shape: no edges.
    private func shimmer(_ t: Double, color: Color) -> LinearGradient {
        let period = 3.2 / style.speed
        let sweep = min(1, (t.truncatingRemainder(dividingBy: period) / period) / 0.45) // 0…1, then rest
        let eased = sweep * sweep * (3 - 2 * sweep)
        let half = 0.35 // band half-width, in unit space along the diagonal
        let p = -half + eased * (1 + 2 * half)
        let peak = 0.55 * style.intensity * (sweep < 1 ? 1 : 0)
        return LinearGradient(stops: [
            .init(color: color.opacity(0), location: 0),
            .init(color: color.opacity(peak * 0.35), location: 0.3),
            .init(color: color.opacity(peak), location: 0.5),
            .init(color: color.opacity(peak * 0.35), location: 0.7),
            .init(color: color.opacity(0), location: 1),
        ], startPoint: UnitPoint(x: p - half, y: p - half), endPoint: UnitPoint(x: p + half, y: p + half))
    }

    /// One of three thin diagonal lines that cross the card in quick succession, then rest.
    private func line(_ t: Double, index: Int, color: Color) -> LinearGradient {
        let period = 2.6 / style.speed
        let s = (t.truncatingRemainder(dividingBy: period) / period) * 1.7 - Double(index) * 0.16 // this line's 0…1
        let visible = s > 0 && s < 1
        let p = -0.2 + max(0, min(1, s)) * 1.4
        let peak = visible ? 0.55 * style.intensity * sin(.pi * s) : 0
        let w = 0.5
        return LinearGradient(stops: [
            .init(color: color.opacity(0), location: 0.465),
            .init(color: color.opacity(peak), location: 0.5),
            .init(color: color.opacity(0), location: 0.535),
        ], startPoint: UnitPoint(x: p - w, y: p - w), endPoint: UnitPoint(x: p + w, y: p + w))
    }

    /// A comet tracing the border in the state's color: a soft head and fading tail over a faint
    /// full rim, with a dim blurred copy for bloom. Kept gentle; it runs the whole time an agent works.
    @ViewBuilder
    private func orbit(_ t: Double, still: Bool, color: Color) -> some View {
        let k = style.intensity
        let angle = Angle.degrees(still ? -90 : (t * 360 * style.speed / 2.4).truncatingRemainder(dividingBy: 360))
        let comet = AngularGradient(stops: [
            .init(color: color.opacity(0), location: 0),
            .init(color: color.opacity(0), location: 0.5),
            .init(color: color.opacity(0.35 * k), location: 0.86),
            .init(color: color.opacity(0.6 * k), location: 0.96),
            .init(color: color.opacity(0.75 * k), location: 1),
        ], center: .center, angle: angle)
        ZStack {
            shape.strokeBorder(color.opacity(0.15 * k), lineWidth: 1)
            shape.strokeBorder(comet, lineWidth: 5).blur(radius: 4).opacity(0.4 * k)
            shape.strokeBorder(comet, lineWidth: 1.75)
        }
    }

    /// A short shake every few seconds.
    private func wiggle(_ t: Double) -> Double {
        guard effects.contains(.wiggle) else { return 0 }
        let local = t.truncatingRemainder(dividingBy: 2.6 / style.speed)
        guard local < 0.5 else { return 0 }
        return 5 * style.intensity * sin(local * 2 * .pi * 7) * (1 - local / 0.5)
    }

    /// A hop (and a smaller second one) every few seconds.
    private func bounce(_ t: Double) -> Double {
        guard effects.contains(.bounce) else { return 0 }
        let local = t.truncatingRemainder(dividingBy: 2.2 / style.speed)
        let h = 7 * style.intensity
        if local < 0.32 { return -h * sin(.pi * local / 0.32) }
        if local < 0.5 { return -h * 0.3 * sin(.pi * (local - 0.32) / 0.18) }
        return 0
    }

    /// 0…1 sine, at this style's speed.
    private func wave(_ t: Double, period: Double) -> Double {
        0.5 + 0.5 * sin(2 * .pi * t * style.speed / period)
    }

    /// 1 or 0, never faster than `maxFlashHz` full cycles a second.
    private func square(_ t: Double, hz: Double) -> Double {
        let f = min(Self.maxFlashHz, hz * style.speed)
        return (t * f).truncatingRemainder(dividingBy: 1) < 0.5 ? 1 : 0
    }

    private static var rainbow: [Color] {
        [.red, .orange, .yellow, .green, .mint, .blue, .purple, .pink, .red]
    }
}

/// Text colors on a card, so they stay readable on any look: tinted glass or solid.
extension StateStyle {
    /// Black or white, whichever reads on this color.
    func contrast(dark: Bool) -> Color {
        let c = resolved(dark: dark).usingColorSpace(.sRGB) ?? .gray
        let luminance = 0.2126 * c.redComponent + 0.7152 * c.greenComponent + 0.0722 * c.blueComponent
        return luminance > 0.55 ? .black : .white
    }

    func primaryText(dark: Bool) -> AnyShapeStyle {
        isSolid ? AnyShapeStyle(contrast(dark: dark)) : AnyShapeStyle(.primary)
    }

    func secondaryText(dark: Bool) -> AnyShapeStyle {
        isSolid ? AnyShapeStyle(contrast(dark: dark).opacity(0.62)) : AnyShapeStyle(.secondary)
    }

    /// The colored status line. Text in the state's own color would vanish into glass tinted
    /// the same color, so it's pushed toward the background's opposite.
    func detailText(for state: AgentState, dark: Bool) -> AnyShapeStyle {
        if isSolid { return AnyShapeStyle(contrast(dark: dark).opacity(0.85)) }
        guard state != .idle else { return AnyShapeStyle(.secondary) }
        let base = resolved(dark: dark)
        return AnyShapeStyle(Color(nsColor: base.blended(withFraction: dark ? 0.35 : 0.4, of: dark ? .white : .black) ?? base))
    }
}
