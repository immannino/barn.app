@testable import BarnKit
import XCTest

final class ClassifyTests: XCTestCase {
    private func kind(_ args: [String]) -> String? {
        ProcessScanner.classify(args: args, kinds: AgentKind.builtIns)?.id
    }

    func testNativeBinaries() {
        XCTAssertEqual(kind(["claude"]), "claude")
        XCTAssertEqual(kind(["/Users/me/.local/share/claude/versions/2.1.303"]), nil, "argv[0] is what we match, not the exec path")
        XCTAssertEqual(kind(["/opt/homebrew/bin/codex", "--full-auto"]), "codex")
        XCTAssertEqual(kind(["cursor-agent"]), "cursor")
        XCTAssertEqual(kind(["kiro-cli-chat"]), "kiro")
    }

    func testInterpreterLaunchedCLIs() {
        XCTAssertEqual(kind(["node", "/usr/local/lib/node_modules/@openai/codex/bin/codex.js"]), "codex")
        XCTAssertEqual(kind(["node", "/Users/me/.nvm/versions/node/v24/bin/gemini"]), "gemini")
        XCTAssertEqual(kind(["node", "--no-warnings", "/x/node_modules/@google/gemini-cli/dist/index.js"]), "gemini")
        XCTAssertEqual(kind(["/Users/me/.local/share/uv/tools/mistral-vibe/bin/python3", "/Users/me/.local/bin/vibe"]), "vibe")
        XCTAssertEqual(kind(["python3.12", "-m", "aider"]), "aider")
        XCTAssertEqual(kind(["bun", "/x/@sourcegraph/amp/dist/main.js"]), "amp")
    }

    func testNonAgents() {
        XCTAssertNil(kind(["node", "server.js"]))
        XCTAssertNil(kind(["-zsh"]))
        XCTAssertNil(kind(["vim", "claude.md"]), "only interpreters look past argv[0]")
        XCTAssertNil(kind([]))
    }

    func testCustomKindsAndDisabling() {
        let custom = AgentKind(id: "custom-x", displayName: "Mine", badge: "MI", executableNames: ["my-agent"], builtIn: false)
        XCTAssertEqual(ProcessScanner.classify(args: ["my-agent"], kinds: [custom])?.id, "custom-x")
        XCTAssertNil(ProcessScanner.classify(args: ["claude"], kinds: [custom]), "disabled built-ins aren't matched")
    }
}
