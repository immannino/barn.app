import Foundation

/// What an agent's own files say about it. Any field may be missing.
struct AgentReport {
    var cwd: String?
    var title: String?
    var state: AgentState?
    var detail: String?
    var since: Date?
    /// A tool call is pending with no result yet: if the process is also quiet, it's
    /// probably sitting on an approval prompt.
    var pendingTool = false
}

/// Mistral Vibe: `~/.vibe/logs/session/active/<session>.lock` maps a pid to a session, whose
/// folder `session_<date>_<id8>/` holds `meta.json` (title, cwd) and `messages.jsonl`.
final class VibeSessions {
    private let root = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".vibe/logs/session")
    private var dirs: [String: URL] = [:]
    private var cache: [String: (mtime: Date, report: AgentReport)] = [:]

    func read() -> [pid_t: AgentReport] {
        let fm = FileManager.default
        let active = root.appendingPathComponent("active")
        guard let locks = try? fm.contentsOfDirectory(at: active, includingPropertiesForKeys: nil) else { return [:] }
        var out: [pid_t: AgentReport] = [:]
        for lock in locks where lock.pathExtension == "lock" {
            guard let data = try? Data(contentsOf: lock),
                  let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pidNum = o["process_id"] as? Int, let sid = o["session_id"] as? String else { continue }
            let pid = pid_t(pidNum)
            guard ProcessScanner.isAlive(pid), let dir = sessionDir(sid) else { continue }
            out[pid] = report(for: sid, dir: dir)
        }
        return out
    }

    private func sessionDir(_ sid: String) -> URL? {
        if let dir = dirs[sid] { return dir }
        let suffix = "_" + sid.prefix(8)
        let match = (try? FileManager.default.contentsOfDirectory(at: root, includingPropertiesForKeys: nil))?
            .first { $0.lastPathComponent.hasPrefix("session_") && $0.lastPathComponent.hasSuffix(suffix) }
        dirs[sid] = match
        return match
    }

    private func report(for sid: String, dir: URL) -> AgentReport {
        let messages = dir.appendingPathComponent("messages.jsonl")
        let mtime = fileStamp(messages)?.mtime ?? .distantPast
        if let cached = cache[sid], cached.mtime == mtime { return cached.report }

        var r = AgentReport()
        if let data = try? Data(contentsOf: dir.appendingPathComponent("meta.json")),
           let meta = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            r.title = meta["title"] as? String
            r.cwd = (meta["environment"] as? [String: Any])?["working_directory"] as? String
        }
        if let last = Self.tailObjects(messages).last {
            let role = last["role"] as? String
            let calls = last["tool_calls"] as? [[String: Any]] ?? []
            if role == "assistant", let call = calls.last {
                let fn = call["function"] as? [String: Any]
                r.state = .working
                r.detail = fn?["name"] as? String
                r.pendingTool = true
            } else if role == "user" || role == "tool" {
                r.state = .working
                r.detail = "thinking"
            } else {
                r.state = .idle
            }
        }
        cache[sid] = (mtime, r)
        return r
    }

    static func tailObjects(_ url: URL, bytes: UInt64 = 64 * 1024) -> [[String: Any]] {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return [] }
        defer { try? fh.close() }
        let size = (try? fh.seekToEnd()) ?? 0
        try? fh.seek(toOffset: size > bytes ? size - bytes : 0)
        guard let data = try? fh.readToEnd() else { return [] }
        return data.split(separator: UInt8(ascii: "\n")).compactMap {
            try? JSONSerialization.jsonObject(with: $0) as? [String: Any]
        }
    }
}

/// The universal escape hatch: anything can write `~/.barn/status/<pid>.json` with
/// `{"state": "working|waiting|idle", "detail": "…", "title": "…"}`. The pid is the agent's
/// process (from a hook, `$PPID`). Files for dead pids are cleaned up.
final class StatusFiles {
    static let dir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".barn/status")

    func read() -> [pid_t: AgentReport] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: Self.dir, includingPropertiesForKeys: [.contentModificationDateKey])
        else { return [:] }
        var out: [pid_t: AgentReport] = [:]
        for url in files where url.pathExtension == "json" {
            guard let pid = pid_t(url.deletingPathExtension().lastPathComponent) else { continue }
            guard ProcessScanner.isAlive(pid) else {
                try? fm.removeItem(at: url)
                continue
            }
            guard let data = try? Data(contentsOf: url),
                  let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { continue }
            var r = AgentReport()
            switch (o["state"] as? String)?.lowercased() {
            case "waiting", "needs_input", "approval": r.state = .waiting
            case "working", "busy", "running", "thinking": r.state = .working
            case "idle", "done", "ready": r.state = .idle
            default: break
            }
            r.detail = o["detail"] as? String
            r.title = o["title"] as? String
            r.since = try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate
            out[pid] = r
        }
        return out
    }
}
