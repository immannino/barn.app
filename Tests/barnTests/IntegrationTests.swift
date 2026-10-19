@testable import BarnKit
import XCTest

final class IntegrationTests: XCTestCase {
    private var home: URL!
    private let cmd = "'/Applications/barn.app/Contents/MacOS/barn' hook codex"

    override func setUpWithError() throws {
        home = FileManager.default.temporaryDirectory.appendingPathComponent("barn-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
        Integration.home = home
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: home)
        Integration.home = FileManager.default.homeDirectoryForCurrentUser
    }

    private var codex: Integration { Integration.all.first { $0.id == "codex" }! }

    private func write(_ json: String, to path: String) throws {
        let url = home.appendingPathComponent(path)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try json.write(to: url, atomically: true, encoding: .utf8)
    }

    private func read(_ path: String) throws -> [String: Any] {
        try JSONSerialization.jsonObject(with: Data(contentsOf: home.appendingPathComponent(path))) as! [String: Any]
    }

    func testToolMissing() {
        XCTAssertEqual(codex.status(), .toolMissing)
    }

    func testInstallPreservesOtherHooksAndBacksUp() throws {
        try write(#"{"theme":"dark","hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#,
                  to: ".codex/hooks.json")
        XCTAssertEqual(codex.status(), .notInstalled)
        try codex.install(command: cmd)
        XCTAssertEqual(codex.status(), .installed)

        let root = try read(".codex/hooks.json")
        XCTAssertEqual(root["theme"] as? String, "dark")
        let stop = (root["hooks"] as! [String: Any])["Stop"] as! [[String: Any]]
        XCTAssertEqual(stop.count, 2, "user's own Stop hook is kept")
        let permission = (root["hooks"] as! [String: Any])["PermissionRequest"] as! [[String: Any]]
        XCTAssertEqual(permission.first?["matcher"] as? String, "*")
        XCTAssertTrue(FileManager.default.fileExists(atPath: home.appendingPathComponent(".codex/hooks.json.barn-backup").path))
    }

    func testInstallIsIdempotentAndUninstallIsExact() throws {
        try write(#"{"hooks":{"Stop":[{"hooks":[{"type":"command","command":"say done"}]}]}}"#, to: ".codex/hooks.json")
        try codex.install(command: cmd)
        try codex.install(command: cmd)
        var hooks = try read(".codex/hooks.json")["hooks"] as! [String: Any]
        XCTAssertEqual((hooks["Stop"] as! [Any]).count, 2, "reinstalling doesn't duplicate")

        try codex.uninstall()
        hooks = try read(".codex/hooks.json")["hooks"] as! [String: Any]
        XCTAssertEqual(Array(hooks.keys), ["Stop"])
        let remaining = ((hooks["Stop"] as! [[String: Any]])[0]["hooks"] as! [[String: Any]])[0]["command"] as? String
        XCTAssertEqual(remaining, "say done")
        XCTAssertEqual(codex.status(), .notInstalled)
    }

    func testRefusesNonJSONConfig() throws {
        try write("{ // comments aren't JSON\n }", to: ".codex/hooks.json")
        XCTAssertEqual(codex.status(), .unreadable)
        XCTAssertThrowsError(try codex.install(command: cmd))
        XCTAssertEqual(try String(contentsOf: home.appendingPathComponent(".codex/hooks.json"), encoding: .utf8),
                       "{ // comments aren't JSON\n }", "file untouched")
    }

    func testCopilotOwnsItsFile() throws {
        let copilot = Integration.all.first { $0.id == "copilot" }!
        try FileManager.default.createDirectory(at: home.appendingPathComponent(".copilot"), withIntermediateDirectories: true)
        try copilot.install(command: "'/x/barn' hook copilot")
        let root = try read(".copilot/hooks/barn.json")
        XCTAssertEqual(root["version"] as? Int, 1)
        XCTAssertEqual(((root["hooks"] as! [String: Any])["agentStop"] as! [[String: Any]])[0]["bash"] as? String,
                       "'/x/barn' hook copilot")
        try copilot.uninstall()
        XCTAssertFalse(FileManager.default.fileExists(atPath: home.appendingPathComponent(".copilot/hooks/barn.json").path))
    }

    func testKeyComboDisplay() {
        XCTAssertEqual(KeyCombo.switcherDefault.display, "⌃⌥Space")
    }
}
