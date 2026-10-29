import AppKit

/// A kind of agent CLI and how to recognize its process. Built-ins below; users can add
/// their own in Settings → Agents.
struct AgentKind: Hashable, Codable, Identifiable {
    var id: String
    var displayName: String
    /// Two-letter badge for deck tiles.
    var badge: String
    /// Executable basenames (argv[0], or the script for interpreter-launched CLIs).
    var executableNames: [String]
    /// argv fragments that identify a CLI run under node/bun/python (npm package paths, …).
    var packageFragments: [String] = []
    var builtIn = true

    static let claude = AgentKind(id: "claude", displayName: "Claude Code", badge: "CC",
                                  executableNames: ["claude"], packageFragments: ["@anthropic-ai/claude-code"])
    static let vibe = AgentKind(id: "vibe", displayName: "Mistral Vibe", badge: "MV",
                                executableNames: ["vibe", "mistral-vibe"], packageFragments: ["mistral-vibe"])

    static let builtIns: [AgentKind] = [
        .claude,
        AgentKind(id: "codex", displayName: "Codex", badge: "CX",
                  executableNames: ["codex"], packageFragments: ["@openai/codex"]),
        AgentKind(id: "gemini", displayName: "Gemini", badge: "GM",
                  executableNames: ["gemini"], packageFragments: ["@google/gemini-cli"]),
        .vibe,
        AgentKind(id: "opencode", displayName: "opencode", badge: "OC",
                  executableNames: ["opencode"], packageFragments: ["opencode-ai"]),
        AgentKind(id: "amp", displayName: "Amp", badge: "AM",
                  executableNames: ["amp"], packageFragments: ["@sourcegraph/amp"]),
        AgentKind(id: "cursor", displayName: "Cursor Agent", badge: "CU", executableNames: ["cursor-agent"]),
        AgentKind(id: "copilot", displayName: "Copilot", badge: "GH",
                  executableNames: ["copilot"], packageFragments: ["@github/copilot"]),
        AgentKind(id: "aider", displayName: "Aider", badge: "AD", executableNames: ["aider"]),
        AgentKind(id: "goose", displayName: "Goose", badge: "GO", executableNames: ["goose"]),
        AgentKind(id: "crush", displayName: "Crush", badge: "CR", executableNames: ["crush"]),
        AgentKind(id: "qwen", displayName: "Qwen Code", badge: "QW",
                  executableNames: ["qwen"], packageFragments: ["@qwen-code/qwen-code"]),
        AgentKind(id: "droid", displayName: "Factory Droid", badge: "FD", executableNames: ["droid"]),
        AgentKind(id: "kiro", displayName: "Kiro", badge: "KI", executableNames: ["kiro-cli", "kiro-cli-chat"]),
        AgentKind(id: "cline", displayName: "Cline", badge: "CL", executableNames: ["cline"], packageFragments: ["/cline/"]),
        AgentKind(id: "auggie", displayName: "Auggie", badge: "AU",
                  executableNames: ["auggie"], packageFragments: ["@augmentcode/auggie"]),
        AgentKind(id: "kimi", displayName: "Kimi", badge: "KM", executableNames: ["kimi"]),
        AgentKind(id: "pi", displayName: "Pi", badge: "PI",
                  executableNames: ["pi"], packageFragments: ["@mariozechner/pi-coding-agent"]),
        AgentKind(id: "kilo", displayName: "Kilo", badge: "KL", executableNames: ["kilo"], packageFragments: ["@kilocode/cli"]),
        AgentKind(id: "antigravity", displayName: "Antigravity", badge: "AG", executableNames: ["agy"]),
    ]
}

enum AgentState: Int, Comparable {
    /// Blocked on the human: permission prompt, question, dialog.
    case waiting = 0
    /// Finished a turn you haven't looked at yet.
    case ready = 1
    case working = 2
    case idle = 3

    static func < (a: AgentState, b: AgentState) -> Bool { a.rawValue < b.rawValue }

    var label: String {
        switch self {
        case .waiting: "needs you"
        case .ready: "ready"
        case .working: "working"
        case .idle: "idle"
        }
    }

    /// From the active look (settings → looks).
    @MainActor var color: NSColor { Settings.shared.activeLook.style(for: self).nsColor }

    @MainActor var style: StateStyle { Settings.shared.activeLook.style(for: self) }
}

/// The app hosting an agent's terminal (Ghostty, iTerm2, VS Code, …).
struct HostApp: Equatable {
    var bundleID: String?
    var name: String
    var pid: pid_t
    /// Set when the agent runs inside tmux; the host app is then unknown.
    var viaTmux = false
}

struct Agent: Identifiable, Equatable {
    var id: String { "\(pid)" }
    var pid: pid_t
    var kind: AgentKind
    var cwd: String
    var tty: String?
    var host: HostApp?
    var state: AgentState
    var stateSince: Date
    /// Human title: Claude's ai/custom title, or nil.
    var title: String?
    /// What it's doing right now ("Bash: npm test", "permission", …).
    var detail: String?
    /// Whether state comes from the agent itself (true) or a CPU heuristic.
    var precise: Bool
    /// The VS Code window (extension host process) a Claude session belongs to, for grouping.
    var windowGroup: pid_t?
    /// Other sessions in the same window folded into this one (Settings → one agent per window).
    var collapsed = 0

    var project: String { (cwd as NSString).lastPathComponent }
    var displayTitle: String { title ?? project }
}

extension TimeInterval {
    /// Minute resolution ("<1m", "4m", "2h") for surfaces that shouldn't redraw every second.
    var coarse: String { self < 60 ? "<1m" : compact }

    var compact: String {
        let s = Int(self)
        if s < 60 { return "\(s)s" }
        if s < 3600 { return "\(s / 60)m" }
        if s < 86400 { return "\(s / 3600)h" }
        return "\(s / 86400)d"
    }
}
