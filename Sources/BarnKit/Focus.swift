import AppKit

/// Brings the terminal running an agent to the front — the exact tab where the host allows it.
enum Focus {
    private static let queue = DispatchQueue(label: "barn.focus", qos: .userInteractive)

    /// Call from a user action (hotkey, click). macOS 14+ uses cooperative activation: a
    /// background app can't bring another app forward, so Barn takes activation itself (allowed
    /// right after user input) and explicitly yields it to the host before scripting it.
    @MainActor
    static func open(_ agent: Agent) {
        if CommandLine.arguments.contains("--demo") { return } // made-up agents have no terminals
        Chimes.shared.play(.jump)
        let host = agent.host.flatMap { $0.pid > 0 ? NSRunningApplication(processIdentifier: $0.pid) : nil }
        if !NSApp.isActive { NSApp.activate() }
        if let host { NSApp.yieldActivation(to: host) }
        queue.async {
            focus(agent)
            DispatchQueue.main.async { host?.activate() }
        }
    }

    private static func focus(_ agent: Agent) {
        Log.write("focus pid=\(agent.pid) host=\(agent.host?.bundleID ?? "nil") tty=\(agent.tty ?? "nil") cwd=\(agent.cwd) title=\(agent.title ?? "nil")")
        if agent.host?.viaTmux == true, tmux(agent) { return }
        switch agent.host?.bundleID {
        case "com.mitchellh.ghostty": if ghostty(agent) { return }
        case "com.googlecode.iterm2": if iterm(agent) { return }
        case "com.apple.Terminal": if terminalApp(agent) { return }
        case let id? where editors.contains(id):
            // Opening the folder with the editor raises the matching workspace window.
            if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
                let config = NSWorkspace.OpenConfiguration()
                NSWorkspace.shared.open([URL(fileURLWithPath: agent.cwd)], withApplicationAt: app, configuration: config)
                return
            }
        default: break
        }
        if let pid = agent.host?.pid, pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
            app.activate()
        }
    }

    private static let editors: Set<String> = [
        "com.microsoft.VSCode", "com.microsoft.VSCodeInsiders", "com.todesktop.230313mzl4w4u92",
        "com.exafunction.windsurf", "dev.zed.Zed",
    ]

    // MARK: Ghostty

    private struct GhosttyTerm { var window, tab, id, name, cwd: String }

    /// tty → Ghostty terminal id. Ids are stable for a terminal's lifetime; validated on use.
    private static var ghosttyIDs: [String: String] = [:]

    /// Ghostty 1.3+ exposes windows → tabs → terminals with title and working directory, but not
    /// the tty. Resolution order: cached id for this tty → the only terminal in the agent's cwd →
    /// the only one whose title contains the agent's title → a tty title probe (exact).
    /// `focus` alone doesn't raise a background window, so raise window and tab first.
    private static func ghostty(_ agent: Agent) -> Bool {
        guard let terminals = ghosttyTerminals() else { return false }
        let cwd = (agent.cwd as NSString).standardizingPath
        let inDir = terminals.filter { ($0.cwd as NSString).standardizingPath == cwd }
        let title = agent.title ?? ""
        let titled = inDir.filter { !title.isEmpty && $0.name.contains(title) }

        var best: GhosttyTerm?
        var how = ""
        if let tty = agent.tty, let id = ghosttyIDs[tty], let t = terminals.first(where: { $0.id == id }) {
            (best, how) = (t, "cached")
        } else if inDir.count == 1 {
            (best, how) = (inDir[0], "only-in-cwd")
        } else if titled.count == 1 {
            (best, how) = (titled[0], "title")
        } else if let tty = agent.tty, let t = probe(tty: tty, terminals: terminals) {
            (best, how) = (t, "probe")
        } else {
            (best, how) = (titled.first ?? inDir.first, "fallback")
        }
        Log.write("ghostty: \(terminals.count) terminals, \(inDir.count) in cwd, \(how) → \(best.map { "\($0.id) \($0.name)" } ?? "none")")
        guard let best else { return false }
        if let tty = agent.tty { ghosttyIDs[tty] = best.id }
        return run("""
        tell application "Ghostty"
            set w to (first window whose id is "\(escape(best.window))")
            activate window w
            select tab (tab \(best.tab) of w)
            focus (first terminal whose id is "\(escape(best.id))")
            activate
        end tell
        """) != nil
    }

    private static func ghosttyTerminals() -> [GhosttyTerm]? {
        // Build the separator outside the tell block: inside it, `tab` is Ghostty's tab class.
        let list = """
        set sep to character id 9
        tell application "Ghostty"
            set out to ""
            repeat with w in windows
                repeat with tb in tabs of w
                    repeat with t in terminals of tb
                        set out to out & (id of w) & sep & (index of tb) & sep & (id of t) & sep & (name of t) & sep & (working directory of t) & linefeed
                    end repeat
                end repeat
            end repeat
            return out
        end tell
        """
        guard let raw = run(list) else { return nil }
        return raw.split(separator: "\n").compactMap { line in
            let p = line.split(separator: "\t", omittingEmptySubsequences: false).map(String.init)
            return p.count >= 5 ? GhosttyTerm(window: p[0], tab: p[1], id: p[2], name: p[3], cwd: p[4]) : nil
        }
    }

    /// Write a unique OSC 2 title to the agent's tty (output to the terminal emulator, invisible,
    /// doesn't touch the agent's input), see which Ghostty terminal picks it up, then restore.
    private static func probe(tty: String, terminals: [GhosttyTerm]) -> GhosttyTerm? {
        let nonce = "barn-\(UUID().uuidString.prefix(8))"
        guard writeTitle(nonce, to: tty) else { return nil }
        var hit: GhosttyTerm?
        for _ in 0..<10 {
            usleep(40_000)
            guard let now = ghosttyTerminals() else { break }
            if let t = now.first(where: { $0.name == nonce }) {
                hit = t
                break
            }
        }
        if let hit, let original = terminals.first(where: { $0.id == hit.id }) {
            writeTitle(original.name, to: tty)
            return original
        }
        return hit
    }

    @discardableResult
    private static func writeTitle(_ title: String, to tty: String) -> Bool {
        let fd = Darwin.open(tty, O_WRONLY | O_NOCTTY | O_NONBLOCK)
        guard fd >= 0 else { return false }
        defer { close(fd) }
        let seq = Array("\u{1b}]2;\(title)\u{07}".utf8)
        return write(fd, seq, seq.count) == seq.count
    }

    // MARK: tmux

    /// Select the agent's pane, point the most relevant attached client at its session, then
    /// raise the terminal running that client (recursing into the Ghostty/iTerm/… paths).
    private static func tmux(_ agent: Agent) -> Bool {
        guard let tty = agent.tty,
              let bin = ["/opt/homebrew/bin/tmux", "/usr/local/bin/tmux", "/usr/bin/tmux"]
                .first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return false }
        let panes = shell(bin, ["list-panes", "-a", "-F", "#{pane_tty}\t#{session_name}\t#{window_id}\t#{pane_id}"])
        guard let pane = rows(panes).first(where: { $0.first == tty }), pane.count >= 4 else {
            Log.write("tmux: no pane with tty \(tty)")
            return false
        }
        let (session, window, paneID) = (pane[1], pane[2], pane[3])
        shell(bin, ["select-window", "-t", window])
        shell(bin, ["select-pane", "-t", paneID])

        // Prefer a client already on this session, else the most recently active one.
        let clients = rows(shell(bin, ["list-clients", "-F", "#{client_tty}\t#{client_pid}\t#{client_session}\t#{client_activity}"]))
            .filter { $0.count >= 4 }
            .sorted { (Int($0[3]) ?? 0) > (Int($1[3]) ?? 0) }
        guard let client = clients.first(where: { $0[2] == session }) ?? clients.first,
              let clientPID = pid_t(client[1]) else {
            Log.write("tmux: selected \(paneID) but no client is attached")
            return true
        }
        if client[2] != session { shell(bin, ["switch-client", "-c", client[0], "-t", session]) }
        Log.write("tmux: \(session) \(window) \(paneID) via client \(client[0])")

        guard var outer = ProcessScanner().describe(clientPID, as: agent.kind) else { return true }
        outer.tty = client[0]
        let host = Agent(pid: clientPID, kind: agent.kind, cwd: outer.cwd, tty: outer.tty, host: outer.host,
                         state: agent.state, stateSince: agent.stateSince, title: nil, detail: nil, precise: false)
        DispatchQueue.main.async {
            if let pid = host.host?.pid, pid > 0, let app = NSRunningApplication(processIdentifier: pid) {
                NSApp.yieldActivation(to: app)
            }
        }
        focus(host)
        return true
    }

    @discardableResult
    private static func shell(_ path: String, _ args: [String]) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        let out = Pipe()
        p.standardOutput = out
        p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return "" }
        let data = out.fileHandleForReading.readDataToEndOfFile()
        p.waitUntilExit()
        return String(decoding: data, as: UTF8.self)
    }

    private static func rows(_ text: String) -> [[String]] {
        text.split(separator: "\n").map { $0.split(separator: "\t", omittingEmptySubsequences: false).map(String.init) }
    }

    // MARK: iTerm2 / Terminal.app (matched by tty)

    private static func iterm(_ agent: Agent) -> Bool {
        guard let tty = agent.tty else { return false }
        return run("""
        tell application "iTerm2"
            repeat with w in windows
                repeat with t in tabs of w
                    repeat with s in sessions of t
                        if tty of s is "\(escape(tty))" then
                            select w
                            select t
                            select s
                            activate
                            return "ok"
                        end if
                    end repeat
                end repeat
            end repeat
        end tell
        """) == "ok"
    }

    private static func terminalApp(_ agent: Agent) -> Bool {
        guard let tty = agent.tty else { return false }
        return run("""
        tell application "Terminal"
            repeat with w in windows
                repeat with t in tabs of w
                    if tty of t is "\(escape(tty))" then
                        set selected of t to true
                        set index of w to 1
                        activate
                        return "ok"
                    end if
                end repeat
            end repeat
        end tell
        """) == "ok"
    }

    // MARK: AppleScript

    @discardableResult
    private static func run(_ source: String) -> String? {
        var error: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&error)
        if let error { Log.write("AppleScript failed: \(error)") }
        return error == nil ? (result?.stringValue ?? "") : nil
    }

    private static func escape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
    }
}
