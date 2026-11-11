import AppKit
import QuartzCore
import SwiftUI

/// How the floating deck is laid out. Personal preferences, not part of a shared look: pasting
/// someone's look recolors your deck but never resizes or re-lays it out.
enum DeckLayout: String, CaseIterable, Codable {
    case tiles, list
}

enum DeckSize: String, CaseIterable, Codable {
    case xs, s, m, l, xl

    var scale: CGFloat {
        switch self {
        case .xs: 0.72
        case .s: 0.86
        case .m: 1
        case .l: 1.2
        case .xl: 1.45
        }
    }
}

enum DeckFont: String, CaseIterable, Codable {
    case system, rounded, mono, serif
    /// Any installed font family, in `Settings.deckFontFamily`.
    case custom

    var design: Font.Design {
        switch self {
        case .system, .custom: .default
        case .rounded: .rounded
        case .mono: .monospaced
        case .serif: .serif
        }
    }
}

/// Sizes for one deck size and font, so tiles and rows scale together.
struct DeckMetrics {
    var scale: CGFloat
    var design: Font.Design
    /// An installed font family; nil uses the system font in `design`.
    var family: String?
    /// The look's skin, which sets its own font and corners.
    var skin: Skin? = nil

    /// Pins the card size regardless of the setting (showcase recordings).
    @MainActor static var sizeOverride: DeckSize?

    @MainActor static var current: DeckMetrics {
        let settings = Settings.shared
        let family = settings.deckFont == .custom && NSFontManager.shared.availableMembers(ofFontFamily: settings.deckFontFamily) != nil
            ? settings.deckFontFamily : nil
        return DeckMetrics(scale: (sizeOverride ?? settings.deckSize).scale, design: settings.deckFont.design, family: family)
    }

    /// The same sizes in a skin's font and corners.
    @MainActor func skinned(_ skin: Skin?) -> DeckMetrics {
        guard let skin else { return self }
        var m = self
        m.skin = skin
        m.family = skin.family
        m.design = skin.fallback.design
        return m
    }

    var tileSize: CGFloat { (86 * scale).rounded() }
    var tileRadius: CGFloat { CGFloat(skin?.corner ?? 20) * scale }
    var spacing: CGFloat { (8 * scale).rounded() }
    var rowWidth: CGFloat { (250 * scale).rounded() }
    var rowHeight: CGFloat { (34 * scale).rounded() }
    var rowRadius: CGFloat { CGFloat(min(skin?.corner ?? 12, 12)) * scale }
    /// Room inside a card for the skin's frame.
    var inset: CGFloat {
        switch skin?.border {
        case .double: 3 * scale
        case .thick, .bevel: 1.5 * scale
        case .heavy: 4 * scale
        default: 0
        }
    }

    @MainActor func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if let skin { return skin.font(size * scale, weight) }
        if let family { return .custom(family, size: size * scale).weight(weight) }
        return .system(size: size * scale, weight: weight, design: design)
    }

    /// Small print (badges, times): rounded system text on glass, the deck font on a skin.
    @MainActor func small(_ size: CGFloat, _ weight: Font.Weight) -> Font {
        skin == nil ? .system(size: size * scale, weight: weight, design: .rounded) : font(size, weight)
    }

    func cased(_ s: String) -> String { skin?.cased(s) ?? s }
}

/// One agent as a compact list row: dot, name, what it's doing (scrolling when it doesn't fit), time.
struct DeckRow: View {
    var agent: Agent
    var look: Look?
    @ObservedObject private var settings = Settings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let look = look ?? settings.activeLook
        let style = look.style(for: agent.state)
        BlinkGate(style: style) { inverted in row(look, style: style, inverted: inverted) }
            .overlay { if settings.confetti { ConfettiOverlay(state: agent.state).allowsHitTesting(false) } }
    }

    private func row(_ look: Look, style: StateStyle, inverted: Bool) -> some View {
        let m = DeckMetrics.current.skinned(look.skin)
        let shape = RoundedRectangle(cornerRadius: m.rowRadius, style: .continuous)
        let dark = colorScheme == .dark
        let paint = look.paint(for: agent.state, dark: dark, inverted: inverted)
        let bar = look.skin?.titleBar
        let barPaint = look.barPaint(for: agent.state, dark: dark, inverted: inverted)
        return HStack(spacing: 7 * m.scale) {
            if let skin = look.skin, skin.mascot != .none {
                MascotView(kind: skin.mascot, state: agent.state,
                           accent: style.resolved(dark: dark), ink: skin.textColor, speed: style.speed)
                    .frame(width: m.rowHeight * 0.9, height: m.rowHeight * 0.75)
            } else {
                StateDot(state: agent.state, size: 7 * m.scale, look: look, inverted: inverted)
            }
            // Golden-ratio steps spread the rows' scroll times evenly whatever the pids are.
            Marquee(phase: (Double(agent.pid) * 0.618).truncatingRemainder(dividingBy: 1)) {
                HStack(spacing: 6 * m.scale) {
                    Text(m.cased(agent.displayTitle)).font(m.font(12, .semibold)).foregroundStyle(paint.primary)
                    Text(m.cased(detail)).font(m.font(11, .medium)).foregroundStyle(paint.detail)
                }
            }
            if style.effects.contains(.cursor) {
                BlockCursor(color: paint.cursor, speed: style.speed)
                    .frame(width: 6 * m.scale, height: 11 * m.scale)
            }
            TimelineView(.everyMinute) { ctx in
                Text(m.cased(ctx.date.timeIntervalSince(agent.stateSince).coarse))
                    .font(m.font(10, .medium))
                    .monospacedDigit()
                    .foregroundStyle(paint.secondary)
            }
        }
        .padding(.leading, bar == nil ? 0 : 5 * m.scale)
        .padding(.horizontal, 11 * m.scale + m.inset)
        .frame(width: m.rowWidth, height: m.rowHeight)
        .overlay(alignment: .leading) {
            // Too short for a title bar, a row shows its color as a strip down the side.
            if let bar, let barPaint {
                BarStrip(bar: bar, paint: barPaint, scale: m.scale, corner: max(0, m.rowRadius - m.inset))
                    .padding(m.inset)
            }
        }
        .contentShape(shape)
        .cardSurface(look, style: style.inverted(inverted), paint: paint, in: shape, scale: m.scale, state: agent.state)
        .stateLook(style, in: shape, sideways: true)
    }

    private var detail: String {
        switch agent.state {
        case .waiting: agent.detail?.isEmpty == false ? agent.detail! : "needs you"
        case .working: agent.detail?.isEmpty == false ? agent.detail! : "working"
        case .ready: "ready"
        case .idle: agent.title != nil ? agent.project : "idle"
        }
    }
}

/// Content that fits sits still. Content that overflows waits a few seconds, then glides left
/// like a news ticker until it comes back around, and waits again. Edges fade while it's cut
/// off. With Reduce Motion it just truncates; the row's tooltip has the full text either way.
/// The scrolling copy is a picture of the content that Core Animation slides, so a ticking row
/// costs nothing between redraws.
struct Marquee<Content: View>: View {
    @ViewBuilder var content: Content
    var pause: Double = 3
    /// Points per second.
    var speed: Double = 32
    var gap: CGFloat = 28
    /// Shifts this marquee's schedule so a list of them doesn't scroll in lockstep.
    var phase: Double = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.displayScale) private var displayScale
    @Environment(\.colorScheme) private var colorScheme
    @State private var contentWidth: CGFloat = 0
    @State private var boxWidth: CGFloat = 0

    init(phase: Double = 0, @ViewBuilder content: () -> Content) {
        self.phase = phase
        self.content = content()
    }

    /// Overflowing by a few points isn't worth a ticker (or an ellipsis): those just clip.
    private var overflows: Bool { boxWidth > 0 && contentWidth > boxWidth + 6 }

    var body: some View {
        // A hidden, truncated copy sets the height and takes whatever width the row offers.
        content.lineLimit(1).hidden()
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .leading) {
                if overflows && !reduceMotion, let strip {
                    MarqueeStrip(image: strip, distance: contentWidth + gap, pause: pause, speed: speed, phase: phase)
                } else if overflows {
                    content.lineLimit(1).truncationMode(.tail) // Reduce Motion
                } else {
                    content.fixedSize()
                }
            }
            .onGeometryChange(for: CGFloat.self, of: \.size.width) { boxWidth = $0 }
            .background(alignment: .leading) {
                content.fixedSize().hidden()
                    .onGeometryChange(for: CGFloat.self, of: \.size.width) { contentWidth = $0 }
            }
            .clipped()
    }

    /// Two copies of the content, a gap apart, as one image.
    private var strip: NSImage? {
        let renderer = ImageRenderer(content: HStack(spacing: gap) { content.fixedSize(); content.fixedSize() }
            .environment(\.colorScheme, colorScheme))
        renderer.scale = displayScale
        return renderer.nsImage
    }
}

/// Slides a marquee's image left by `distance` after each pause, forever, with faded edges.
private struct MarqueeStrip: NSViewRepresentable {
    var image: NSImage
    var distance: CGFloat
    var pause: Double
    var speed: Double
    var phase: Double

    func makeNSView(context: Context) -> MarqueeView { MarqueeView() }
    func updateNSView(_ view: MarqueeView, context: Context) {
        view.set(image: image, timing: .init(distance: distance, pause: pause, speed: speed, phase: phase))
    }
}

final class MarqueeView: NSView {
    struct Timing: Equatable {
        var distance: CGFloat
        var pause: Double
        var speed: Double
        var phase: Double
    }

    private let strip = CALayer()
    private let fade = CAGradientLayer()
    private var timing: Timing?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        strip.anchorPoint = CGPoint(x: 0, y: 0.5)
        layer?.addSublayer(strip)
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        fade.colors = [NSColor.clear, .black, .black, .clear].map(\.cgColor)
        fade.locations = [0, 0.04, 0.9, 1]
        layer?.mask = fade
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func set(image: NSImage, timing: Timing) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        strip.contents = image
        strip.bounds = CGRect(origin: .zero, size: image.size)
        layoutStrip()
        CATransaction.commit()
        if timing != self.timing {
            self.timing = timing
            animate()
        }
    }

    override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.frame = bounds
        layoutStrip()
        CATransaction.commit()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        animate()
    }

    private func layoutStrip() {
        strip.position = CGPoint(x: 0, y: bounds.midY)
    }

    private func animate() {
        strip.removeAnimation(forKey: "scroll")
        guard let timing, window != nil, timing.distance > 0 else { return }
        let cycle = timing.pause + Double(timing.distance) / timing.speed
        let a = CAKeyframeAnimation(keyPath: "position.x")
        a.values = [0, 0, -timing.distance]
        a.keyTimes = [0, NSNumber(value: timing.pause / cycle), 1]
        a.duration = cycle
        a.repeatCount = .infinity
        a.isRemovedOnCompletion = false
        a.timeOffset = (Date.timeIntervalSinceReferenceDate + timing.phase * cycle).truncatingRemainder(dividingBy: cycle)
        strip.add(a, forKey: "scroll")
    }
}

/// The deck's agents in the chosen layout. Shared by the deck and the looks preview.
struct DeckItems<Item: View>: View {
    var agents: [Agent]
    var look: Look? = nil
    var columns: Int
    @ViewBuilder var decorate: (Agent, AnyView) -> Item
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        let skin = (look ?? settings.activeLook).skin
        let m = DeckMetrics.current
        // Room for drop shadows between cards.
        let shadow = skin?.shadow == .hard ? Skin.shadowOffset * m.scale : 0
        switch settings.deckLayout {
        case .tiles:
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(m.tileSize), spacing: m.spacing + shadow),
                                     count: max(1, min(columns, agents.count))),
                      spacing: m.spacing + shadow) {
                ForEach(agents) { agent in decorate(agent, AnyView(DeckTile(agent: agent, look: look))) }
            }
        case .list:
            VStack(spacing: m.spacing * 0.75 + shadow) {
                ForEach(agents) { agent in decorate(agent, AnyView(DeckRow(agent: agent, look: look))) }
            }
        }
    }
}
