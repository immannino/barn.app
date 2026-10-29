import AppKit
import SwiftUI

/// Status dot in the look's color; pulses while the agent needs you, unless the look is still.
struct StateDot: View {
    var state: AgentState
    var size: CGFloat = 10
    var look: Look?
    @ObservedObject private var settings = Settings.shared
    @Environment(\.colorScheme) private var colorScheme
    @State private var pulse = false

    var body: some View {
        let style = (look ?? settings.activeLook).style(for: state)
        let pulses = state == .waiting && !style.effects.isEmpty
        // On a solid card the dot would be the card's own color, so it takes the text's instead.
        let color = style.isSolid ? style.contrast(dark: colorScheme == .dark) : style.swiftColor
        Circle()
            .fill(color.gradient)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(state == .idle ? 0 : 0.7), radius: size * 0.35)
            .opacity(pulses && pulse ? 0.35 : 1)
            .animation(pulses ? .easeInOut(duration: 0.7 / style.speed).repeatForever() : .default, value: pulse)
            .onAppear { pulse = true }
    }
}

struct AppIcon: View {
    var host: HostApp?
    var size: CGFloat = 20

    var body: some View {
        if let id = host?.bundleID, let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: id) {
            Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
                .resizable()
                .frame(width: size, height: size)
        } else {
            Image(systemName: "terminal")
                .frame(width: size, height: size)
                .foregroundStyle(.secondary)
        }
    }
}

/// "Needs you · 3m" / "Bash: npm test" style subtitle shared by the switcher and menu.
func statusLine(_ agent: Agent, now: Date = Date()) -> String {
    var parts = [agent.state.label]
    if let detail = agent.detail, !detail.isEmpty, agent.state != .idle { parts.append(detail) }
    parts.append(now.timeIntervalSince(agent.stateSince).compact)
    if agent.collapsed > 0 { parts.append("+\(agent.collapsed) more") }
    return parts.joined(separator: " · ")
}

/// Lets a SwiftUI region drag its borderless window.
struct WindowDragArea: NSViewRepresentable {
    final class DragView: NSView {
        override func mouseDown(with event: NSEvent) { window?.performDrag(with: event) }
    }
    func makeNSView(context: Context) -> NSView { DragView() }
    func updateNSView(_ nsView: NSView, context: Context) {}
}
