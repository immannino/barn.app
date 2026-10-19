import Darwin
import Foundation

/// `barn hook <harness>`: a universal hook handler. Point any agent's hook at it; it reads the
/// event JSON on stdin, maps it to a state and writes `~/.barn/status/<agent pid>.json`.
/// Understands Claude-style events (Claude Code, Codex, Factory Droid, Qwen, Auggie, Copilot,
/// Kiro, Cline) and Gemini CLI's. Always exits 0 quickly so it never blocks the agent.
enum HookCommand {
    static func run(harness: String) -> Never {
        let input = FileHandle.standardInput.readDataToEndOfFile()
        let event = (try? JSONSerialization.jsonObject(with: input) as? [String: Any]) ?? [:]
        let pid = agentPID()
        let path = StatusFiles.dir.appendingPathComponent("\(pid).json")
        if let name = eventName(event), let state = state(for: name, event: event) {
            if state == "ended" {
                try? FileManager.default.removeItem(at: path)
            } else {
                var out: [String: Any] = ["state": state, "harness": harness, "event": name]
                if let detail = detail(event) { out["detail"] = detail }
                try? FileManager.default.createDirectory(at: StatusFiles.dir, withIntermediateDirectories: true)
                if let data = try? JSONSerialization.data(withJSONObject: out) {
                    try? data.write(to: path, options: .atomic)
                }
            }
        }
        exit(0)
    }

    static func eventName(_ e: [String: Any]) -> String? {
        (e["hook_event_name"] ?? e["hookEventName"] ?? e["event"] ?? e["type"]) as? String
    }

    static func state(for name: String, event e: [String: Any]) -> String? {
        switch name.lowercased() {
        case "permissionrequest", "elicitation", "toolpermission": return "waiting"
        case "notification":
            let type = ((e["notification_type"] ?? e["notificationType"]) as? String ?? "").lowercased()
            if type.contains("idle") { return "idle" }
            return "waiting" // permission_prompt, ToolPermission, generic "needs your attention"
        case "userpromptsubmit", "beforeagent", "pretooluse", "beforetool", "posttooluse", "aftertool",
             "posttoolusefailure", "permissiondenied", "taskstart", "taskresume", "agentstart", "pretoolcall":
            return "working"
        case "stop", "afteragent", "agentstop", "taskcomplete", "taskcancel", "subagentstop", "agent-turn-complete":
            return name.lowercased() == "subagentstop" ? nil : "idle"
        case "sessionstart": return "idle"
        case "sessionend": return "ended"
        default: return nil
        }
    }

    private static func detail(_ e: [String: Any]) -> String? {
        if let tool = (e["tool_name"] ?? e["toolName"]) as? String { return tool }
        if let message = e["message"] as? String { return String(message.prefix(80)) }
        return nil
    }

    /// The agent is the nearest ancestor that isn't a shell or launcher (hooks usually run
    /// through `sh -c`).
    private static func agentPID() -> pid_t {
        let shells: Set<String> = ["sh", "bash", "zsh", "dash", "fish", "env", "timeout", "nohup", "barn"]
        let procs = Dictionary(ProcessScanner.listProcesses().map { ($0.pid, $0) }, uniquingKeysWith: { a, _ in a })
        var pid = getppid()
        for _ in 0..<8 {
            guard let p = procs[pid] else { break }
            let name = p.comm.hasPrefix("-") ? String(p.comm.dropFirst()) : p.comm
            if !shells.contains(name) { return pid }
            pid = p.ppid
        }
        return getppid()
    }
}
