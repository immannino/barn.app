import AppKit
import Carbon.HIToolbox
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let store = AgentStore()
    private var launcher: LauncherController!
    private var deck: DeckController!
    private let settingsWindow = SettingsController()
    private var notifier: Notifier!
    private var statusItem: NSStatusItem!
    private var hotKeys: [HotKey] = []
    private var cancellables: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        let openSettings: () -> Void = { [weak self] in self?.settingsWindow.show() }
        launcher = LauncherController(store: store, onSettings: openSettings)
        deck = DeckController(store: store, onSettings: openSettings)
        notifier = Notifier(store: store)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.delegate = self
        statusItem.menu = menu
        store.$agents
            .receive(on: RunLoop.main)
            .sink { [weak self] in self?.renderStatusItem($0) }
            .store(in: &cancellables)

        // Other menu bar apps coming and going (or a display change) can push the icon behind the notch.
        let center = NotificationCenter.default
        center.publisher(for: NSWindow.didMoveNotification, object: statusItem.button?.window)
            .merge(with: center.publisher(for: NSApplication.didChangeScreenParametersNotification))
            .debounce(for: .seconds(1), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.checkStatusItemVisible() }
            .store(in: &cancellables)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { self.checkStatusItemVisible() }

        // Re-register global shortcuts whenever they change; pause them while one is being recorded.
        let settings = Settings.shared
        settings.$switcherHotKey.combineLatest(settings.$deckHotKey, settings.$isRecordingHotKey)
            .receive(on: RunLoop.main)
            .sink { [weak self] switcher, deck, recording in
                self?.registerHotKeys(switcher: switcher, deck: deck, paused: recording)
            }
            .store(in: &cancellables)

        store.start()
        // No update prompts or settings windows popping up mid-recording.
        if !CommandLine.arguments.contains("--demo") { Updater.shared.start() }
        if DemoScript.isOn { DemoScript.run(store: store, launcher: launcher, deck: deck) }
        DispatchQueue.global(qos: .utility).async { Integration.all.forEach { $0.repairIfMoved() } }

        // Dev conveniences: `open barn.app --args --switcher --deck --settings`.
        let args = CommandLine.arguments
        if args.contains("--deck") { deck.show() }
        if !Settings.shared.welcomed, !args.contains("--settings"), !args.contains("--demo") { settingsWindow.show() }
        if let i = args.firstIndex(of: "--settings") {
            let tab = i + 1 < args.count ? SettingsView.Tab(rawValue: args[i + 1]) : nil
            settingsWindow.show(tab: tab ?? .general)
        }
        if let i = args.firstIndex(of: "--focus"), i + 1 < args.count, let pid = Int32(args[i + 1]) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                if let agent = self.store.agents.first(where: { $0.pid == pid }) { Focus.open(agent) }
                else { Log.write("--focus: no agent with pid \(pid)") }
            }
        }
        if args.contains("--switcher") {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { self.launcher.show() }
        }
    }

    private func registerHotKeys(switcher: KeyCombo?, deck deckCombo: KeyCombo?, paused: Bool) {
        hotKeys = [] // deinit unregisters
        var errors: Set<String> = []
        if !paused {
            let actions: [(String, KeyCombo?, () -> Void)] = [
                ("switcher", switcher, { [weak self] in self?.launcher.toggle() }),
                ("deck", deckCombo, { [weak self] in self?.deck.toggle() }),
            ]
            for (id, combo, action) in actions {
                guard let combo else { continue }
                if let hk = HotKey(keyCode: combo.keyCode, modifiers: combo.modifiers, handler: action) {
                    hotKeys.append(hk)
                } else {
                    errors.insert(id)
                }
            }
        }
        if !paused, Settings.shared.hotKeyErrors != errors { Settings.shared.hotKeyErrors = errors }
    }

    /// Opening barn.app while it's already running (Finder, Spotlight) opens settings, so it's
    /// reachable even when the menu bar icon isn't.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        settingsWindow.show()
        return false
    }

    // MARK: Status item — one dot per agent, like a tiny deck in the menu bar.

    /// macOS silently drops status items that don't fit; on notched displays they end up under the
    /// notch. The first time that happens, open settings to explain it.
    private func checkStatusItemVisible() {
        guard !CommandLine.arguments.contains("--demo"), let frame = statusItem.button?.window?.frame else { return }
        let hidden = Self.isHidden(statusItem: frame, screens: NSScreen.screens.map { ($0.frame, $0.auxiliaryTopRightArea) })
        let settings = Settings.shared
        if settings.menuBarIconHidden != hidden { settings.menuBarIconHidden = hidden }
        if hidden {
            Log.write("menu bar icon is hidden (x=\(Int(frame.minX)))")
            if !settings.hiddenIconExplained {
                settings.hiddenIconExplained = true
                settingsWindow.show()
            }
        }
    }

    /// `notchRight` is `NSScreen.auxiliaryTopRightArea`, in the screen's own coordinates (nil without a notch).
    nonisolated static func isHidden(statusItem item: NSRect, screens: [(frame: NSRect, notchRight: NSRect?)]) -> Bool {
        // Match on x only: with an auto-hiding menu bar the item can sit above the screen's top edge.
        guard let screen = screens.first(where: { $0.frame.minX <= item.midX && item.midX < $0.frame.maxX })
        else { return true }
        guard let notchRight = screen.notchRight else { return false }
        return item.minX < screen.frame.minX + notchRight.minX - 1
    }

    private func renderStatusItem(_ agents: [Agent]) {
        guard let button = statusItem.button else { return }
        button.toolTip = agents.isEmpty ? "barn — no agents" : agents.map { "\($0.state.label): \($0.displayTitle)" }.joined(separator: "\n")
        guard !agents.isEmpty else {
            button.image = Brand.menuBarGlyph()
            button.title = ""
            return
        }
        let shown = Array(agents.prefix(10))
        let dot: CGFloat = 7, gap: CGFloat = 3
        let size = NSSize(width: CGFloat(shown.count) * (dot + gap) - gap + 2, height: 16)
        button.image = NSImage(size: size, flipped: false) { _ in
            for (i, agent) in shown.enumerated() {
                let rect = NSRect(x: 1 + CGFloat(i) * (dot + gap), y: (size.height - dot) / 2, width: dot, height: dot)
                agent.state.color.setFill()
                NSBezierPath(ovalIn: rect).fill()
            }
            return true
        }
        button.title = agents.count > shown.count ? " +\(agents.count - shown.count)" : ""
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        menu.removeAllItems()
        if store.agents.isEmpty {
            menu.addItem(withTitle: "no agents running", action: nil, keyEquivalent: "")
        }
        let now = Date()
        for agent in store.agents {
            let item = NSMenuItem(title: agent.displayTitle, action: #selector(openAgent(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = agent.id
            item.image = Self.dotImage(agent.state.color)
            let subtitle = "\(agent.project) · \(agent.kind.displayName) · \(statusLine(agent, now: now))"
            if #available(macOS 14.4, *) { item.subtitle = subtitle } else { item.toolTip = subtitle }
            menu.addItem(item)
        }
        menu.addItem(.separator())
        let settings = Settings.shared
        let items = [
            Self.item("open switcher", #selector(openSwitcher), settings.switcherHotKey),
            Self.item("floating deck", #selector(toggleDeck), settings.deckHotKey),
        ]
        items[1].state = deck.isVisible ? .on : .off
        let prefs = NSMenuItem(title: "settings…", action: #selector(openSettings), keyEquivalent: ",")
        var extras = [prefs]
        if Updater.shared.isAvailable {
            let update = NSMenuItem(title: "check for updates…", action: #selector(checkForUpdates), keyEquivalent: "")
            update.isEnabled = Updater.shared.canCheck
            extras.append(update)
        }
        for item in items + extras {
            item.target = self
            menu.addItem(item)
        }
        menu.addItem(.separator())
        menu.addItem(withTitle: "quit barn", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
    }

    /// Menu item showing its global shortcut (when it maps to a menu key equivalent).
    private static func item(_ title: String, _ action: Selector, _ combo: KeyCombo?) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        guard let combo else { return item }
        let key = combo.keyCode == kVK_Space ? " " : combo.keyName.lowercased()
        guard key.count == 1 else { return item }
        item.keyEquivalent = key
        var mask: NSEvent.ModifierFlags = []
        if combo.modifiers & cmdKey != 0 { mask.insert(.command) }
        if combo.modifiers & optionKey != 0 { mask.insert(.option) }
        if combo.modifiers & controlKey != 0 { mask.insert(.control) }
        if combo.modifiers & shiftKey != 0 { mask.insert(.shift) }
        item.keyEquivalentModifierMask = mask
        return item
    }

    @objc private func openAgent(_ sender: NSMenuItem) {
        guard let id = sender.representedObject as? String, let agent = store.agents.first(where: { $0.id == id }) else { return }
        store.acknowledge(agent)
        Focus.open(agent)
    }

    @objc private func openSwitcher() { launcher.show() }
    @objc private func toggleDeck() { deck.toggle() }
    @objc private func openSettings() { settingsWindow.show() }
    @objc private func checkForUpdates() { Updater.shared.checkForUpdates() }

    private static func dotImage(_ color: NSColor) -> NSImage {
        NSImage(size: NSSize(width: 10, height: 10), flipped: false) { rect in
            color.setFill()
            NSBezierPath(ovalIn: rect.insetBy(dx: 1, dy: 1)).fill()
            return true
        }
    }
}

/// Entry point, called from the `barn` executable's main.swift.
public enum BarnApp {
    @MainActor public static func main() {
        let args = CommandLine.arguments
        if args.count >= 2, args[1] == "hook" { HookCommand.run(harness: args.count > 2 ? args[2] : "unknown") }
        if args.contains("--dump") { return dump() }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }

    /// `Barn --dump`: print what detection sees, without any UI.
    private static func dump() {
        let scanner = ProcessScanner()
        _ = scanner.scan()
        Thread.sleep(forTimeInterval: 1)
        let found = scanner.scan()
        let sessions = ClaudeSessions().read()
        for f in found.sorted(by: { $0.pid < $1.pid }) {
            let s = sessions[f.pid]
            let status: String = s.map { "status=\($0.status)" } ?? "status=(inferred)"
            let fields: [String] = [
                "\(f.pid)", f.kind.id, f.tty ?? "-", f.host?.name ?? "?",
                String(format: "cpu=%.0f%%", f.cpu * 100),
                status, s?.title ?? "-", s?.activity ?? "-", f.cwd,
            ]
            print(fields.joined(separator: "  "))
        }
    }
}
