import AppKit
import QuartzCore
import SwiftUI

/// Status dot in the look's color; pulses while the agent needs you, unless the look is still.
struct StateDot: View {
    var state: AgentState
    var size: CGFloat = 10
    var look: Look?
    @ObservedObject private var settings = Settings.shared
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let style = (look ?? settings.activeLook).style(for: state)
        // On a solid card the dot would be the card's own color, so it takes the text's instead.
        let color = style.isSolid ? NSColor(style.contrast(dark: colorScheme == .dark)) : style.nsColor
        DotLayer(color: color, glows: state != .idle,
                 pulse: state == .waiting && !style.effects.isEmpty && !reduceMotion ? 1.4 / style.speed : nil)
            .frame(width: size, height: size)
    }
}

/// The dot as a Core Animation layer, so its pulse plays in the window server rather than
/// re-rendering the deck every frame.
private struct DotLayer: NSViewRepresentable {
    var color: NSColor
    var glows: Bool
    /// Seconds per fade out and back, or nil to hold still.
    var pulse: Double?

    func makeNSView(context: Context) -> DotView { DotView() }
    func updateNSView(_ view: DotView, context: Context) {
        view.set(color: color, glows: glows, pulse: pulse)
    }
}

final class DotView: NSView {
    private let fill = CAGradientLayer()
    private let disc = CAShapeLayer()
    private var color: NSColor = .gray
    private var glows = false
    private var pulse: Double?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
        fill.mask = disc
        layer?.addSublayer(fill)
        layer?.shadowOffset = .zero
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func set(color: NSColor, glows: Bool, pulse: Double?) {
        let changed = color != self.color || glows != self.glows || pulse != self.pulse
        self.color = color
        self.glows = glows
        self.pulse = pulse
        if changed { redraw(restartPulse: true) }
    }

    override func layout() {
        super.layout()
        redraw(restartPulse: false)
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        redraw(restartPulse: false)
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        redraw(restartPulse: true)
    }

    private func redraw(restartPulse: Bool) {
        guard let root = layer else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fill.frame = bounds
        disc.frame = bounds
        disc.path = CGPath(ellipseIn: bounds, transform: nil)
        effectiveAppearance.performAsCurrentDrawingAppearance {
            // Like SwiftUI's `color.gradient`: a touch lighter at the top.
            let top = color.blended(withFraction: 0.18, of: .white) ?? color
            fill.colors = [top.cgColor, color.cgColor]
            root.shadowColor = color.cgColor
        }
        root.shadowOpacity = glows ? 0.7 : 0
        root.shadowRadius = bounds.width * 0.35
        if restartPulse {
            root.removeAnimation(forKey: "pulse")
            if let pulse, window != nil {
                let a = CABasicAnimation(keyPath: "opacity")
                a.fromValue = 1
                a.toValue = 0.35
                a.duration = pulse / 2
                a.autoreverses = true
                a.repeatCount = .infinity
                a.isRemovedOnCompletion = false
                a.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                root.add(a, forKey: "pulse")
            }
        }
        CATransaction.commit()
    }
}

struct AppIcon: View {
    var host: HostApp?
    var size: CGFloat = 20

    var body: some View {
        if let id = host?.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "terminal")
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }
}

/// "Needs you · 3m" / "Bash: npm test" style subtitle shared by the switcher and menu.
func statusLine(_ agent: Agent, now: Date = Date()) -> String {
    var parts = [agent.state.label]
    if let detail = agent.detail, !detail.isEmpty, agent.state != .idle { parts.append(detail) }
    parts.append(now.timeIntervalSince(agent.stateSince).compact)
    if agent.collapsed > 0 { parts.append("+\(agent.collapsed) more") }
    return parts.joined(separator: " · ")
}

/// Lets a SwiftUI region drag its borderless window.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
