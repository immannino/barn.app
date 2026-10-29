import AppKit
import SwiftUI

@MainActor
final class SettingsController {
    private var window: NSWindow?

    func show(tab: SettingsView.Tab = .general) {
        if let window { window.close() }
        let window = makeWindow(tab: tab)
        self.window = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(tab: SettingsView.Tab) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 520),
                              styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: true)
        window.title = "barn settings"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: SettingsView(settings: .shared, tab: tab))
        window.center()
        return window
    }
}

struct SettingsView: View {
    @ObservedObject var settings: Settings
    @State var tab = Tab.general

    enum Tab: String, CaseIterable {
        case general, looks, shortcuts, agents, about
        var icon: String {
            switch self {
            case .general: "gearshape"
            case .looks: "paintpalette"
            case .shortcuts: "command"
            case .agents: "sparkles"
            case .about: "heart"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Group {
                switch tab {
                case .general: GeneralPane(settings: settings) { tab = .agents }
                case .looks: LooksPane(settings: settings)
                case .shortcuts: ShortcutsPane(settings: settings)
                case .agents: AgentsPane(settings: settings)
                case .about: AboutPane()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .ignoresSafeArea(edges: .top)
        .tint(Brand.blue)
        .frame(width: 600, height: 520)
    }

    private var header: some View {
        ZStack(alignment: .bottom) {
            BrandBackdrop()
            HStack(alignment: .bottom) {
                Wordmark(size: 30)
                    .foregroundStyle(.white)
                Spacer()
                HStack(spacing: 4) {
                    ForEach(Tab.allCases, id: \.self) { t in
                        Button { tab = t } label: {
                            Label(t.rawValue, systemImage: t.icon)
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                                .padding(.horizontal, 11)
                                .frame(height: 28)
                                .foregroundStyle(tab == t ? Color(nsColor: Brand.ink) : .white.opacity(0.9))
                                .background(Capsule().fill(tab == t ? Color.white : .white.opacity(0.12)))
                                .contentShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 16)
        }
        .frame(height: 112)
        .ignoresSafeArea()
    }
}

// MARK: Panes

struct Pane<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) { content }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct SectionTitle: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .bold, design: .rounded))
            .foregroundStyle(.secondary)
            .textCase(.lowercase)
    }
}

private struct GeneralPane: View {
    @ObservedObject var settings: Settings
    @ObservedObject private var updater = Updater.shared
    var showAgents: () -> Void

    var body: some View {
        Pane {
            if settings.menuBarIconHidden { HiddenIconCard(settings: settings) }
            if !settings.welcomed { WelcomeCard(settings: settings, showAgents: showAgents) }
            SectionTitle(text: "startup")
            Toggle("open barn at login", isOn: Binding(get: { settings.launchAtLogin },
                                                      set: { settings.launchAtLogin = $0 }))
            SectionTitle(text: "agents")
            Toggle("one agent per VS Code window", isOn: $settings.onePerWindow)
            Text("The Claude Code extension keeps a process for every conversation tab. This shows the busiest one per window and counts the rest.")
                .font(.caption)
                .foregroundStyle(.secondary)
            SectionTitle(text: "notifications")
            Toggle("when an agent needs you", isOn: $settings.notifyWaiting)
            Toggle("when an agent finishes a turn", isOn: $settings.notifyReady)
            Toggle("play a sound", isOn: $settings.notificationSound)
                .disabled(!settings.notifyWaiting && !settings.notifyReady)
            SectionTitle(text: "sounds & haptics")
            Toggle("play little barn sounds", isOn: $settings.soundsOn)
            VStack(alignment: .leading, spacing: 6) {
                soundRow("when an agent shows up or leaves", $settings.soundComings, .arrive)
                soundRow("when an agent needs you", $settings.soundWaiting, .needsYou)
                soundRow("when an agent finishes a turn", $settings.soundReady, .ready)
                soundRow("when you jump to an agent", $settings.soundJump, .jump)
                HStack(spacing: 8) {
                    Image(systemName: "speaker.fill").foregroundStyle(.secondary)
                    Slider(value: $settings.soundVolume, in: 0.1...1) { editing in
                        if !editing { Chimes.shared.preview(.ready) }
                    }
                    .frame(maxWidth: 200)
                    Image(systemName: "speaker.wave.3.fill").foregroundStyle(.secondary)
                }
            }
            .padding(.leading, 20)
            .disabled(!settings.soundsOn)
            Toggle("trackpad taps", isOn: $settings.haptics)
            Text("A little tap with each sound, and as the switcher's selection moves under your pointer. You'll feel them on a Force Touch trackpad while a finger is on it.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            if updater.isAvailable {
                SectionTitle(text: "updates")
                HStack {
                    Toggle("check for updates automatically", isOn: Binding(get: { updater.automaticallyChecks },
                                                                           set: { updater.automaticallyChecks = $0 }))
                    Spacer()
                    Button("check now") { updater.checkForUpdates() }
                        .disabled(!updater.canCheck)
                        .controlSize(.small)
                }
            }
            SectionTitle(text: "exact status from any agent")
            Text("Point an agent's hooks at barn and it reports exactly when it's working or waiting on you. This works for Codex, Gemini, Copilot, Factory Droid, Qwen, Auggie, Kiro and Cline.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            CodeBlock(text: "barn hook codex")
            Text("No hooks? Anything can write a status file. It's keyed by the agent's pid and removed when that process exits:")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            CodeBlock(text: #"echo '{"state":"waiting","detail":"approve deploy"}' > ~/.barn/status/$PPID.json"#)
        }
    }
}

extension GeneralPane {
    private func soundRow(_ label: String, _ isOn: Binding<Bool>, _ cue: Chimes.Cue) -> some View {
        HStack {
            Toggle(label, isOn: isOn)
            Spacer()
            Button { Chimes.shared.preview(cue) } label: { Image(systemName: "play.circle") }
                .buttonStyle(.borderless)
                .help("play it")
        }
    }
}

private struct WelcomeCard: View {
    @ObservedObject var settings: Settings
    var showAgents: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("hi! barn is living in your menu bar now.")
                .font(.system(size: 16, weight: .bold, design: .rounded))
            VStack(alignment: .leading, spacing: 6) {
                step("1", "Press \(settings.switcherHotKey?.display ?? "the switcher shortcut") anywhere to find an agent and jump to its terminal.")
                step("2", "The first jump asks if barn can control your terminal. Say OK; that's how it picks the exact tab.")
                step("3", "Optional: connect your other agents' hooks for exact working/waiting state.")
            }
            HStack {
                Button("connect agents") { showAgents() }
                    .buttonStyle(.borderedProminent)
                Button("got it") { settings.welcomed = true }
            }
            .controlSize(.small)
        }
        .foregroundStyle(.white)
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BrandBackdrop().clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)))
    }

    private func step(_ n: String, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(n)
                .font(.system(size: 11, weight: .heavy, design: .rounded))
                .foregroundStyle(Color(nsColor: Brand.ink))
                .frame(width: 18, height: 18)
                .background(Circle().fill(Color(nsColor: Brand.butter)))
            Text(text).font(.system(size: 12.5))
        }
    }
}

/// Shown while macOS isn't drawing barn's menu bar icon, usually because the bar is full and
/// the icon landed behind the notch.
private struct HiddenIconCard: View {
    @ObservedObject var settings: Settings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("your menu bar is full, so barn's icon is hidden", systemImage: "eye.slash")
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
            Text("macOS hides menu bar icons that don't fit beside the notch. barn is still running. To make room, ⌘-drag icons you don't need off the menu bar, or turn some off in System Settings → Control Center. Then ⌘-drag barn to the right so it stays visible.")
                .font(.system(size: 12))
            Text("You can always get here without the icon: the gear in the switcher (\(settings.switcherHotKey?.display ?? "switcher shortcut")), right-clicking the floating deck, or opening barn again from Applications.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(nsColor: Brand.coral).opacity(0.14)))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).strokeBorder(Color(nsColor: Brand.coral).opacity(0.4)))
    }
}

private struct CodeBlock: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 11.5, design: .monospaced))
            .textSelection(.enabled)
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 8).fill(.primary.opacity(0.06)))
    }
}

private struct ShortcutsPane: View {
    @ObservedObject var settings: Settings

    var body: some View {
        Pane {
            SectionTitle(text: "global shortcuts")
            ShortcutRow(title: "open switcher", subtitle: "search and jump to any agent",
                        id: "switcher", combo: $settings.switcherHotKey, fallback: .switcherDefault, settings: settings)
            ShortcutRow(title: "toggle floating deck", subtitle: "always-on-top tiles",
                        id: "deck", combo: $settings.deckHotKey, fallback: .deckDefault, settings: settings)
            Text("Click a shortcut, then press the new keys. esc cancels, ⌫ turns it off.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            SectionTitle(text: "in the switcher")
            VStack(alignment: .leading, spacing: 6) {
                keyHint("↑ ↓  or  ⌃N ⌃P", "move")
                keyHint("↩", "jump to terminal")
                keyHint("⌘1 – ⌘9", "jump directly")
                keyHint("esc", "close")
            }
        }
    }

    private func keyHint(_ keys: String, _ what: String) -> some View {
        HStack {
            Text(keys).font(.system(size: 12, weight: .medium, design: .rounded)).frame(width: 130, alignment: .leading)
            Text(what).font(.system(size: 12)).foregroundStyle(.secondary)
        }
    }
}

private struct ShortcutRow: View {
    var title: String
    var subtitle: String
    var id: String
    @Binding var combo: KeyCombo?
    var fallback: KeyCombo
    @ObservedObject var settings: Settings

    var body: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 13, weight: .medium))
                Text(subtitle).font(.system(size: 11.5)).foregroundStyle(.secondary)
                if let warning { Text(warning).font(.system(size: 11)).foregroundStyle(Color(nsColor: Brand.coral)) }
            }
            Spacer()
            HotKeyRecorder(combo: $combo, settings: settings)
            Button {
                combo = fallback
            } label: {
                Image(systemName: "arrow.counterclockwise")
            }
            .buttonStyle(.borderless)
            .help("reset to \(fallback.display)")
            .disabled(combo == fallback)
        }
    }

    private var warning: String? {
        if settings.hotKeyErrors.contains(id) { return "another app already uses this shortcut" }
        if combo?.systemConflict == true { return "conflicts with a macOS shortcut" }
        return nil
    }
}

/// Click to record a new global shortcut.
struct HotKeyRecorder: View {
    @Binding var combo: KeyCombo?
    @ObservedObject var settings: Settings
    @State private var recording = false
    @State private var monitor: Any?

    var body: some View {
        Button {
            recording ? stop() : start()
        } label: {
            Text(recording ? "press keys…" : (combo?.display ?? "off"))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .frame(minWidth: 110)
                .frame(height: 28)
                .foregroundStyle(recording ? .white : .primary)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(recording ? Brand.blue : Color.primary.opacity(0.07))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(recording ? Color.white.opacity(0.3) : Color.primary.opacity(0.12), lineWidth: 0.5)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onDisappear { stop() }
    }

    private func start() {
        recording = true
        settings.isRecordingHotKey = true // global hotkeys are paused so the current combo can be captured
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            switch Int(event.keyCode) {
            case 53 where event.modifierFlags.intersection([.command, .option, .control]).isEmpty:
                stop()
            case 51 where event.modifierFlags.intersection([.command, .option, .control]).isEmpty:
                combo = nil
                stop()
            default:
                if let new = KeyCombo(event: event) {
                    combo = new
                    stop()
                } else {
                    NSSound.beep()
                }
            }
            return nil
        }
    }

    private func stop() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        recording = false
        settings.isRecordingHotKey = false
    }
}

private struct AgentsPane: View {
    @ObservedObject var settings: Settings
    @State private var newName = ""
    @State private var newProcesses = ""

    /// Kinds with a dedicated state reader, and kinds whose hooks can call `barn hook`.
    private let exact: Set<String> = ["claude", "vibe"]
    private let hookable: Set<String> = ["codex", "gemini", "copilot", "droid", "qwen", "auggie", "kiro", "cline"]

    var body: some View {
        Pane {
            SectionTitle(text: "exact state through hooks")
            Text("One click adds `barn hook` to the tool's hook config, so barn knows exactly when it's working or waiting on you. Your other settings are kept, and the original file is backed up once.")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            IntegrationsList()

            SectionTitle(text: "built in")
            VStack(spacing: 0) {
                ForEach(AgentKind.builtIns) { kind in
                    HStack {
                        Text(kind.badge)
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .foregroundStyle(.white)
                            .frame(width: 26, height: 18)
                            .background(RoundedRectangle(cornerRadius: 5).fill(Brand.blue))
                        VStack(alignment: .leading, spacing: 1) {
                            Text(kind.displayName).font(.system(size: 13, weight: .medium))
                            Text(kind.executableNames.joined(separator: ", "))
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(exact.contains(kind.id) ? "exact state" : hookable.contains(kind.id) ? "exact with hook" : "activity")
                            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                            .foregroundStyle(exact.contains(kind.id) ? Color(nsColor: Brand.mint)
                                : hookable.contains(kind.id) ? Color(nsColor: Brand.sky) : .secondary)
                        Toggle("", isOn: Binding(
                            get: { !settings.disabledKinds.contains(kind.id) },
                            set: { on in
                                if on { settings.disabledKinds.remove(kind.id) } else { settings.disabledKinds.insert(kind.id) }
                            }))
                            .toggleStyle(.switch)
                            .controlSize(.small)
                            .labelsHidden()
                    }
                    .padding(.vertical, 6)
                    Divider()
                }
            }

            SectionTitle(text: "your own")
            Text("Anything barn should treat as an agent. Matched against the process's executable name (or the script name when run by node, bun or python).")
                .font(.system(size: 11.5))
                .foregroundStyle(.secondary)
            ForEach(settings.customKinds) { kind in
                HStack {
                    Text(kind.displayName).font(.system(size: 13, weight: .medium))
                    Text(kind.executableNames.joined(separator: ", "))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        settings.customKinds.removeAll { $0.id == kind.id }
                    } label: { Image(systemName: "minus.circle.fill") }
                        .buttonStyle(.borderless)
                }
            }
            HStack {
                TextField("name", text: $newName).frame(width: 140)
                TextField("process names, comma separated", text: $newProcesses)
                Button("add", action: add)
                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty || processes.isEmpty)
            }
            .textFieldStyle(.roundedBorder)
        }
    }

    private var processes: [String] {
        newProcesses.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }

    private func add() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        let badge = String(name.filter(\.isLetter).prefix(2)).uppercased()
        settings.customKinds.append(AgentKind(id: "custom-\(UUID().uuidString.prefix(8))", displayName: name,
                                              badge: badge.isEmpty ? "??" : badge, executableNames: processes,
                                              builtIn: false))
        newName = ""
        newProcesses = ""
    }
}

private struct IntegrationsList: View {
    @State private var statuses: [String: Integration.Status] = [:]
    @State private var error: String?

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Integration.all) { integration in
                let status = statuses[integration.id] ?? .notInstalled
                HStack {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(integration.name).font(.system(size: 13, weight: .medium))
                        Text("~/" + integration.configPath)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(label(status))
                        .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                        .foregroundStyle(status == .installed ? Color(nsColor: Brand.mint) : .secondary)
                    switch status {
                    case .installed, .partial:
                        Button("remove") { run { try integration.uninstall() } }
                        if status == .partial { Button("repair") { run { try integration.install() } } }
                    case .notInstalled:
                        Button("set up") { run { try integration.install() } }
                            .buttonStyle(.borderedProminent)
                    case .toolMissing, .unreadable:
                        EmptyView()
                    }
                }
                .controlSize(.small)
                .padding(.vertical, 6)
                Divider()
            }
            if let error {
                Text(error)
                    .font(.system(size: 11.5))
                    .foregroundStyle(Color(nsColor: Brand.coral))
                    .padding(.top, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .onAppear(perform: refresh)
    }

    private func label(_ status: Integration.Status) -> String {
        switch status {
        case .installed: "connected"
        case .partial: "partly set up"
        case .notInstalled: ""
        case .toolMissing: "not installed"
        case .unreadable: "config isn't plain JSON"
        }
    }

    private func run(_ action: () throws -> Void) {
        do {
            try action()
            error = nil
        } catch let failure {
            error = failure.localizedDescription
        }
        refresh()
    }

    private func refresh() {
        statuses = Dictionary(uniqueKeysWithValues: Integration.all.map { ($0.id, $0.status()) })
    }
}

private struct AboutPane: View {
    var body: some View {
        Pane {
            HStack(spacing: 16) {
                if let icon = NSApp.applicationIconImage {
                    Image(nsImage: icon).resizable().frame(width: 72, height: 72)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Wordmark(size: 26)
                    Text("version \(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev")")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Text("a little barn for all your agents.")
                        .font(.system(size: 13, design: .rounded))
                }
            }
            Text("barn watches the process table and each agent's own session files. Nothing is sent anywhere, and it doesn't need to start your agents. The only thing it fetches is the update feed from barn.ope.cool, which you can turn off under general.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
            Button("open log") {
                NSWorkspace.shared.open(FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Library/Logs/barn.log"))
            }
        }
    }
}
