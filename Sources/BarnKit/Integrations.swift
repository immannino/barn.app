import Foundation

/// One-click setup of `barn hook <harness>` in other agents' hook configs.
///
/// Edits are merges: unrelated settings and other hooks are preserved, a `.barn-backup` copy
/// is written before the first change, and files that don't parse as JSON are left alone.
/// barn's entries are recognized by their command (`… hook <id>`), so removal is exact.
struct Integration: Identifiable {
    enum Format {
        /// `{"hooks": {"Event": [{"matcher": "*", "hooks": [{"type": "command", "command": …}]}]}}`
        /// — Claude Code's schema, adopted by Codex, Gemini, Factory, Qwen and Auggie.
        case claudeStyle
        /// `{"version": 1, "hooks": {"event": [{"type": "command", "bash": …}]}}` in a file barn owns.
        case copilot
    }

    var id: String
    var name: String
    /// Relative to the home directory.
    var configPath: String
    /// Folder whose existence means the tool is installed.
    var homeDir: String
    var format: Format
    var events: [String]
    /// Events whose entries need `"matcher": "*"` to fire for every tool.
    var matcherEvents: Set<String> = []

    static let all: [Integration] = [
        Integration(id: "codex", name: "Codex", configPath: ".codex/hooks.json", homeDir: ".codex",
                    format: .claudeStyle, events: ["UserPromptSubmit", "PermissionRequest", "Stop", "SessionEnd"],
                    matcherEvents: ["PermissionRequest"]),
        Integration(id: "gemini", name: "Gemini CLI", configPath: ".gemini/settings.json", homeDir: ".gemini",
                    format: .claudeStyle, events: ["BeforeAgent", "Notification", "AfterAgent", "SessionEnd"],
                    matcherEvents: ["Notification"]),
        Integration(id: "droid", name: "Factory Droid", configPath: ".factory/settings.json", homeDir: ".factory",
                    format: .claudeStyle, events: ["UserPromptSubmit", "Notification", "Stop", "SessionEnd"]),
        Integration(id: "qwen", name: "Qwen Code", configPath: ".qwen/settings.json", homeDir: ".qwen",
                    format: .claudeStyle, events: ["UserPromptSubmit", "Notification", "Stop", "SessionEnd"]),
        Integration(id: "auggie", name: "Auggie", configPath: ".augment/settings.json", homeDir: ".augment",
                    format: .claudeStyle, events: ["PreToolUse", "Stop", "SessionEnd"]),
        Integration(id: "copilot", name: "Copilot CLI", configPath: ".copilot/hooks/barn.json", homeDir: ".copilot",
                    format: .copilot, events: ["userPromptSubmitted", "preToolUse", "agentStop"]),
    ]

    enum Status: Equatable { case notInstalled, installed, partial, toolMissing, unreadable }

    struct Failure: LocalizedError {
        var message: String
        var errorDescription: String? { message }
    }

    // MARK: Paths & command

    static var home = FileManager.default.homeDirectoryForCurrentUser

    var configURL: URL { Self.home.appendingPathComponent(configPath) }

    /// The hook command, pointing at this binary by absolute path so PATH doesn't matter.
    static func command(for id: String, executable: String = Bundle.main.executablePath ?? "barn") -> String {
        "'\(executable.replacingOccurrences(of: "'", with: "'\\''"))' hook \(id)"
    }

    private func isOurs(_ handler: [String: Any]) -> Bool {
        let cmd = (handler["command"] ?? handler["bash"]) as? String ?? ""
        return cmd.hasSuffix(" hook \(id)") && cmd.contains("barn")
    }

    // MARK: Status / install / remove

    func status() -> Status {
        let fm = FileManager.default
        guard fm.fileExists(atPath: Self.home.appendingPathComponent(homeDir).path) else { return .toolMissing }
        guard fm.fileExists(atPath: configURL.path) else { return .notInstalled }
        guard let root = try? readJSON() else { return .unreadable }
        let present = events.filter { !(handlers(in: root, event: $0).filter(isOurs).isEmpty) }
        if present.isEmpty { return .notInstalled }
        return present.count == events.count ? .installed : .partial
    }

    func install(command: String? = nil) throws {
        let cmd = command ?? Self.command(for: id)
        var root = try readJSON() ?? [:]
        try backup()
        root = Self.removing(from: root, format: format, isOurs: isOurs)
        root = merged(into: root, command: cmd)
        try write(root)
    }

    func uninstall() throws {
        guard var root = try readJSON() else { return }
        root = Self.removing(from: root, format: format, isOurs: isOurs)
        if case .copilot = format, (root["hooks"] as? [String: Any])?.isEmpty ?? true {
            try? FileManager.default.removeItem(at: configURL)
            return
        }
        try write(root)
    }

    /// If barn.app moved since the hooks were installed, re-point them at this binary.
    func repairIfMoved() {
        guard status() == .installed || status() == .partial, let root = try? readJSON() else { return }
        let current = Self.command(for: id)
        let stale = events.flatMap { handlers(in: root, event: $0) }.filter(isOurs)
            .contains { (($0["command"] ?? $0["bash"]) as? String) != current }
        if stale {
            do {
                try install()
                Log.write("re-pointed \(id) hooks at \(current)")
            } catch {
                Log.write("couldn't repair \(id) hooks: \(error)")
            }
        }
    }

    // MARK: JSON merge (pure; unit-tested)

    func merged(into root: [String: Any], command: String) -> [String: Any] {
        var root = root
        var hooks = root["hooks"] as? [String: Any] ?? [:]
        for event in events {
            var list = hooks[event] as? [Any] ?? []
            switch format {
            case .claudeStyle:
                var entry: [String: Any] = ["hooks": [["type": "command", "command": command, "timeout": 5]]]
                if matcherEvents.contains(event) { entry["matcher"] = "*" }
                list.append(entry)
            case .copilot:
                list.append(["type": "command", "bash": command, "timeoutSec": 5])
            }
            hooks[event] = list
        }
        root["hooks"] = hooks
        if case .copilot = format, root["version"] == nil { root["version"] = 1 }
        return root
    }

    static func removing(from root: [String: Any], format: Format, isOurs: ([String: Any]) -> Bool) -> [String: Any] {
        var root = root
        guard var hooks = root["hooks"] as? [String: Any] else { return root }
        for (event, value) in hooks {
            guard let list = value as? [Any] else { continue }
            var kept: [Any] = []
            for item in list {
                guard var entry = item as? [String: Any] else { kept.append(item); continue }
                switch format {
                case .claudeStyle:
                    let inner = (entry["hooks"] as? [[String: Any]] ?? []).filter { !isOurs($0) }
                    if inner.isEmpty, entry["hooks"] != nil { continue }
                    entry["hooks"] = inner
                    kept.append(entry)
                case .copilot:
                    if !isOurs(entry) { kept.append(entry) }
                }
            }
            if kept.isEmpty { hooks.removeValue(forKey: event) } else { hooks[event] = kept }
        }
        root["hooks"] = hooks.isEmpty ? nil : hooks
        return root
    }

    private func handlers(in root: [String: Any], event: String) -> [[String: Any]] {
        let list = (root["hooks"] as? [String: Any])?[event] as? [[String: Any]] ?? []
        switch format {
        case .claudeStyle: return list.flatMap { $0["hooks"] as? [[String: Any]] ?? [] }
        case .copilot: return list
        }
    }

    // MARK: File IO

    /// nil if the file doesn't exist; throws if it exists but isn't a JSON object.
    private func readJSON() throws -> [String: Any]? {
        guard let data = try? Data(contentsOf: configURL) else { return nil }
        if data.allSatisfy({ $0 == 0x20 || $0 == 0x0A || $0 == 0x09 || $0 == 0x0D }) { return [:] }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw Failure(message: "\(configPath) isn't plain JSON (comments?), so barn left it alone")
        }
        return root
    }

    private func backup() throws {
        let fm = FileManager.default
        let backup = configURL.appendingPathExtension("barn-backup")
        if fm.fileExists(atPath: configURL.path), !fm.fileExists(atPath: backup.path) {
            try fm.copyItem(at: configURL, to: backup)
        }
    }

    private func write(_ root: [String: Any]) throws {
        try FileManager.default.createDirectory(at: configURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes])
        try (data + Data("\n".utf8)).write(to: configURL, options: .atomic)
    }
}
