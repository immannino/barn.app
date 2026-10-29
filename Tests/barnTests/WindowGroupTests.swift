@testable import BarnKit
import XCTest

@MainActor
final class WindowGroupTests: XCTestCase {
    private func agent(_ pid: pid_t, _ state: AgentState, ago: TimeInterval, window: pid_t?) -> Agent {
        Agent(pid: pid, kind: .claude, cwd: "/code/app", tty: nil, host: nil, state: state,
              stateSince: Date(timeIntervalSince1970: 1000 - ago), title: nil, detail: nil, precise: true,
              windowGroup: window)
    }

    func testOnePerWindow() {
        let out = AgentStore.collapseWindows([
            agent(1, .idle, ago: 500, window: 10),
            agent(2, .working, ago: 50, window: 10),
            agent(3, .idle, ago: 100, window: 10),
            agent(4, .idle, ago: 10, window: 20),
            agent(5, .idle, ago: 10, window: nil),
            agent(6, .idle, ago: 20, window: nil),
        ])
        XCTAssertEqual(out.map(\.pid).sorted(), [2, 4, 5, 6])
        XCTAssertEqual(out.first { $0.pid == 2 }?.collapsed, 2)
        XCTAssertEqual(out.first { $0.pid == 4 }?.collapsed, 0)
    }

    func testIdleTieGoesToMostRecent() {
        let out = AgentStore.collapseWindows([
            agent(1, .idle, ago: 500, window: 10),
            agent(2, .idle, ago: 5, window: 10),
        ])
        XCTAssertEqual(out.map(\.pid), [2])
    }
}
