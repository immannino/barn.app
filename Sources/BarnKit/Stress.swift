import AppKit

/// `--demo --stress`: a worst case for the perf test (scripts/perf.sh). Two dozen made-up agents
/// with titles long enough to scroll in the list layout, a look with every effect on every
/// state, and an agent changing state every quarter second, so a regression in rendering or
/// re-layout shows up as CPU. Runs until quit.
@MainActor
enum Stress {
    static var isOn: Bool { CommandLine.arguments.contains("--stress") }
    private static var timer: Timer?

    static let look: Look = {
        let all = Effect.allCases
        return Look(name: "stress", author: "barn",
                    waiting: StateStyle(color: "#FF5C61", tint: 0.32, effects: all, speed: 3, intensity: 1),
                    ready: StateStyle(color: "#3DDB99", tint: 0.7, effects: all, speed: 3, intensity: 1),
                    working: StateStyle(color: "#334DFF", tint: 0.26, effects: all, speed: 3, intensity: 1),
                    idle: StateStyle(color: "#8E8E93", tint: 0.1, effects: all, speed: 3, intensity: 1))
    }()

    static func agents() -> [Agent] {
        let host = HostApp(bundleID: "com.mitchellh.ghostty", name: "Ghostty", pid: 0)
        let kinds = ["claude", "codex", "gemini", "vibe"].compactMap { id in AgentKind.builtIns.first { $0.id == id } }
        let states = AgentState.allCases
        let now = Date()
        return (0..<24).map { i in
            Agent(pid: pid_t(1000 + i), kind: kinds[i % kinds.count], cwd: "/Users/you/code/project-\(i)",
                  tty: nil, host: host, state: states[i % states.count], stateSince: now.addingTimeInterval(-Double(i * 97)),
                  title: "Stress agent \(i) with a title long enough to overflow its row", detail: detail(i, 0),
                  precise: true)
        }
    }

    /// Moves one agent to its next state every 0.25 s, round robin.
    static func run(store: AgentStore) {
        var tick = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { _ in
            MainActor.assumeIsolated {
                tick += 1
                let states = AgentState.allCases
                store.demoAgents { agents in
                    guard !agents.isEmpty else { return }
                    let i = tick % agents.count
                    let next = states[(states.firstIndex(of: agents[i].state)! + 1) % states.count]
                    agents[i].state = next
                    agents[i].detail = detail(i, tick)
                    agents[i].stateSince = Date()
                }
            }
        }
    }

    private static func detail(_ i: Int, _ tick: Int) -> String {
        "Bash: npm run test -- --shard \(tick % 8)/8 packages/service-\(i)/src/handlers"
    }
}
