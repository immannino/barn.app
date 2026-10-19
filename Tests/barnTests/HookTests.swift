@testable import BarnKit
import XCTest

final class HookTests: XCTestCase {
    private func state(_ event: [String: Any]) -> String? {
        guard let name = HookCommand.eventName(event) else { return nil }
        return HookCommand.state(for: name, event: event)
    }

    func testClaudeStyleEvents() {
        XCTAssertEqual(state(["hook_event_name": "UserPromptSubmit"]), "working")
        XCTAssertEqual(state(["hook_event_name": "PreToolUse", "tool_name": "Bash"]), "working")
        XCTAssertEqual(state(["hook_event_name": "PermissionRequest"]), "waiting")
        XCTAssertEqual(state(["hook_event_name": "Notification", "notification_type": "permission_prompt"]), "waiting")
        XCTAssertEqual(state(["hook_event_name": "Notification", "notification_type": "idle_prompt"]), "idle")
        XCTAssertEqual(state(["hook_event_name": "Stop"]), "idle")
        XCTAssertEqual(state(["hook_event_name": "SessionEnd"]), "ended")
        XCTAssertNil(state(["hook_event_name": "SubagentStop"]), "a subagent finishing doesn't end the parent's turn")
    }

    func testGeminiAndCopilotEvents() {
        XCTAssertEqual(state(["hook_event_name": "BeforeAgent"]), "working")
        XCTAssertEqual(state(["hook_event_name": "Notification", "notification_type": "ToolPermission"]), "waiting")
        XCTAssertEqual(state(["hook_event_name": "AfterAgent"]), "idle")
        XCTAssertEqual(state(["hookEventName": "agentStop"]), "idle")
    }

    func testUnknownEventsAreIgnored() {
        XCTAssertNil(state(["hook_event_name": "PreCompact"]))
        XCTAssertNil(state([:]))
    }
}
