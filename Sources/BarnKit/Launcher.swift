import AppKit
import Combine
import SwiftUI

/// Borderless panels refuse key status by default; the switcher needs it to take typing.
final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
}

@MainActor
final class LauncherModel: ObservableObject {
    @Published var query = ""
    @Published var selection = 0
    @Published var focusToken = 0

    func filter(_ agents: [Agent]) -> [Agent] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return agents }
        let terms = q.split(separator: " ")
        return agents.filter { a in
            let hay = [a.displayTitle, a.project, a.kind.displayName, a.host?.name ?? "", a.state.label, a.cwd]
                .joined(separator: " ").lowercased()
            return terms.allSatisfy { hay.contains($0) }
        }
    }
}

/// Spotlight-style switcher: hotkey → type to filter → ↵ jumps to that agent's terminal.
@MainActor
final class LauncherController: NSObject, NSWindowDelegate {
    private let store: AgentStore
    private let onSettings: () -> Void
    private let model = LauncherModel()
    private let panel: KeyPanel
    private var keyMonitor: Any?
    private var cancellables: Set<AnyCancellable> = []

    static let width: CGFloat = 660
    static let searchHeight: CGFloat = 56
    static let gap: CGFloat = 10
    static let rowHeight: CGFloat = 54
    static let listPadding: CGFloat = 8
    /// Transparent margin so the glass shadow isn't clipped by the window edge.
    static let margin: CGFloat = 20
    static let maxRows = 8
    /// The results panel's title bar, on looks whose skin has one.
    static let titleHeight: CGFloat = 22

    init(store: AgentStore, onSettings: @escaping () -> Void) {
        self.store = store
        self.onSettings = onSettings
        panel = KeyPanel(contentRect: NSRect(x: 0, y: 0, width: Self.width, height: 300),
                         styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: true)
        super.init()
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false // the glass draws its own
        panel.hidesOnDeactivate = false
        panel.delegate = self

        let host = NSHostingView(rootView: LauncherView(store: store, model: model,
                                                        onOpen: { [weak self] in self?.open($0) },
                                                        onSettings: { [weak self] in self?.openSettings() }))
        host.wantsLayer = true
        host.layer?.backgroundColor = .clear
        panel.contentView = host

        // Keep the panel height matched to the visible rows, anchored at the top edge.
        store.$agents.combineLatest(model.$query)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.resize() }
            .store(in: &cancellables)
    }

    var isVisible: Bool { panel.isVisible }
    var frame: NSRect { panel.frame }

    /// Scripted demo: type into the search field, then "press ↵".
    func demoType(_ query: String) { model.query = query }
    func demoOpenSelected() {
        let results = model.filter(store.agents)
        if results.indices.contains(model.selection) { open(results[model.selection]) }
    }

    func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        model.query = ""
        model.selection = 0
        let screen = NSScreen.screens.first { NSMouseInRect(NSEvent.mouseLocation, $0.frame, false) } ?? NSScreen.main
        if let visible = screen?.visibleFrame {
            let h = height()
            let w = Self.width + Self.margin * 2
            panel.setFrame(NSRect(x: visible.midX - w / 2, y: visible.minY + visible.height * 0.74 - h,
                                  width: w, height: h), display: false)
        }
        panel.makeKeyAndOrderFront(nil)
        model.focusToken += 1
        installKeyMonitor()
    }

    func hide() {
        panel.orderOut(nil)
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }

    func windowDidResignKey(_ notification: Notification) { hide() }

    private func open(_ agent: Agent) {
        hide()
        store.acknowledge(agent)
        Focus.open(agent)
    }

    private func openSettings() {
        hide()
        onSettings()
    }

    private func height() -> CGFloat {
        let rows = max(1, min(Self.maxRows, model.filter(store.agents).count))
        let bar = Settings.shared.activeLook.skin?.titleBar == nil ? 0 : Self.titleHeight
        return Self.margin * 2 + Self.searchHeight + Self.gap + bar + CGFloat(rows) * Self.rowHeight + Self.listPadding * 2
    }

    private func resize() {
        guard panel.isVisible else { return }
        var frame = panel.frame
        let h = height()
        guard frame.height != h else { return }
        frame.origin.y += frame.height - h
        frame.size.height = h
        panel.setFrame(frame, display: true)
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            let results = self.model.filter(self.store.agents)
            let ctrl = event.modifierFlags.contains(.control)
            switch Int(event.keyCode) {
            case 53: // esc
                self.hide()
                return nil
            case 125: // ↓
                self.move(1, count: results.count)
                return nil
            case 126: // ↑
                self.move(-1, count: results.count)
                return nil
            case 45 where ctrl: // ⌃N
                self.move(1, count: results.count)
                return nil
            case 35 where ctrl: // ⌃P
                self.move(-1, count: results.count)
                return nil
            case 36, 76: // return
                if results.indices.contains(self.model.selection) { self.open(results[self.model.selection]) }
                return nil
            case 43 where event.modifierFlags.contains(.command): // ⌘,
                self.openSettings()
                return nil
            default:
                if event.modifierFlags.contains(.command), let n = Int(event.charactersIgnoringModifiers ?? ""),
                   (1...9).contains(n), results.indices.contains(n - 1) {
                    self.open(results[n - 1])
                    return nil
                }
                return event
            }
        }
    }

    private func move(_ delta: Int, count: Int) {
        guard count > 0 else { return }
        model.selection = (model.selection + delta + count) % count
    }
}

struct LauncherView: View {
    @ObservedObject var store: AgentStore
    @ObservedObject var model: LauncherModel
    var onOpen: (Agent) -> Void
    var onSettings: () -> Void
    @ObservedObject private var settings = Settings.shared
    @FocusState private var searchFocused: Bool
    @Namespace private var selectionNS

    private var skin: Skin? { settings.activeLook.skin }

    var body: some View {
        let results = model.filter(store.agents)
        GlassGroup(spacing: LauncherController.gap) {
            VStack(spacing: LauncherController.gap) {
                if let skin {
                    searchBar
                        .panelSurface(skin, in: RoundedRectangle(cornerRadius: skin.corner))
                    VStack(spacing: 0) {
                        if let bar = skin.titleBar,
                           let paint = settings.activeLook.barPaint(for: .working, dark: skin.colorScheme == .dark) {
                            SkinTitleBar(bar: Self.panelBar(bar), paint: paint, scale: 1, corner: skin.corner) {
                                Text(skin.cased("barn"))
                                    .font(skin.font(12, .bold))
                                    .barGap(bar, paint, scale: 1)
                                    .frame(maxWidth: .infinity, alignment: bar.buttons == .win || bar.buttons == .xp ? .leading : .center)
                            }
                            .padding([.top, .horizontal], DeckMetrics(scale: 1, design: .default, family: nil, skin: skin).inset)
                        }
                        resultList(results)
                    }
                    .panelSurface(skin, in: RoundedRectangle(cornerRadius: skin.corner))
                } else {
                    searchBar
                        .barnGlass(in: Capsule())
                    resultList(results)
                        .barnGlass(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
            }
        }
        .padding(LauncherController.margin)
        .onChange(of: model.focusToken, initial: true) { searchFocused = true }
    }

    private var searchBar: some View {
        HStack(spacing: 12) {
            if let skin {
                Text(skin.prompt ?? ">")
                    .font(skin.font(21, .bold))
                    .fixedSize()
            } else {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 19, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            TextField(skin?.cased("search agents") ?? "search agents", text: $model.query)
                .textFieldStyle(.plain)
                .font(skin?.font(21) ?? .system(size: 21, weight: .regular))
                .focused($searchFocused)
                .onChange(of: model.query) { model.selection = 0 }
            ForEach(summary, id: \.label) { chip in
                HStack(spacing: 5) {
                    if skin != nil {
                        Rectangle().fill(Color(nsColor: chip.state.color)).frame(width: 6, height: 6)
                    } else {
                        Circle().fill(Color(nsColor: chip.state.color)).frame(width: 6, height: 6)
                    }
                    Text(skin?.cased(chip.label) ?? chip.label)
                }
                .font(skin?.font(11.5, .medium) ?? .system(size: 11.5, weight: .medium))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 9)
                .frame(height: 24)
                .background {
                    if let skin {
                        Rectangle().strokeBorder(Color(nsColor: skin.dimColor), lineWidth: 1)
                    } else {
                        Capsule().fill(.primary.opacity(0.06))
                    }
                }
            }
            Button(action: onSettings) {
                Image(systemName: "gearshape")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .help("settings (⌘,)")
        }
        .padding(.horizontal, 20)
        .frame(height: LauncherController.searchHeight)
    }

    @ViewBuilder
    private func resultList(_ results: [Agent]) -> some View {
        if results.isEmpty {
            VStack(spacing: 4) {
                Text(cased(store.agents.isEmpty ? "no agents running" : "no matches"))
                    .font(skin?.font(13, .medium) ?? .system(size: 13, weight: .medium))
                if store.agents.isEmpty {
                    Text(cased("start claude, codex, vibe… in any terminal"))
                        .font(skin?.font(11.5) ?? .system(size: 11.5))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(results.enumerated()), id: \.element.id) { i, agent in
                            LauncherRow(agent: agent, index: i, selected: i == model.selection)
                                .background {
                                    if i == model.selection, let skin {
                                        // An inverse-video bar, like a DOS menu.
                                        RoundedRectangle(cornerRadius: min(skin.corner, 6))
                                            .fill(Color(nsColor: skin.textColor))
                                            .matchedGeometryEffect(id: "selection", in: selectionNS)
                                    } else if i == model.selection {
                                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                                            .fill(Brand.blue.opacity(0.2))
                                            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .strokeBorder(Brand.blue.opacity(0.25), lineWidth: 0.5))
                                            .matchedGeometryEffect(id: "selection", in: selectionNS)
                                    }
                                }
                                .id(agent.id)
                                .contentShape(Rectangle())
                                .onTapGesture { onOpen(agent) }
                                .onHover {
                                    guard $0, model.selection != i else { return }
                                    model.selection = i
                                    Chimes.shared.tick()
                                }
                        }
                    }
                    .padding(LauncherController.listPadding)
                    .animation(.snappy(duration: 0.18), value: model.selection)
                }
                .scrollIndicators(.never)
                .onChange(of: model.selection) {
                    if results.indices.contains(model.selection) { proxy.scrollTo(results[model.selection].id) }
                }
            }
        }
    }

    private func cased(_ s: String) -> String { skin?.cased(s) ?? s }

    /// The skin's title bar at the switcher's size.
    private static func panelBar(_ bar: Skin.TitleBar) -> Skin.TitleBar {
        var b = bar
        b.height = LauncherController.titleHeight
        return b
    }

    private var summary: [(label: String, state: AgentState)] {
        let waiting = store.agents.filter { $0.state == .waiting }.count
        let working = store.agents.filter { $0.state == .working }.count
        let ready = store.agents.filter { $0.state == .ready }.count
        var chips: [(String, AgentState)] = []
        if waiting > 0 { chips.append(("\(waiting) need you", .waiting)) }
        if ready > 0 { chips.append(("\(ready) ready", .ready)) }
        if working > 0 { chips.append(("\(working) working", .working)) }
        if chips.isEmpty { chips.append(("\(store.agents.count) idle", .idle)) }
        return chips.map { (label: $0.0, state: $0.1) }
    }
}

struct LauncherRow: View {
    var agent: Agent
    var index: Int
    var selected = false
    @ObservedObject private var settings = Settings.shared

    var body: some View {
        let look = settings.activeLook
        let skin = look.skin
        let cased = { (s: String) in skin?.cased(s) ?? s }
        let font = { (size: CGFloat, weight: Font.Weight) in skin?.font(size, weight) ?? .system(size: size, weight: weight) }
        // On a skin the selected row is inverse video: the skin's background color on its text color.
        let inverse = selected && skin != nil
        let status: Color = if inverse {
            Color(nsColor: skin!.backgroundColor)
        } else if let skin, agent.state == .waiting {
            Color(nsColor: look.dotColor(for: .waiting, dark: skin.colorScheme == .dark))
        } else if agent.state == .waiting {
            agent.state.style.swiftColor
        } else {
            .secondary
        }
        HStack(spacing: 12) {
            StateDot(state: agent.state, size: 9)
                .frame(width: 14)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 7) {
                    Text(cased(agent.displayTitle))
                        .font(font(14, .semibold))
                        .lineLimit(1)
                    if agent.title != nil {
                        Text(cased(agent.project))
                            .font(font(12, .medium))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                TimelineView(.periodic(from: .now, by: 1)) { ctx in
                    Text(cased("\(agent.kind.displayName) · \(statusLine(agent, now: ctx.date))"))
                        .font(font(12, .regular))
                        .foregroundStyle(status)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            AppIcon(host: agent.host, size: 22)
            if index < 9 {
                Text("⌘\(index + 1)")
                    .font(skin?.font(11, .medium) ?? .system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
                    .frame(width: 28)
            }
        }
        .foregroundStyle(inverse ? Color(nsColor: skin!.backgroundColor) : skin.map { Color(nsColor: $0.textColor) } ?? .primary)
        .padding(.horizontal, 12)
        .frame(height: LauncherController.rowHeight)
        .stateLook(settings.activeLook.style(for: agent.state),
                   in: RoundedRectangle(cornerRadius: 14, style: .continuous), motion: false)
    }
}
