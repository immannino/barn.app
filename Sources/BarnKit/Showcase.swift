import AppKit
import SwiftUI

/// `--demo --showcase <group> [--showcase-rect <file>] [--showcase-seconds <n>]`: one group of
/// looks ("glass", "terminals", "desktops", "whimsy", "friends") as the settings previews, stacked
/// over the brand backdrop, for recording GIFs (scripts/record-looks.sh). Covers the whole screen,
/// menu bar included, and quits when done.
@MainActor
enum Showcase {
    private static var window: NSWindow?
    private static let spacing: CGFloat = 8
    private static let margin: CGFloat = 24

    static var group: String? {
        let args = CommandLine.arguments
        return args.firstIndex(of: "--showcase").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
    }

    static var groups: [(name: String, looks: [Look])] {
        [("glass", Look.presets.filter { $0.skin == nil })] + Look.allSkinGroups
    }

    static func run() {
        guard let name = group, let looks = groups.first(where: { $0.name == name })?.looks,
              let screen = NSScreen.main else {
            Log.write("--showcase: no group named \(group ?? "") (try \(groups.map(\.name).joined(separator: ", ")))")
            return NSApp.terminate(nil)
        }
        let args = CommandLine.arguments
        let value = { (flag: String) in args.firstIndex(of: flag).flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil } }
        let seconds = value("--showcase-seconds").flatMap(Double.init) ?? 8

        // Every group at the same card size: the biggest that fits the longest group on this screen.
        let longest = CGFloat(groups.map(\.looks.count).max() ?? looks.count)
        let room = screen.frame.height - margin * 2
        for size in [DeckSize.m, .s, .xs] {
            DeckMetrics.sizeOverride = size
            if longest * box.height + (longest - 1) * spacing <= room { break }
        }

        let stack = VStack(spacing: spacing) {
            ForEach(looks, id: \.name) { look in
                LookPreview(look: look, size: box)
                    .overlay(alignment: .topLeading) {
                        Text(look.name)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.75))
                            .padding(.leading, 12)
                            .padding(.top, 3)
                    }
            }
        }
        let content = ZStack { BrandBackdrop(); stack }.ignoresSafeArea()

        // Above the menu bar so nothing but the backdrop and previews is on screen.
        let w = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
        w.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.mainMenuWindow)) + 2)
        w.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        w.ignoresMouseEvents = true
        w.isReleasedWhenClosed = false
        w.contentView = NSHostingView(rootView: content)
        w.setFrame(screen.frame, display: true)
        w.orderFrontRegardless()
        window = w
        CGWarpMouseCursorPosition(CGPoint(x: screen.frame.minX + 2, y: 2))

        let count = CGFloat(looks.count)
        let size = CGSize(width: box.width, height: count * box.height + (count - 1) * spacing)
        if let path = value("--showcase-rect") { writeRect(size, on: screen, to: path) }
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { NSApp.terminate(nil) }
    }

    /// One preview: snug around four tiles at the current card size, with headroom for the name.
    private static var box: CGSize {
        let n = LookPreview.natural(list: false)
        return CGSize(width: n.width + LookPreview.padding.width + 48, height: n.height + LookPreview.padding.height + 8)
    }

    /// The centered stack in screen pixels, top-left origin, with `margin` around it: "x y w h".
    private static func writeRect(_ size: CGSize, on screen: NSScreen, to path: String) {
        let scale = screen.backingScaleFactor
        let w = size.width + margin * 2, h = min(screen.frame.height, size.height + margin * 2)
        let x = (screen.frame.width - w) / 2, y = (screen.frame.height - h) / 2
        let line = [x, y, w, h].map { String(Int(($0 * scale).rounded())) }.joined(separator: " ")
        try? (line + "\n").write(toFile: path, atomically: true, encoding: .utf8)
    }
}
