import Foundation

/// Claude Code writes `~/.claude/sessions/<pid>.json` for every interactive session and
/// keeps `status` (busy / idle / waiting) current. That gives precise state with zero setup.
/// The transcript JSONL adds the session title and the tool currently running.
final class ClaudeSessions {
    struct Session {
        var pid: pid_t
        var sessionID: String
        var cwd: String
        var name: String?
        var status: String
        var waitingFor: String?
        var statusUpdatedAt: Date?
        var kind: String?
        /// Who launched it: "claude-vscode" for the VS Code extension, "cli" for a terminal.
        var entrypoint: String?
        /// From the transcript.
        var title: String?
        var activity: String?
    }

    private struct TranscriptMeta {
        var size: UInt64
        var mtime: Date
        var title: String?
        var activity: String?
    }

    private let home = FileManager.default.homeDirectoryForCurrentUser
    private var sessionsDir: URL { home.appendingPathComponent(".claude/sessions") }
    private var projectsDir: URL { home.appendingPathComponent(".claude/projects") }
    private var transcriptPaths: [String: URL] = [:]
    private var transcriptMeta: [String: TranscriptMeta] = [:]

    /// Live sessions keyed by pid.
    func read() -> [pid_t: Session] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: sessionsDir, includingPropertiesForKeys: nil) else { return [:] }
        var out: [pid_t: Session] = [:]
        for url in files where url.pathExtension == "json" {
            guard let data = try? Data(contentsOf: url),
                  let o = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let pidNum = o["pid"] as? Int, let sid = o["sessionId"] as? String else { continue }
            let pid = pid_t(pidNum)
            guard ProcessScanner.isAlive(pid) else { continue }
            var s = Session(
                pid: pid, sessionID: sid,
                cwd: o["cwd"] as? String ?? "",
                name: o["name"] as? String,
                status: o["status"] as? String ?? "idle",
                waitingFor: o["waitingFor"] as? String,
                statusUpdatedAt: (o["statusUpdatedAt"] as? Double).map { Date(timeIntervalSince1970: $0 / 1000) },
                kind: o["kind"] as? String,
                entrypoint: o["entrypoint"] as? String
            )
            if let meta = transcript(for: sid) {
                s.title = meta.title
                s.activity = meta.activity
            }
            out[pid] = s
        }
        let liveIDs = Set(out.values.map(\.sessionID))
        transcriptMeta = transcriptMeta.filter { liveIDs.contains($0.key) }
        return out
    }

    // MARK: Transcript

    private func transcript(for sid: String) -> TranscriptMeta? {
        guard let url = transcriptURL(for: sid), let (size, mtime) = fileStamp(url) else { return nil }
        if let cached = transcriptMeta[sid], cached.size == size, cached.mtime == mtime { return cached }
        var meta = TranscriptMeta(size: size, mtime: mtime)
        parseTail(url, size: size, into: &meta)
        transcriptMeta[sid] = meta
        return meta
    }

    private func transcriptURL(for sid: String) -> URL? {
        if let url = transcriptPaths[sid] { return url }
        let fm = FileManager.default
        guard let dirs = try? fm.contentsOfDirectory(at: projectsDir, includingPropertiesForKeys: nil) else { return nil }
        for dir in dirs {
            let candidate = dir.appendingPathComponent("\(sid).jsonl")
            if fm.fileExists(atPath: candidate.path) {
                transcriptPaths[sid] = candidate
                return candidate
            }
        }
        return nil
    }

    private func parseTail(_ url: URL, size: UInt64, into meta: inout TranscriptMeta) {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return }
        defer { try? fh.close() }
        let tail: UInt64 = 256 * 1024
        try? fh.seek(toOffset: size > tail ? size - tail : 0)
        guard let data = try? fh.readToEnd() else { return }
        var customTitle: String?
        var aiTitle: String?
        var activity: String?
        var activityDone = false

        for line in data.split(separator: UInt8(ascii: "\n")).reversed() {
            if (customTitle != nil || aiTitle != nil), activityDone { break }
            guard let o = try? JSONSerialization.jsonObject(with: line) as? [String: Any],
                  let type = o["type"] as? String else { continue }
            switch type {
            case "custom-title": if customTitle == nil { customTitle = o["customTitle"] as? String }
            case "ai-title": if aiTitle == nil { aiTitle = o["aiTitle"] as? String }
            case "assistant" where !activityDone:
                let content = (o["message"] as? [String: Any])?["content"] as? [[String: Any]] ?? []
                if let tool = content.last(where: { $0["type"] as? String == "tool_use" }) {
                    activity = Self.describe(tool: tool)
                } else {
                    activity = "responding"
                }
                activityDone = true
            case "user" where !activityDone:
                activity = "thinking"
                activityDone = true
            default: break
            }
        }
        meta.title = customTitle ?? aiTitle
        meta.activity = activity
    }

    private static func describe(tool: [String: Any]) -> String {
        let name = tool["name"] as? String ?? "tool"
        let input = tool["input"] as? [String: Any] ?? [:]
        let arg: String? = {
            if let d = input["description"] as? String { return d }
            if let c = input["command"] as? String { return c }
            if let p = input["file_path"] as? String { return (p as NSString).lastPathComponent }
            if let p = input["pattern"] as? String { return p }
            if let u = input["url"] as? String { return u }
            return nil
        }()
        let short = name.hasPrefix("mcp__") ? String(name.split(separator: "__").last ?? "mcp") : name
        guard let arg, !arg.isEmpty else { return short }
        let oneLine = arg.replacingOccurrences(of: "\n", with: " ")
        return "\(short): \(oneLine.prefix(60))"
    }
}

/// Size + mtime via stat(2). FileManager.attributesOfItem is ~10× the cost, which adds up
/// when polled every second.
func fileStamp(_ url: URL) -> (size: UInt64, mtime: Date)? {
    var st = stat()
    guard stat(url.path, &st) == 0 else { return nil }
    let t = st.st_mtimespec
    return (UInt64(st.st_size), Date(timeIntervalSince1970: TimeInterval(t.tv_sec) + TimeInterval(t.tv_nsec) / 1e9))
}
