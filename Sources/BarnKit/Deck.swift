import AppKit
import Combine
import SwiftUI

/// Always-on-top floating "Stream Deck": one tile per agent, click to jump.
@MainActor
final class DeckController {
    private let store: AgentStore
    private let onSettings: () -> Void
    private var panel: NSPanel?
    private var host: NSHostingController<DeckView>?
    private var sizing: AnyCancellable?
    private static let visibleKey = "deckVisible"

    init(store: AgentStore, onSettings: @escaping () -> Void) {
        self.store = store
        self.onSettings = onSettings
        if UserDefaults.standard.bool(forKey: Self.visibleKey) { show() }
    }

    var isVisible: Bool { panel?.isVisible ?? false }
    var frame: NSRect? { panel?.frame }

    func toggle() { isVisible ? hide() : show() }

    func show() {
        let panel = self.panel ?? makePanel()
        self.panel = panel
        panel.orderFrontRegardless()
        UserDefaults.standard.set(true, forKey: Self.visibleKey)
    }

    func hide() {
        panel?.orderOut(nil)
        UserDefaults.standard.set(false, forKey: Self.visibleKey)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(contentRect: NSRect(x: 0, y: 0, width: 300, height: 100),
                            styleMask: [.borderless, .nonactivatingPanel, .utilityWindow], backing: .buffered, defer: true)
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false // the glass draws its own
        panel.hidesOnDeactivate = false
        panel.isMovableByWindowBackground = true

        let host = NSHostingController(rootView: DeckView(
            store: store,
            onOpen: { [weak self] agent in
                self?.store.acknowledge(agent)
                Focus.open(agent)
            },
            onSettings: { [weak self] in self?.onSettings() },
            onHide: { [weak self] in self?.hide() }))
        host.sizingOptions = [] // sized manually in fit()
        panel.contentViewController = host
        self.host = host
        if CommandLine.arguments.contains("--demo") {
            // Screenshot layout: right of the centered switcher; don't touch the saved position.
            fit(panel, host: host, initial: true)
            if let screen = NSScreen.main?.visibleFrame {
                panel.setFrameOrigin(NSPoint(x: screen.midX + 370, y: screen.minY + screen.height * 0.74 - panel.frame.height))
            }
        } else {
            fit(panel, host: host, initial: !panel.setFrameUsingName("BarnDeck"))
            panel.setFrameAutosaveName("BarnDeck")
        }
        // Resize with the agent count, keeping the top-left corner where the user put it.
        let settings = Settings.shared
        let layoutChanged = Publishers.MergeMany([
            settings.$deckColumns.map { _ in () }.eraseToAnyPublisher(),
            settings.$deckLayout.map { _ in () }.eraseToAnyPublisher(),
            settings.$deckSize.map { _ in () }.eraseToAnyPublisher(),
            settings.$deckFont.map { _ in () }.eraseToAnyPublisher(),
            settings.$deckFontFamily.map { _ in () }.eraseToAnyPublisher(),
        ])
        sizing = store.$agents
            .map(\.count)
            .removeDuplicates()
            .map { _ in () }
            .merge(with: layoutChanged)
            .receive(on: RunLoop.main)
            .sink { [weak self, weak panel] _ in
                DispatchQueue.main.async {
                    guard let self, let panel, let host = self.host else { return }
                    self.fit(panel, host: host, initial: false)
                }
            }
        return panel
    }

    private func fit(_ panel: NSPanel, host: NSHostingController<DeckView>, initial: Bool) {
        let size = host.sizeThatFits(in: CGSize(width: 4000, height: 4000))
        guard size.width > 0, size.height > 0 else { return }
        var frame = panel.frame
        if initial, let screen = NSScreen.main?.visibleFrame {
            frame.origin = NSPoint(x: screen.maxX - size.width - 4, y: screen.maxY - size.height)
        } else {
            frame.origin.y += frame.height - size.height
        }
        frame.size = size
        if let screen = (panel.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.origin.x, screen.minX), screen.maxX - size.width)
            frame.origin.y = min(max(frame.origin.y, screen.minY), screen.maxY - size.height)
        }
        panel.setFrame(frame, display: true)
    }
}

struct DeckView: View {
    @ObservedObject var store: AgentStore
    var onOpen: (Agent) -> Void
    var onSettings: () -> Void
    var onHide: () -> Void
    @ObservedObject private var settings = Settings.shared
    @State private var hovering = false

    var body: some View {
        let perRow = CommandLine.arguments.contains("--demo") ? 3 : settings.deckColumns
        GlassGroup(spacing: 8) {
            VStack(spacing: 6) {
                DragHandle()
                    .opacity(hovering ? 1 : 0.55)
                if store.agents.isEmpty {
                    if let skin = settings.activeLook.skin {
                        Text(skin.cased("no agents"))
                            .font(skin.font(12, .medium))
                            .padding(.horizontal, 18)
                            .frame(height: 38)
                            .panelSurface(skin, in: RoundedRectangle(cornerRadius: skin.corner))
                    } else {
                        Text("no agents")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 18)
                            .frame(height: 38)
                            .barnGlass(in: Capsule())
                    }
                } else {
                    DeckItems(agents: store.agents, columns: perRow) { agent, item in
                        item
                            .onTapGesture { onOpen(agent) }
                            .help("\(agent.displayTitle)\n\(agent.cwd)\n\(statusLine(agent))")
                            .contextMenu {
                                Button("jump to \(agent.displayTitle)") { onOpen(agent) }
                                Divider()
                                deckMenu
                            }
                    }
                }
            }
        }
        .contextMenu { deckMenu }
        .padding(16) // room for the glass shadow
        .opacity(hovering ? 1 : settings.deckOpacity)
        .onHover { hovering = $0 }
        .animation(.easeOut(duration: 0.2), value: hovering)
        .fixedSize()
    }
}

extension DeckView {
    /// Right-click menu, so settings are reachable without the menu bar icon.
    @ViewBuilder var deckMenu: some View {
        Menu("look") {
            let all = settings.allLooks
            ForEach(Array(all.enumerated()), id: \.element.id) { i, item in
                if i > 0 && Look.group(of: all[i - 1].id) != Look.group(of: item.id) { Divider() }
                Toggle(item.look.name, isOn: Binding(get: { settings.activeLookID == item.id },
                                                     set: { if $0 { settings.activeLookID = item.id } }))
            }
        }
        Button("settings…", action: onSettings)
        Button("hide deck", action: onHide)
        Divider()
        Button("quit barn") { NSApp.terminate(nil) }
    }
}

/// Grab bar for moving the borderless deck (transparent pixels don't receive clicks).
struct DragHandle: View {
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        Group {
            if let skin = settings.activeLook.skin {
                // A row of character-cell blocks.
                HStack(spacing: 2) {
                    ForEach(0..<5, id: \.self) { _ in
                        Rectangle().fill(Color(nsColor: skin.dimColor)).frame(width: 4, height: 4)
                    }
                }
                .frame(width: 64, height: 16)
                .panelSurface(skin, in: RoundedRectangle(cornerRadius: min(skin.corner, 4)))
            } else {
                Capsule()
                    .fill(.secondary.opacity(0.7))
                    .frame(width: 30, height: 4)
                    .frame(width: 64, height: 16)
                    .barnGlass(in: Capsule())
            }
        }
        .overlay(WindowDragArea())
        .help("drag to move")
    }
}

struct DeckTile: View {
    var agent: Agent
    /// Overrides the active look (the looks editor's preview).
    var look: Look?
    @ObservedObject private var settings = Settings.shared
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let look = look ?? settings.activeLook
        let style = look.style(for: agent.state)
        BlinkGate(style: style) { inverted in tile(look, style: style, inverted: inverted) }
            .overlay { if settings.confetti { ConfettiOverlay(state: agent.state).allowsHitTesting(false) } }
    }

    private func tile(_ look: Look, style: StateStyle, inverted: Bool) -> some View {
        let m = DeckMetrics.current.skinned(look.skin)
        let shape = RoundedRectangle(cornerRadius: m.tileRadius, style: .continuous)
        let dark = colorScheme == .dark
        let paint = look.paint(for: agent.state, dark: dark, inverted: inverted)
        let bar = look.skin?.titleBar
        let barPaint = look.barPaint(for: agent.state, dark: dark, inverted: inverted)
        return Group {
            if let skin = look.skin, skin.mascot != .none {
                // The character acts out the state above the name; the time sits in the corner.
                VStack(alignment: .leading, spacing: 1 * m.scale) {
                    MascotView(kind: skin.mascot, state: agent.state,
                               accent: style.resolved(dark: dark), ink: skin.textColor, speed: style.speed)
                        .frame(maxWidth: .infinity)
                        .frame(height: 42 * m.scale)
                        .overlay(alignment: .topTrailing) {
                            TimelineView(.everyMinute) { ctx in
                                Text(m.cased(ctx.date.timeIntervalSince(agent.stateSince).coarse))
                                    .font(m.small(8.5, .medium))
                                    .monospacedDigit()
                                    .foregroundStyle(paint.secondary)
                            }
                        }
                    tileBody(style, m: m, paint: paint, lines: 1)
                }
                .padding(.horizontal, 8 * m.scale + m.inset)
                .padding(.vertical, 6 * m.scale + m.inset)
            } else if let bar, let barPaint {
                // A little window: the header rides in the title bar, which shows the state when it
                // follows it (so the dot steps aside).
                VStack(spacing: 0) {
                    SkinTitleBar(bar: bar, paint: barPaint, scale: m.scale, corner: max(0, m.tileRadius - m.inset)) {
                        header(look, m: m, paint: paint, inverted: inverted, dot: !bar.followsState,
                               bar: bar, barPaint: barPaint)
                    }
                    .padding([.top, .horizontal], m.inset)
                    tileBody(style, m: m, paint: paint)
                        .padding(.horizontal, 8 * m.scale + m.inset)
                        .padding(.top, 3 * m.scale)
                        .padding(.bottom, 7 * m.scale + m.inset)
                }
            } else {
                VStack(alignment: .leading, spacing: 2 * m.scale) {
                    header(look, m: m, paint: paint, inverted: inverted, dot: true, bar: nil, barPaint: nil)
                    tileBody(style, m: m, paint: paint)
                }
                .padding(10 * m.scale + m.inset)
            }
        }
        .frame(width: m.tileSize, height: m.tileSize)
        .contentShape(shape)
        .cardSurface(look, style: style.inverted(inverted), paint: paint, in: shape, scale: m.scale, state: agent.state)
        .stateLook(style, in: shape)
    }

    /// The dot, the agent's badge and how long it's been in this state.
    private func header(_ look: Look, m: DeckMetrics, paint: CardPaint, inverted: Bool, dot: Bool,
                        bar: Skin.TitleBar?, barPaint: BarPaint?) -> some View {
        let ink: AnyShapeStyle = barPaint.map { AnyShapeStyle(Color(nsColor: $0.text)) } ?? paint.secondary
        return HStack(spacing: 5 * m.scale) {
            if dot { StateDot(state: agent.state, size: 7 * m.scale, look: look, inverted: inverted) }
            Text(m.cased(agent.kind.badge))
                .font(m.small(9, .bold))
                .foregroundStyle(ink)
                .fixedSize()
                .barGap(bar, barPaint, scale: m.scale)
            Spacer(minLength: 0)
            TimelineView(.everyMinute) { ctx in
                Text(m.cased(ctx.date.timeIntervalSince(agent.stateSince).coarse))
                    .font(m.small(9, .medium))
                    .monospacedDigit()
                    .foregroundStyle(ink)
                    .fixedSize()
                    .barGap(bar, barPaint, scale: m.scale)
            }
        }
    }

    /// The project and what it's doing, at the bottom of the tile.
    private func tileBody(_ style: StateStyle, m: DeckMetrics, paint: CardPaint, lines: Int = 2) -> some View {
        VStack(alignment: .leading, spacing: 2 * m.scale) {
            Spacer(minLength: 0)
            Text(m.cased(agent.project))
                .font(m.font(12.5, .semibold))
                .foregroundStyle(paint.primary)
                .lineLimit(lines)
                .minimumScaleFactor(0.7)
            HStack(spacing: 2 * m.scale) {
                Text(m.cased(tileDetail))
                    .font(m.font(9.5, .medium))
                    .foregroundStyle(paint.detail)
                    .lineLimit(1)
                if style.effects.contains(.cursor) {
                    BlockCursor(color: paint.cursor, speed: style.speed)
                        .frame(width: 5 * m.scale, height: 9 * m.scale)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var tileDetail: String {
        let base = tileState
        return agent.collapsed > 0 ? "\(base) · +\(agent.collapsed)" : base
    }

    private var tileState: String {
        switch agent.state {
        case .waiting: agent.detail?.split(separator: "·").first.map { $0.trimmingCharacters(in: .whitespaces) } ?? "needs you"
        case .working: agent.detail.map { String($0.split(separator: ":").first ?? "") } ?? "working"
        case .ready: "ready"
        case .idle: "idle"
        }
    }
}
