import AppKit
import SwiftUI

// Drawing for skins (Skin.swift). Nothing here animates except the blink and the cursor, and
// patterns are tiled images made once, so a skinned deck costs no more than glass.

extension View {
    /// A card's surface: tinted glass, or the look's opaque skin.
    @ViewBuilder
    func cardSurface<S: InsettableShape>(_ look: Look, style: StateStyle, paint: CardPaint, in shape: S,
                                         scale: CGFloat = 1, state: AgentState? = nil) -> some View {
        if let skin = look.skin, !paint.fills.isEmpty {
            modifier(SkinSurface(skin: skin, fills: paint.fills.map { Color(nsColor: $0) }, frame: Color(nsColor: paint.frame),
                                 glow: paint.glow, shape: shape, scale: scale, solid: paint.solid,
                                 scene: state.map { ($0, NSColor(hex: style.color) ?? .white, style.speed) }))
        } else {
            barnGlass(in: shape, tint: style.tint > 0 ? style.swiftColor.opacity(style.tint) : nil, interactive: true)
        }
    }

    /// Glass, or the skin's plain background, for chrome that isn't an agent (the deck's handle,
    /// the switcher's panels).
    @ViewBuilder
    func panelSurface<S: InsettableShape>(_ skin: Skin?, in shape: S, scale: CGFloat = 1) -> some View {
        if let skin {
            let glow = skin.glowColor.flatMap(NSColor.init(hex:)) ?? skin.textColor
            modifier(SkinSurface(skin: skin,
                                 fills: ([skin.background] + skin.gradient).compactMap(NSColor.init(hex:)).map { Color(nsColor: $0) },
                                 frame: Color(nsColor: skin.frameColor),
                                 glow: skin.glow > 0 ? Color(nsColor: glow).opacity(0.35 + 0.6 * skin.glow) : nil,
                                 shape: shape, scale: scale))
                .foregroundStyle(Color(nsColor: skin.textColor))
                .environment(\.colorScheme, skin.colorScheme)
        } else {
            barnGlass(in: shape)
        }
    }

    /// On a striped title bar, a gap in the stripes behind a label, like old Mac window titles.
    @ViewBuilder
    func barGap(_ bar: Skin.TitleBar?, _ paint: BarPaint?, scale: CGFloat) -> some View {
        if let bar, let paint, bar.stripes {
            padding(.horizontal, 3 * scale).background(Color(nsColor: paint.start))
        } else {
            self
        }
    }
}

private struct SkinSurface<S: InsettableShape>: ViewModifier {
    var skin: Skin
    var fills: [Color]
    var frame: Color
    var glow: Color?
    var shape: S
    var scale: CGFloat
    var solid = false
    /// The card's state, color and speed, for a backdrop to act out.
    var scene: (state: AgentState, accent: NSColor, speed: Double)?

    func body(content: Content) -> some View {
        content
            .shadow(color: glow ?? .clear, radius: glow == nil ? 0 : 1.5 + 2.5 * skin.glow)
            .background {
                ZStack {
                    if fills.count > 1 {
                        let (start, end) = skin.direction.points
                        shape.fill(LinearGradient(colors: fills, startPoint: start, endPoint: end))
                    } else {
                        shape.fill(fills.first ?? .black)
                    }
                    if skin.backdrop != .none, let scene {
                        BackdropView(kind: skin.backdrop, state: scene.state, accent: scene.accent, speed: scene.speed,
                                     clip: { shape.path(in: $0).cgPath })
                    }
                    if skin.pattern != .none {
                        PatternFill(skin: skin, scale: scale).clipShape(shape).opacity(solid ? 0.3 : 1)
                    }
                    if skin.scanlines > 0 {
                        Scanlines(strength: skin.scanlines, scale: scale).clipShape(shape)
                    }
                    if skin.gloss > 0 {
                        Gloss(amount: skin.gloss).clipShape(shape)
                    }
                }
            }
            .overlay { SkinBorder(border: skin.border, color: frame, shape: shape, scale: scale) }
            .background {
                if skin.shadow == .hard {
                    shape.fill(Color.black.opacity(0.75)).offset(x: Skin.shadowOffset * scale, y: Skin.shadowOffset * scale)
                }
            }
    }
}

private struct SkinBorder<S: InsettableShape>: View {
    var border: Skin.Border
    var color: Color
    var shape: S
    var scale: CGFloat

    var body: some View {
        let w = max(1, (1.25 * scale).rounded())
        switch border {
        case .none:
            EmptyView()
        case .line:
            shape.strokeBorder(color, lineWidth: w)
        case .thick:
            shape.strokeBorder(color, lineWidth: max(2, (3 * scale).rounded()))
        case .heavy:
            shape.strokeBorder(color, lineWidth: max(4, (6 * scale).rounded()))
        case .double:
            ZStack {
                shape.inset(by: 2.5 * scale).strokeBorder(color, lineWidth: w)
                shape.inset(by: 5.5 * scale).strokeBorder(color, lineWidth: w)
            }
        case .bevel:
            // An outline around a raised edge: lit top and left, shaded bottom and right. The
            // edges are straight, so the shape's corners are only rounded by its outline.
            let edge = max(2, (2 * scale).rounded())
            ZStack {
                VStack(spacing: 0) {
                    Color.white.opacity(0.9).frame(height: edge)
                    Spacer(minLength: 0)
                    Color.black.opacity(0.4).frame(height: edge)
                }
                HStack(spacing: 0) {
                    Color.white.opacity(0.9).frame(width: edge)
                    Spacer(minLength: 0)
                    Color.black.opacity(0.4).frame(width: edge)
                }
            }
            .padding(1)
            .clipShape(shape)
            .overlay(shape.strokeBorder(color, lineWidth: 1))
        }
    }
}

/// CRT scanlines: a dark line every few points.
private struct Scanlines: View {
    var strength: Double
    var scale: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let pitch = max(2, (3 * scale).rounded())
            var y: CGFloat = 0
            var path = Path()
            while y < size.height {
                path.addRect(CGRect(x: 0, y: y + pitch * 0.55, width: size.width, height: pitch * 0.45))
                y += pitch
            }
            ctx.fill(path, with: .color(.black.opacity(0.18 + 0.32 * strength)))
        }
        .allowsHitTesting(false)
    }
}

/// A glassy highlight: bright at the top, cut off sharply at the middle.
private struct Gloss: View {
    var amount: Double

    var body: some View {
        LinearGradient(stops: [.init(color: .white.opacity(0.75 * amount), location: 0),
                               .init(color: .white.opacity(0.3 * amount), location: 0.47),
                               .init(color: .clear, location: 0.5)],
                       startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
    }
}

// MARK: Patterns

private struct PatternFill: View {
    var skin: Skin
    var scale: CGFloat

    var body: some View {
        let tile = PatternTiles.tile(skin.pattern, colors: skin.patternPalette)
        ZStack(alignment: .leading) {
            Rectangle().fill(ImagePaint(image: Image(nsImage: tile)))
            if skin.pattern == .ruled {
                // The red margin.
                Rectangle().fill(Color(red: 0.93, green: 0.36, blue: 0.36)).frame(width: 1).padding(.leading, 7 * scale)
            }
        }
        .opacity(0.2 + 0.8 * skin.patternStrength)
        .allowsHitTesting(false)
    }
}

/// One tile per pattern and palette, drawn once and repeated by SwiftUI.
@MainActor
private enum PatternTiles {
    private static var cache: [String: NSImage] = [:]

    static func tile(_ pattern: Skin.Pattern, colors: [NSColor]) -> NSImage {
        let key = pattern.rawValue + colors.map(\.hex).joined()
        if let image = cache[key] { return image }
        let image = draw(pattern, colors: colors)
        cache[key] = image
        return image
    }

    /// The same specks every time, so cards don't shimmer as they redraw.
    private struct Seeded {
        var state: UInt64
        mutating func next() -> CGFloat {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return CGFloat(state >> 33) / CGFloat(1 << 31)
        }
    }

    private static func draw(_ pattern: Skin.Pattern, colors: [NSColor]) -> NSImage {
        let ink = colors[0]
        let size: CGFloat = switch pattern {
        case .none, .dither: 2
        case .pinstripes: 2
        case .grid: 3
        case .checker: 8
        case .ruled: 9
        case .stripes, .dots: 10
        case .grain: 32
        case .sparkles: 40
        case .bubbles: 44
        case .confetti: 48
        case .hatch: 6
        case .waves, .chevrons: 16
        case .plaid: 28
        case .stipple: 24
        case .hearts: 36
        case .gears: 48
        case .memphis: 64
        case .bauhaus: 72
        }
        return NSImage(size: NSSize(width: size, height: size), flipped: true) { _ in
            ink.setFill()
            ink.setStroke()
            var rng = Seeded(state: 42)
            switch pattern {
            case .none:
                break
            case .memphis, .bauhaus, .waves, .hatch, .stipple, .chevrons, .hearts, .gears, .plaid:
                PatternArt.draw(pattern, colors: colors, size: size)
            case .dither:
                NSRect(x: 0, y: 0, width: 1, height: 1).fill()
                NSRect(x: 1, y: 1, width: 1, height: 1).fill()
            case .checker:
                NSRect(x: 0, y: 0, width: 4, height: 4).fill()
                NSRect(x: 4, y: 4, width: 4, height: 4).fill()
            case .stripes:
                for k in [-size, 0, size] {
                    let p = NSBezierPath()
                    p.move(to: NSPoint(x: k, y: size))
                    p.line(to: NSPoint(x: k + size, y: 0))
                    p.lineWidth = 2.5
                    p.stroke()
                }
            case .pinstripes:
                NSRect(x: 0, y: 0, width: size, height: 1).fill()
            case .ruled:
                NSRect(x: 0, y: size - 0.75, width: size, height: 0.75).fill()
            case .grid:
                NSRect(x: size - 0.5, y: 0, width: 0.5, height: size).fill()
                NSRect(x: 0, y: size - 0.5, width: size, height: 0.5).fill()
            case .dots:
                NSBezierPath(ovalIn: NSRect(x: 3.5, y: 3.5, width: 3, height: 3)).fill()
            case .grain:
                for _ in 0..<110 {
                    ink.withAlphaComponent(0.25 + 0.75 * rng.next()).setFill()
                    let d = 0.5 + rng.next()
                    NSRect(x: rng.next() * size, y: rng.next() * size, width: d, height: d).fill()
                }
            case .bubbles:
                // Rings with a glint, of a few sizes.
                for _ in 0..<5 {
                    let r = 1.5 + rng.next() * 4
                    let c = NSPoint(x: r + 1 + rng.next() * (size - 2 * r - 2), y: r + 1 + rng.next() * (size - 2 * r - 2))
                    let ring = NSBezierPath(ovalIn: NSRect(x: c.x - r, y: c.y - r, width: 2 * r, height: 2 * r))
                    ink.withAlphaComponent(0.18).setFill()
                    ring.fill()
                    ink.withAlphaComponent(0.9).setStroke()
                    ring.lineWidth = 0.7
                    ring.stroke()
                    ink.setFill()
                    NSBezierPath(ovalIn: NSRect(x: c.x - r * 0.55, y: c.y - r * 0.6, width: r * 0.45, height: r * 0.35)).fill()
                }
            case .sparkles:
                for i in 0..<7 {
                    let x = 4 + rng.next() * (size - 8), y = 4 + rng.next() * (size - 8)
                    if i < 3 { star(at: NSPoint(x: x, y: y), radius: 2.5 + rng.next() * 2) } else {
                        NSBezierPath(ovalIn: NSRect(x: x, y: y, width: 1.2, height: 1.2)).fill()
                    }
                }
            case .confetti:
                for i in 0..<10 {
                    colors[i % colors.count].setFill()
                    colors[i % colors.count].setStroke()
                    let center = NSPoint(x: 5 + rng.next() * (size - 10), y: 5 + rng.next() * (size - 10))
                    let turn = NSAffineTransform()
                    turn.translateX(by: center.x, yBy: center.y)
                    turn.rotate(byDegrees: rng.next() * 180)
                    let shape: NSBezierPath
                    switch i % 4 {
                    case 0: shape = NSBezierPath(rect: NSRect(x: -2.5, y: -0.8, width: 5, height: 1.6))
                    case 1: shape = NSBezierPath(ovalIn: NSRect(x: -1.5, y: -1.5, width: 3, height: 3))
                    case 2:
                        shape = NSBezierPath()
                        shape.move(to: NSPoint(x: 0, y: -2))
                        shape.line(to: NSPoint(x: 2, y: 1.5))
                        shape.line(to: NSPoint(x: -2, y: 1.5))
                        shape.close()
                    default:
                        // A squiggle.
                        shape = NSBezierPath()
                        shape.move(to: NSPoint(x: -3, y: 0))
                        shape.curve(to: NSPoint(x: 0, y: 0), controlPoint1: NSPoint(x: -2, y: -2), controlPoint2: NSPoint(x: -1, y: -2))
                        shape.curve(to: NSPoint(x: 3, y: 0), controlPoint1: NSPoint(x: 1, y: 2), controlPoint2: NSPoint(x: 2, y: 2))
                        shape.lineWidth = 1
                        shape.transform(using: turn as AffineTransform)
                        shape.stroke()
                        continue
                    }
                    shape.transform(using: turn as AffineTransform)
                    shape.fill()
                }
            }
            return true
        }
    }

    /// A four-point twinkle.
    private static func star(at c: NSPoint, radius r: CGFloat) {
        let p = NSBezierPath()
        let waist = r * 0.22
        p.move(to: NSPoint(x: c.x, y: c.y - r))
        p.line(to: NSPoint(x: c.x + waist, y: c.y - waist))
        p.line(to: NSPoint(x: c.x + r, y: c.y))
        p.line(to: NSPoint(x: c.x + waist, y: c.y + waist))
        p.line(to: NSPoint(x: c.x, y: c.y + r))
        p.line(to: NSPoint(x: c.x - waist, y: c.y + waist))
        p.line(to: NSPoint(x: c.x - r, y: c.y))
        p.line(to: NSPoint(x: c.x - waist, y: c.y - waist))
        p.close()
        p.fill()
    }
}

// MARK: Title bars

/// A window title bar across the top of a card or panel, with its buttons.
struct SkinTitleBar<Title: View>: View {
    var bar: Skin.TitleBar
    var paint: BarPaint
    var scale: CGFloat
    /// The card's corner radius, for the bar's top corners.
    var corner: CGFloat
    @ViewBuilder var title: Title

    var body: some View {
        let h = (bar.height * scale).rounded()
        let button = max(6, h - 5 * scale)
        HStack(spacing: 4 * scale) {
            if bar.buttons == .mac || bar.buttons == .aqua {
                BarButtons(kind: bar.buttons, size: button, paint: paint)
                    .barGap(bar, paint, scale: scale)
            }
            title
            if bar.buttons == .win || bar.buttons == .xp {
                BarButtons(kind: bar.buttons, size: button, paint: paint)
            }
        }
        .padding(.horizontal, 4 * scale)
        .frame(maxWidth: .infinity)
        .frame(height: h)
        .foregroundStyle(Color(nsColor: paint.text))
        .background {
            ZStack {
                let (start, end) = bar.direction.points
                LinearGradient(colors: [Color(nsColor: paint.start), Color(nsColor: paint.end)], startPoint: start, endPoint: end)
                if bar.stripes {
                    BarStripes(color: Color(nsColor: paint.text).opacity(0.5), scale: scale)
                        .padding(.vertical, 3 * scale)
                }
                if bar.gloss > 0 { Gloss(amount: bar.gloss) }
            }
        }
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: corner, topTrailingRadius: corner))
    }
}

/// A list row's stand-in for a title bar: a strip down its leading edge.
struct BarStrip: View {
    var bar: Skin.TitleBar
    var paint: BarPaint
    var scale: CGFloat
    var corner: CGFloat

    var body: some View {
        LinearGradient(colors: [Color(nsColor: paint.start), Color(nsColor: paint.end)], startPoint: .top, endPoint: .bottom)
            .overlay { if bar.gloss > 0 { Gloss(amount: bar.gloss) } }
            .frame(width: (5 * scale).rounded())
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: corner, bottomLeadingRadius: corner))
    }
}

private struct BarStripes: View {
    var color: Color
    var scale: CGFloat

    var body: some View {
        Canvas { ctx, size in
            let pitch = max(2, (2 * scale).rounded())
            var path = Path()
            var y: CGFloat = 0
            while y < size.height {
                path.addRect(CGRect(x: 0, y: y, width: size.width, height: pitch / 2))
                y += pitch
            }
            ctx.fill(path, with: .color(color))
        }
    }
}

private struct BarButtons: View {
    var kind: Skin.TitleBar.Buttons
    var size: CGFloat
    var paint: BarPaint

    var body: some View {
        switch kind {
        case .none:
            EmptyView()
        case .win:
            ZStack {
                Rectangle().fill(Color(white: 0.75))
                Rectangle().strokeBorder(
                    LinearGradient(stops: [.init(color: .white, location: 0.5), .init(color: .black.opacity(0.6), location: 0.5)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1)
                XMark().stroke(Color.black, lineWidth: max(1, size / 8)).padding(size * 0.28)
            }
            .frame(width: size + 2, height: size)
        case .xp:
            let shape = RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
            ZStack {
                shape.fill(LinearGradient(colors: [Color(red: 0.93, green: 0.55, blue: 0.45), Color(red: 0.77, green: 0.2, blue: 0.1)],
                                          startPoint: .top, endPoint: .bottom))
                shape.strokeBorder(Color.white.opacity(0.9), lineWidth: 1)
                XMark().stroke(Color.white, style: StrokeStyle(lineWidth: max(1.2, size / 7), lineCap: .round)).padding(size * 0.3)
            }
            .frame(width: size, height: size)
        case .mac:
            Rectangle().fill(Color(nsColor: paint.start))
                .overlay(Rectangle().strokeBorder(Color(nsColor: paint.text), lineWidth: 1))
                .frame(width: size * 0.85, height: size * 0.85)
        case .aqua:
            HStack(spacing: size * 0.22) {
                ForEach(["#FF5F57", "#FEBC2E", "#28C840"], id: \.self) { hex in
                    Circle().fill(Color(nsColor: NSColor(hex: hex)!))
                        .overlay(Gloss(amount: 0.8).clipShape(Circle()))
                        .overlay(Circle().strokeBorder(Color.black.opacity(0.25), lineWidth: 0.5))
                        .frame(width: size * 0.7, height: size * 0.7)
                }
            }
        }
    }
}

private struct XMark: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        return p
    }
}

// MARK: Blink and cursor

/// The blink effect's beat: the card swaps between its paint and a solid block of its state
/// color, like Apple II FLASH text (or its title bar flashes, like a window asking for
/// attention). Two redraws a second at most (never faster than 3 Hz). With Reduce Motion it
/// holds the off beat.
struct BlinkGate<Content: View>: View {
    var style: StateStyle
    @ViewBuilder var content: (_ inverted: Bool) -> Content
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if !style.effects.contains(.blink) {
            content(false)
        } else if reduceMotion {
            content(true)
        } else {
            let half = max(1 / 6, 0.6 / style.speed)
            TimelineView(.periodic(from: Date(timeIntervalSinceReferenceDate: 0), by: half)) { ctx in
                content(Int(ctx.date.timeIntervalSinceReferenceDate / half) % 2 == 1)
            }
        }
    }
}

/// A blinking block cursor, played by Core Animation so it costs nothing between blinks.
struct BlockCursor: NSViewRepresentable {
    var color: NSColor
    var speed: Double = 1

    func makeNSView(context: Context) -> CursorView { CursorView() }
    func updateNSView(_ view: CursorView, context: Context) { view.set(color: color, period: 1.06 / speed) }
}

final class CursorView: NSView {
    private var color: NSColor?
    private var period: Double = 1

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func set(color: NSColor, period: Double) {
        guard color != self.color || period != self.period else { return }
        self.color = color
        self.period = max(1 / 3, period)
        restart()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        restart()
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        restart()
    }

    private func restart() {
        guard let layer, let color else { return }
        effectiveAppearance.performAsCurrentDrawingAppearance { layer.backgroundColor = color.cgColor }
        layer.removeAnimation(forKey: "blink")
        guard window != nil, !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion else { return }
        let a = CAKeyframeAnimation(keyPath: "opacity")
        a.values = [1, 0]
        a.keyTimes = [0, 0.5, 1]
        a.calculationMode = .discrete
        a.duration = period
        a.repeatCount = .infinity
        a.isRemovedOnCompletion = false
        a.timeOffset = Date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: period)
        layer.add(a, forKey: "blink")
    }
}
