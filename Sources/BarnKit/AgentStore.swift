import AppKit
import Combine

enum AgentEvent {
    case arrived(Agent)
    case left(Agent)
    case changed(Agent, from: AgentState)
}

/// Polls the system once a second and publishes the merged agent list.
///
/// Sources, most trusted first: `~/.barn/status/<pid>.json` (anything can write it), the
/// agent's own session files (Claude Code, Mistral Vibe), then CPU activity.
@MainActor
final class AgentStore: ObservableObject {
    @Published private(set) var agents: [Agent] = []
    /// Agents coming, going and changing state. Nothing fires for the agents found by the first
    /// scan, so launching barn doesn't set off a burst of notifications and noises.
    let events = PassthroughSubject<AgentEvent, Never>()
    private var scanned = false
    /// Every agent found, before "one per window" folds any away. Events compare against this,
    /// so a hidden session isn't mistaken for a new arrival on every scan.
    private var tracked: [Agent] = []

    private let queue = DispatchQueue(label: "barn.scan", qos: .userInitiated)
    private let scanner = ProcessScanner()
    private let claude = ClaudeSessions()
    private let vibe = VibeSessions()
    private let statusFiles = StatusFiles()
    private var timer: Timer?
    /// Last time each pid's CPU was above threshold, for hysteresis.
    private var lastBusy: [pid_t: Date] = [:]
    /// Agents whose finished turn the user has already looked at.
    private var acknowledged: Set<String> = []

    private struct Snapshot {
        var found: [ProcessScanner.Found]
        var claude: [pid_t: ClaudeSessions.Session]
        var reports: [pid_t: AgentReport]
        var explicit: [pid_t: AgentReport]
    }

    func start() {
        if CommandLine.arguments.contains("--demo") { return startDemo() }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    /// Mark a finished turn as seen so it drops from "ready" to "idle".
    func acknowledge(_ agent: Agent) {
        acknowledged.insert(agent.id)
        if let i = agents.firstIndex(where: { $0.id == agent.id }), agents[i].state == .ready {
            agents[i].state = .idle
        }
        if let i = tracked.firstIndex(where: { $0.id == agent.id }), tracked[i].state == .ready {
            tracked[i].state = .idle
        }
    }

    private func refresh() {
        let kinds = Settings.shared.activeKinds
        let claudeOn = kinds.contains { $0.id == AgentKind.claude.id }
        let vibeOn = kinds.contains { $0.id == AgentKind.vibe.id }
        queue.async { [scanner, claude, vibe, statusFiles] in
            scanner.kinds = kinds
            var found = scanner.scan()
            let sessions = claudeOn ? claude.read() : [:]
            let reports = vibeOn ? vibe.read() : [:]
            // Hooks may fire from a wrapper's child (npm codex → native codex): credit the
            // nearest tracked ancestor.
            let known = Set(found.map(\.pid))
            var explicit: [pid_t: AgentReport] = [:]
            for (pid, r) in statusFiles.read() { explicit[scanner.nearest(pid, in: known) ?? pid] = r }
            // Agents not found by name: IDE-launched Claude sessions, and anything self-reporting.
            for (pid, s) in sessions where !known.contains(pid) && s.kind == "interactive" {
                if let f = scanner.describe(pid, as: .claude) { found.append(f) }
            }
            for (pid, r) in explicit where !known.contains(pid) && !found.contains(where: { $0.pid == pid }) {
                let kind = AgentKind(id: "reported", displayName: r.title ?? "agent", badge: "••", executableNames: [])
                if let f = scanner.describe(pid, as: kind) { found.append(f) }
            }
            let snapshot = Snapshot(found: found, claude: sessions, reports: reports, explicit: explicit)
            DispatchQueue.main.async { self.merge(snapshot) }
        }
    }

    private func merge(_ snap: Snapshot) {
        let previous = Dictionary(uniqueKeysWithValues: tracked.map { ($0.id, $0) })
        let now = Date()
        var next: [Agent] = []

        for f in snap.found {
            var agent = Agent(pid: f.pid, kind: f.kind, cwd: f.cwd, tty: f.tty, host: f.host,
                              state: .idle, stateSince: now, title: nil, detail: nil, precise: false)
            if f.cpu > 0.04 { lastBusy[f.pid] = now }
            let quietFor = lastBusy[f.pid].map { now.timeIntervalSince($0) } ?? .infinity

            if let s = snap.claude[f.pid] {
                apply(s, to: &agent)
            } else if let r = snap.reports[f.pid] {
                apply(r, to: &agent)
                // A tool call with no result and no CPU: almost certainly an approval prompt.
                if r.pendingTool, quietFor > 3 {
                    agent.state = .waiting
                    agent.detail = ["approve?", r.detail].compactMap { $0 }.joined(separator: " · ")
                } else if agent.state == .idle, quietFor < 4 {
                    agent.state = .working
                }
            } else {
                agent.state = quietFor < 4 ? .working : .idle
            }
            if let r = snap.explicit[f.pid] { apply(r, to: &agent) }
            if snap.claude[f.pid]?.entrypoint == "claude-vscode", f.ppid > 1 { agent.windowGroup = f.ppid }
            next.append(agent)
        }

        for i in next.indices {
            let id = next[i].id
            let prev = previous[id]
            // working → idle means a turn just finished: surface it as ready until seen.
            if next[i].state == .working || next[i].state == .waiting { acknowledged.remove(id) }
            if next[i].state == .idle, let prev, prev.state == .working || prev.state == .ready,
               !acknowledged.contains(id) {
                next[i].state = .ready
            }
            if let prev, prev.state == next[i].state {
                next[i].stateSince = prev.stateSince
            }
        }
        for agent in next {
            if let prev = previous[agent.id] {
                if prev.state != agent.state { events.send(.changed(agent, from: prev.state)) }
            } else if scanned {
                events.send(.arrived(agent))
            }
        }
        let nextIDs = Set(next.map(\.id))
        if scanned { for agent in tracked where !nextIDs.contains(agent.id) { events.send(.left(agent)) } }
        scanned = true
        let live = Set(next.map(\.pid))
        lastBusy = lastBusy.filter { live.contains($0.key) }
        acknowledged = acknowledged.filter { id in next.contains { $0.id == id } }

        tracked = next
        if Settings.shared.onePerWindow { next = Self.collapseWindows(next) }
        next.sort { ($0.state, $0.project.lowercased(), $0.pid) < ($1.state, $1.project.lowercased(), $1.pid) }
        if next != agents { agents = next }
    }

    /// One agent per VS Code window: the one that needs you most, else the most recently active.
    static func collapseWindows(_ agents: [Agent]) -> [Agent] {
        var best: [pid_t: Agent] = [:]
        var counts: [pid_t: Int] = [:]
        for a in agents {
            guard let g = a.windowGroup else { continue }
            counts[g, default: 0] += 1
            if let b = best[g], (b.state, -b.stateSince.timeIntervalSince1970) <= (a.state, -a.stateSince.timeIntervalSince1970) { continue }
            best[g] = a
        }
        return agents.compactMap { a in
            guard let g = a.windowGroup else { return a }
            guard best[g]?.pid == a.pid else { return nil }
            var rep = a
            rep.collapsed = counts[g, default: 1] - 1
            return rep
        }
    }

    private func apply(_ s: ClaudeSessions.Session, to agent: inout Agent) {
        agent.precise = true
        agent.title = s.title ?? s.name
        if !s.cwd.isEmpty { agent.cwd = s.cwd }
        agent.stateSince = s.statusUpdatedAt ?? agent.stateSince
        switch s.status {
        case "waiting":
            agent.state = .waiting
            agent.detail = [s.waitingFor, s.activity].compactMap { $0 }.joined(separator: " · ")
        case "busy":
            agent.state = .working
            agent.detail = s.activity
        default:
            agent.state = .idle
        }
    }

    private func apply(_ r: AgentReport, to agent: inout Agent) {
        if let title = r.title { agent.title = title }
        if let cwd = r.cwd, !cwd.isEmpty { agent.cwd = cwd }
        if let state = r.state {
            agent.state = state
            agent.precise = true
        }
        if let detail = r.detail { agent.detail = detail }
        if let since = r.since { agent.stateSince = since }
    }

    // MARK: Demo

    /// `--demo`: made-up agents for screenshots, no scanning.
    private func startDemo() {
        if Stress.isOn {
            agents = Stress.agents()
            demoAgents { _ in }
            Stress.run(store: self)
            return
        }
        let ghostty = HostApp(bundleID: "com.mitchellh.ghostty", name: "Ghostty", pid: 0)
        let kind = { (id: String) in AgentKind.builtIns.first { $0.id == id }! }
        let now = Date()
        func agent(_ pid: pid_t, _ k: String, _ cwd: String, _ title: String?, _ state: AgentState,
                   _ detail: String?, _ ago: TimeInterval) -> Agent {
            Agent(pid: pid, kind: kind(k), cwd: "/Users/you/code/" + cwd, tty: nil, host: ghostty, state: state,
                  stateSince: now.addingTimeInterval(-ago), title: title, detail: detail, precise: true)
        }
        // The scripted demo (Demo.swift) starts with pancake-api still working, so it can ask for you on camera.
        let pancake: AgentState = DemoScript.isOn ? .working : .waiting
        agents = [
            agent(101, "claude", "pancake-api", "Add rate limiting to checkout", pancake,
                  DemoScript.isOn ? "Bash: npm test" : "permission · Bash: npm run migrate", 42),
            agent(102, "codex", "garden", "Fix flaky watering scheduler test", .ready, nil, 180),
            agent(103, "claude", "web", "Redesign onboarding flow", .working, "Edit: Onboarding.tsx", 95),
            agent(104, "vibe", "ledger", "Daily audit query", .working, "thinking", 20),
            agent(105, "gemini", "docs", nil, .idle, nil, 3600 * 2),
            agent(106, "claude", "infra", "Terraform plan for staging", .idle, nil, 60 * 25),
        ]
        demoAgents { _ in }
    }

    /// Demo only: change the made-up agents, then sort the way `merge` does.
    func demoAgents(_ change: (inout [Agent]) -> Void) {
        var next = agents
        change(&next)
        next.sort { ($0.state, $0.project.lowercased(), $0.pid) < ($1.state, $1.project.lowercased(), $1.pid) }
        agents = next
    }
}
