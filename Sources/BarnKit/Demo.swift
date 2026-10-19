import AppKit
import SwiftUI

/// `--demo --demo-script [--demo-rect <file>]`: a ~17 s scripted story with the made-up demo
/// agents, for recording marketing video (scripts/record-demo.sh). Plays the same every time,
/// needs no input, and quits when done. A full-screen brand backdrop covers everything else on
/// screen, so takes look the same and nothing personal ends up in the video.
///
///   0s  deck up, four agents working     4s  pancake-api needs you
///   2s  ledger finishes                  6s  ⌃⌥Space, 7.5s type "pan", 9.5s ↵
///  10s  pancake-api back to work        12s  web finishes, 17s quit
@MainActor
enum DemoScript {
    static var isOn: Bool { CommandLine.arguments.contains("--demo-script") }
    private static var backdrop: NSWindow?

    static func run(store: AgentStore, launcher: LauncherController, deck: DeckController) {
        let args = CommandLine.arguments
        let rectFile = args.firstIndex(of: "--demo-rect").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }

        // Park the pointer at the left edge of the main display: out of frame, off any tooltip,
        // and the switcher opens on the display the pointer is on.
        let main = CGDisplayBounds(CGMainDisplayID())
        CGWarpMouseCursorPosition(CGPoint(x: main.minX + 8, y: main.midY))
        backdrop = makeBackdrop()
        backdrop?.orderFrontRegardless()
        at(0.3) { deck.show() }
        at(2.0) { store.demoUpdate(104, .ready) }
        at(4.0) { store.demoUpdate(101, .waiting, "permission · Bash: npm run migrate") }
        at(6.0) { launcher.show() }
        // Measured with the full list showing, so the crop fits the switcher at its tallest.
        at(6.2) { if let rectFile { writeRect(launcher.frame, deck.frame, to: rectFile) } }
        for (i, prefix) in ["p", "pa", "pan"].enumerated() {
            at(7.5 + Double(i) * 0.3) { launcher.demoType(prefix) }
        }
        at(9.5) { launcher.demoOpenSelected() }
        at(10.0) { store.demoUpdate(101, .working, "Bash: npm run migrate") }
        at(12.0) { store.demoUpdate(103, .ready) }
        at(17.0) { NSApp.terminate(nil) }
    }

    /// Above other apps' windows, below the deck (.floating) and switcher (.modalPanel).
    private static func makeBackdrop() -> NSWindow? {
        guard let screen = NSScreen.main else { return nil }
        let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        window.level = NSWindow.Level(NSWindow.Level.normal.rawValue + 1)
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.ignoresMouseEvents = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: BrandBackdrop().ignoresSafeArea())
        window.setFrame(screen.frame, display: false)
        return window
    }

    private static func at(_ seconds: Double, _ action: @escaping @MainActor () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { action() }
    }

    /// The switcher + deck area in screen pixels, top-left origin (what ffmpeg's crop wants):
    /// "x y width height".
    private static func writeRect(_ a: NSRect, _ b: NSRect?, to path: String) {
        guard let screen = NSScreen.main else { return }
        let r = b.map { a.union($0) } ?? a
        let scale = screen.backingScaleFactor
        let x = (r.minX - screen.frame.minX) * scale
        let y = (screen.frame.maxY - r.maxY) * scale
        let line = [x, y, r.width * scale, r.height * scale].map { String(Int($0.rounded())) }.joined(separator: " ")
        try? (line + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }
}

extension AgentStore {
    /// Demo only: move a made-up agent to a new state, re-sorted like a real refresh.
    func demoUpdate(_ pid: pid_t, _ state: AgentState, _ detail: String? = nil) {
        demoAgents { agents in
            guard let i = agents.firstIndex(where: { $0.pid == pid }) else { return }
            agents[i].state = state
            agents[i].detail = detail
            agents[i].stateSince = Date()
        }
    }
}
