import AppKit
import QuartzCore
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

/// Flashing faster than 3 Hz can trigger seizures (WCAG 2.3.1), whatever the speed says.
private let maxFlashHz: Double = 3

/// Effects that draw on the card (borders, fills, halos) run as Core Animation layers, so the
/// window server animates them and barn itself stays idle. Redrawing them from SwiftUI every
/// frame cost a working deck 20–50% CPU. Wiggle and bounce move the card itself, so SwiftUI
/// drives them, but only during the half second each hop or shake lasts.
private struct StateLookModifier<S: InsettableShape>: ViewModifier {
    var style: StateStyle
    var shape: S
    var motion: Bool
    var sideways: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var effects: [Effect] {
        style.effects.filter { !$0.moves || (motion && !reduceMotion) }
    }

    func body(content: Content) -> some View {
        let drawn = effects.filter { !$0.moves }
        let layered = content.overlay {
            if !drawn.isEmpty {
                // Reduce Motion holds them still: a steady border or halo instead of animation.
                EffectLayers(style: style, effects: drawn, shape: shape, still: reduceMotion)
                    .allowsHitTesting(false)
            }
        }
        let bursts = effects.compactMap(burst)
        if bursts.isEmpty {
            layered
        } else {
            TimelineView(BurstSchedule(bursts: bursts)) { ctx in
                let t = ctx.date.timeIntervalSinceReferenceDate
                layered
                    .rotationEffect(.degrees(sideways ? 0 : wiggle(t)))
                    .offset(x: sideways ? wiggle(t) * 0.8 : 0, y: bounce(t))
            }
        }
    }

    private func burst(_ effect: Effect) -> BurstSchedule.Burst? {
        switch effect {
        case .wiggle: BurstSchedule.Burst(period: 2.6 / style.speed, length: 0.5)
        case .bounce: BurstSchedule.Burst(period: 2.2 / style.speed, length: 0.5)
        default: nil
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
}

/// Frames at 30 fps while a burst of motion plays (the first `length` seconds of every
/// `period`, by the wall clock), one frame to settle when it ends, then nothing until the next.
struct BurstSchedule: TimelineSchedule {
    struct Burst: Sendable {
        var period: Double
        var length: Double
    }

    var bursts: [Burst]
    var fps: Double = 30

    func entries(from startDate: Date, mode: TimelineScheduleMode) -> AnyIterator<Date> {
        var t = startDate.timeIntervalSinceReferenceDate
        var first = true
        return AnyIterator {
            if first {
                first = false
            } else {
                // SwiftUI walks the schedule from the timeline's start on every update; skipping
                // the past keeps that walk short however long the deck has been open.
                let from = max(t, Date.timeIntervalSinceReferenceDate)
                t = bursts.map { next(after: from, $0) }.min() ?? from + 1
            }
            return Date(timeIntervalSinceReferenceDate: t)
        }
    }

    func next(after t: Double, _ burst: Burst) -> Double {
        let start = (t / burst.period).rounded(.down) * burst.period
        let end = start + burst.length
        return t < end - 1e-6 ? min(t + 1 / fps, end) : start + burst.period
    }
}

// MARK: The layers

private struct EffectLayers<S: InsettableShape>: NSViewRepresentable {
    var style: StateStyle
    var effects: [Effect]
    var shape: S
    var still: Bool

    func makeNSView(context: Context) -> EffectView { EffectView() }

    func updateNSView(_ view: EffectView, context: Context) {
        let shape = shape
        view.configure(
            EffectView.Config(style: style, effects: effects, still: still,
                              outline: shape.path(in: CGRect(x: 0, y: 0, width: 100, height: 100))),
            path: { rect, inset in shape.inset(by: inset).path(in: rect).cgPath })
    }
}

/// Hosts a card's effect layers. Rebuilt only when the style, size or appearance changes; between
/// those, Core Animation plays every effect on its own.
final class EffectView: NSView {
    struct Config: Equatable {
        var style: StateStyle
        var effects: [Effect]
        var still: Bool
        /// The card's shape at a fixed size, so a new corner radius rebuilds the layers.
        var outline: Path
    }

    private var config: Config?
    private var built: (config: Config, size: CGSize)?
    private var path: (CGRect, CGFloat) -> CGPath = { rect, _ in CGPath(rect: rect, transform: nil) }

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(_ config: Config, path: @escaping (CGRect, CGFloat) -> CGPath) {
        self.path = path
        self.config = config
        rebuild()
    }

    override func layout() {
        super.layout()
        rebuild()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuild(force: true)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rebuild(force: true)
    }

    private func rebuild(force: Bool = false) {
        guard let config, let root = layer, window != nil, bounds.width > 0, bounds.height > 0 else { return }
        if !force, let built, built.config == config, built.size == bounds.size { return }
        built = (config, bounds.size)

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.sublayers?.forEach { $0.removeFromSuperlayer() }
        var color = CGColor.clear
        var rainbow: [CGColor] = []
        effectiveAppearance.performAsCurrentDrawingAppearance {
            color = config.style.nsColor.cgColor
            rainbow = [Color.red, .orange, .yellow, .green, .mint, .blue, .purple, .pink, .red].map { NSColor($0).cgColor }
        }
        let paint = EffectPainter(style: config.style, bounds: bounds, color: color, rainbow: rainbow,
                                  still: config.still, path: path)
        // Bottom to top: fills under borders, halos last.
        for effect in [Effect.strobe, .shimmer, .lines, .orbit, .pulse, .flash, .rainbow, .glow]
        where config.effects.contains(effect) {
            paint.layers(for: effect).forEach(root.addSublayer)
        }
        CATransaction.commit()
    }
}

/// Builds one effect's layers and the looping animations that play it. Each animation is
/// sampled from the same timing curves the effect always had, and starts at the wall clock's
/// point in its cycle, so every card running an effect moves in step.
private struct EffectPainter {
    var style: StateStyle
    var bounds: CGRect
    var color: CGColor
    var rainbow: [CGColor]
    var still: Bool
    var path: (CGRect, CGFloat) -> CGPath

    private var k: Double { style.intensity }
    private func color(_ alpha: Double) -> CGColor { color.copy(alpha: color.alpha * alpha) ?? color }

    func layers(for effect: Effect) -> [CALayer] {
        switch effect {
        case .strobe:
            let fill = shape(fill: color(0.6 * k))
            fill.opacity = 0.5
            if !still { fill.add(blink(hz: 2, on: 1), forKey: "strobe") }
            return [fill]

        case .shimmer:
            // A soft band of light along the diagonal, sweeping corner to corner and then resting,
            // so it reads as a glint rather than a scanner.
            guard !still else { return [] }
            let peak = 0.55 * k
            let band = gradient([color(0), color(peak * 0.35), color(peak), color(peak * 0.35), color(0)],
                                at: [0, 0.3, 0.5, 0.7, 1])
            let period = 3.2 / style.speed
            let half = 0.35 // band half-width, in unit space along the diagonal
            func p(_ t: Double) -> Double {
                let sweep = min(1, (t / period) / 0.45) // 0…1, then rest
                return -half + sweep * sweep * (3 - 2 * sweep) * (1 + 2 * half)
            }
            band.add(sampled("startPoint", period: period, steps: 64) { value(p($0) - half) }, forKey: "start")
            band.add(sampled("endPoint", period: period, steps: 64) { value(p($0) + half) }, forKey: "end")
            return [clipped([band], to: shape(fill: .black))]

        case .lines:
            // Three thin diagonal lines that cross the card in quick succession, then rest.
            guard !still else { return [] }
            let period = 2.6 / style.speed
            let lines = (0..<3).map { i -> CALayer in
                let line = gradient([color(0), color(0.55 * k), color(0)], at: [0.465, 0.5, 0.535])
                func s(_ t: Double) -> Double { t / period * 1.7 - Double(i) * 0.16 } // this line's 0…1
                func p(_ t: Double) -> Double { -0.2 + max(0, min(1, s(t))) * 1.4 }
                line.opacity = 0
                line.add(sampled("startPoint", period: period, steps: 96) { value(p($0) - 0.5) }, forKey: "start")
                line.add(sampled("endPoint", period: period, steps: 96) { value(p($0) + 0.5) }, forKey: "end")
                line.add(sampled("opacity", period: period, steps: 96) { t -> Float in
                    let s = s(t)
                    return s > 0 && s < 1 ? Float(sin(.pi * s)) : 0
                }, forKey: "fade")
                return line
            }
            return [clipped(lines, to: shape(fill: .black))]

        case .orbit:
            // A comet tracing the border: a soft head and fading tail over a faint full rim, with
            // a halo for bloom. Kept gentle; it runs the whole time an agent works.
            let comet = spinner([color(0), color(0), color(0.35 * k), color(0.6 * k), color(0.75 * k)],
                                at: [0, 0.5, 0.86, 0.96, 1], period: 2.4 / style.speed, still: -.pi / 2)
            let ring = clipped([comet], to: shape(stroke: 1.75, color: .black))
            let bloom = CALayer()
            bloom.frame = bounds
            bloom.addSublayer(ring)
            bloom.shadowColor = color
            bloom.shadowOffset = .zero
            bloom.shadowRadius = 3
            bloom.shadowOpacity = Float(0.7 * k)
            return [shape(stroke: 1, color: color(0.15 * k)), bloom]

        case .pulse:
            let border = shape(stroke: 1.5, color: color)
            border.opacity = Float(k)
            if !still {
                border.add(sampled("opacity", period: 1.6 / style.speed) { Float(0.2 + 0.8 * k * wave($0, 1.6)) },
                           forKey: "pulse")
            }
            return [border]

        case .flash:
            let border = shape(stroke: 2.5, color: color)
            border.opacity = Float(k)
            if !still { border.add(blink(hz: 1.5, on: Float(k)), forKey: "flash") }
            return [border]

        case .rainbow:
            let ring = clipped([spinner(rainbow, at: nil, period: 3 / style.speed, still: 0)],
                               to: shape(stroke: 2.5, color: .black))
            ring.opacity = Float(0.4 + 0.6 * k)
            return [ring]

        case .glow:
            // The halo is two shadows cast by the border's outline alone, breathing together.
            let border = shape(stroke: 1, color: color(0.9))
            let outline = path(bounds, 0.5).copy(strokingWithWidth: 1, lineCap: .butt, lineJoin: .miter, miterLimit: 10)
            let period = 2.4 / style.speed
            let halos = [(opacity: 0.9, radius: { (w: Double) in 4 + 10 * k * w }),
                         (opacity: 0.5, radius: { (_: Double) in 2 })].map { halo -> CALayer in
                let l = CALayer()
                l.frame = bounds
                l.shadowPath = outline
                l.shadowColor = color
                l.shadowOffset = .zero
                l.shadowOpacity = Float(halo.opacity * k * 0.6)
                l.shadowRadius = halo.radius(0.6)
                if !still {
                    l.add(sampled("shadowOpacity", period: period) { Float(halo.opacity * k * wave($0, 2.4)) }, forKey: "o")
                    l.add(sampled("shadowRadius", period: period) { halo.radius(wave($0, 2.4)) }, forKey: "r")
                }
                return l
            }
            return halos + [border]

        case .wiggle, .bounce:
            return [] // they move the card itself; see StateLookModifier
        }
    }

    // MARK: Pieces

    private func shape(fill: CGColor) -> CAShapeLayer {
        let l = CAShapeLayer()
        l.frame = bounds
        l.path = path(bounds, 0)
        l.fillColor = fill
        return l
    }

    /// A border inside the shape's edge, like SwiftUI's `strokeBorder`.
    private func shape(stroke width: CGFloat, color: CGColor) -> CAShapeLayer {
        let l = CAShapeLayer()
        l.frame = bounds
        l.path = path(bounds, width / 2)
        l.lineWidth = width
        l.strokeColor = color
        l.fillColor = nil
        return l
    }

    private func gradient(_ colors: [CGColor], at locations: [Double]) -> CAGradientLayer {
        let g = CAGradientLayer()
        g.frame = bounds
        g.colors = colors
        g.locations = locations.map { NSNumber(value: $0) }
        g.startPoint = point(-1)
        g.endPoint = point(0)
        return g
    }

    /// A conic gradient turning once per `period` behind the card; mask it to a ring for a border.
    private func spinner(_ colors: [CGColor], at locations: [Double]?, period: Double, still angle: Double) -> CAGradientLayer {
        let g = CAGradientLayer()
        let side = hypot(bounds.width, bounds.height)
        g.bounds = CGRect(x: 0, y: 0, width: side, height: side)
        g.position = CGPoint(x: bounds.midX, y: bounds.midY)
        g.type = .conic
        g.startPoint = CGPoint(x: 0.5, y: 0.5)
        g.endPoint = CGPoint(x: 1, y: 0.5)
        g.colors = colors
        g.locations = locations?.map { NSNumber(value: $0) }
        if still {
            g.setAffineTransform(CGAffineTransform(rotationAngle: angle))
        } else {
            let spin = CABasicAnimation(keyPath: "transform.rotation.z")
            spin.fromValue = 0
            spin.toValue = 2 * Double.pi
            g.add(loop(spin, period: period), forKey: "spin")
        }
        return g
    }

    private func clipped(_ layers: [CALayer], to mask: CALayer) -> CALayer {
        let c = CALayer()
        c.frame = bounds
        c.mask = mask
        layers.forEach(c.addSublayer)
        return c
    }

    /// A point on the card's top-left to bottom-right diagonal, in unit space.
    private func value(_ p: Double) -> NSValue { NSValue(point: NSPoint(x: p, y: p)) }
    private func point(_ p: Double) -> CGPoint { CGPoint(x: p, y: p) }

    // MARK: Timing

    /// 0…1 sine, at this style's speed.
    private func wave(_ t: Double, _ period: Double) -> Double {
        0.5 + 0.5 * sin(2 * .pi * t * style.speed / period)
    }

    /// On, then off, never faster than `maxFlashHz` full cycles a second.
    private func blink(hz: Double, on: Float) -> CAKeyframeAnimation {
        let a = CAKeyframeAnimation(keyPath: "opacity")
        a.values = [on, 0]
        a.keyTimes = [0, 0.5, 1]
        a.calculationMode = .discrete
        return loop(a, period: 1 / min(maxFlashHz, hz * style.speed))
    }

    /// `value(t)` over one cycle, `t` in seconds, as keyframes Core Animation interpolates.
    private func sampled(_ keyPath: String, period: Double, steps: Int = 48, _ value: (Double) -> Any) -> CAKeyframeAnimation {
        let a = CAKeyframeAnimation(keyPath: keyPath)
        a.values = (0...steps).map { value(Double($0) / Double(steps) * period) }
        a.keyTimes = (0...steps).map { NSNumber(value: Double($0) / Double(steps)) }
        return loop(a, period: period)
    }

    /// Repeats forever, starting where the wall clock is in the cycle.
    private func loop<A: CAAnimation>(_ a: A, period: Double) -> A {
        a.duration = period
        a.repeatCount = .infinity
        a.isRemovedOnCompletion = false
        a.timeOffset = Date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        return a
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
