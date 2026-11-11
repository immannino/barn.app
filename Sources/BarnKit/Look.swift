import AppKit
import SwiftUI

/// A look: how deck tiles, switcher rows and menu bar dots show each agent state. barn ships a
/// few presets; users duplicate and tweak them in settings → looks, and share them as JSON:
///
///     {
///       "barn-look" : 1,
///       "name" : "red alert",
///       "author" : "tony",
///       "states" : {
///         "needs-you" : { "color" : "#FF2D2D", "tint" : 0.45, "effects" : ["flash", "wiggle"], "speed" : 1.4, "intensity" : 1 },
///         "ready" : { … }, "working" : { … }, "idle" : { … }
///       }
///     }
///
/// Decoding is forgiving so looks travel well between barn versions: a missing state or field
/// falls back to barn's default, unknown effects are skipped, and numbers are clamped.
struct Look: Equatable {
    var name: String
    var author: String?
    var waiting: StateStyle
    var ready: StateStyle
    var working: StateStyle
    var idle: StateStyle
    /// An opaque retro surface instead of glass (Skin.swift). nil is glass.
    var skin: Skin? = nil

    static let formatVersion = 1

    func style(for state: AgentState) -> StateStyle {
        switch state {
        case .waiting: waiting
        case .ready: ready
        case .working: working
        case .idle: idle
        }
    }

    subscript(state: AgentState) -> StateStyle {
        get { style(for: state) }
        set {
            switch state {
            case .waiting: waiting = newValue
            case .ready: ready = newValue
            case .working: working = newValue
            case .idle: idle = newValue
            }
        }
    }
}

struct StateStyle: Equatable {
    /// "#RRGGBB".
    var color: String
    /// How strongly the color tints the glass, 0…1. From 0.6 up the card reads as solid, and its
    /// text flips to a contrasting color.
    var tint: Double
    var effects: [Effect] = []
    /// Animation speed multiplier, 0.25…3.
    var speed: Double = 1
    /// 0…1.
    var intensity: Double = 0.8
    /// Used instead of `color` in dark mode, for looks that follow the appearance (mono: ink in
    /// light mode, white in dark).
    var darkColor: String? = nil
    /// Text color on this state's cards, overriding the automatic black, white or skin text.
    var text: String? = nil

    /// Follows light/dark mode when there's a `darkColor`.
    var nsColor: NSColor {
        guard let darkColor, NSColor(hex: darkColor) != nil else { return NSColor(hex: color) ?? .systemGray }
        let light = color
        return NSColor(name: nil) { appearance in
            let dark = appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua
            return NSColor(hex: dark ? darkColor : light) ?? .systemGray
        }
    }
    var swiftColor: Color { Color(nsColor: nsColor) }

    /// The plain color for one appearance (blending a dynamic color needs this).
    func resolved(dark: Bool) -> NSColor {
        NSColor(hex: dark ? (darkColor ?? color) : color) ?? .systemGray
    }

    var isSolid: Bool { tint >= 0.6 }

    static let speedRange = 0.25...3.0

    func clamped() -> StateStyle {
        var s = self
        s.color = NSColor(hex: color) != nil ? color.uppercased() : "#8E8E93"
        s.darkColor = darkColor.flatMap { NSColor(hex: $0) != nil ? $0.uppercased() : nil }
        s.text = text.flatMap { NSColor(hex: $0) != nil ? $0.uppercased() : nil }
        s.tint = min(1, max(0, tint))
        s.speed = min(Self.speedRange.upperBound, max(Self.speedRange.lowerBound, speed))
        s.intensity = min(1, max(0, intensity))
        var seen = Set<Effect>()
        s.effects = effects.filter { seen.insert($0).inserted }
        return s
    }
}

enum Effect: String, CaseIterable, Codable {
    /// The border fades in and out.
    case pulse
    /// A soft colored halo breathes around the card.
    case glow
    /// The border blinks hard on and off.
    case flash
    /// The whole card flashes its color.
    case strobe
    /// A soft diagonal sheen sweeps across the card now and then.
    case shimmer
    /// Thin lines of light sweep across, one after another.
    case lines
    /// A comet of light travels around the border.
    case orbit
    /// A rotating rainbow border.
    case rainbow
    /// Every few seconds the card shakes, like it's trying to get your attention.
    case wiggle
    /// Every few seconds the card hops.
    case bounce
    /// Liquid sloshing in the bottom of the card.
    case wave
    /// Bubbles rise through the card.
    case bubbles
    /// Soft curtains of colored light drift across the card.
    case aurora
    /// The card swaps to a solid block of its color and back, like Apple II FLASH text.
    case blink
    /// A blinking block cursor after the status.
    case cursor

    var label: String { rawValue }

    /// Effects that move the card around; skipped in the switcher list and with Reduce Motion.
    var moves: Bool { self == .wiggle || self == .bounce }

    var help: String {
        switch self {
        case .pulse: "the border fades in and out"
        case .glow: "a soft halo breathes around it"
        case .flash: "the border blinks on and off (at most 3 times a second)"
        case .strobe: "the whole card flashes (at most 3 times a second)"
        case .shimmer: "a soft sheen sweeps across now and then"
        case .lines: "thin lines of light sweep across"
        case .orbit: "a comet of light travels around the border"
        case .rainbow: "a rotating rainbow border"
        case .wiggle: "shakes every few seconds"
        case .bounce: "hops every few seconds"
        case .wave: "liquid sloshes in the bottom of the card"
        case .bubbles: "bubbles rise through the card"
        case .aurora: "soft colored light drifts across it"
        case .blink: "flips to inverse and back, like old terminals (at most 3 times a second)"
        case .cursor: "a blinking block cursor after the status"
        }
    }
}

// MARK: Presets

extension Look {
    private static let gray = StateStyle(color: "#8E8E93", tint: 0)

    static let barn = Look(
        name: "barn", author: "barn",
        waiting: StateStyle(color: "#FF5C61", tint: 0.32, effects: [.pulse], speed: 1, intensity: 0.8),
        ready: StateStyle(color: "#3DDB99", tint: 0.26),
        working: StateStyle(color: "#334DFF", tint: 0.26, effects: [.orbit], speed: 0.8, intensity: 0.8),
        idle: gray)

    static let presets: [Look] = [
        barn,
        Look(name: "calm", author: "barn",
             waiting: StateStyle(color: "#FF5C61", tint: 0.3),
             ready: StateStyle(color: "#3DDB99", tint: 0.18),
             working: StateStyle(color: "#334DFF", tint: 0.16),
             idle: gray),
        Look(name: "red alert", author: "barn",
             waiting: StateStyle(color: "#FF2D2D", tint: 0.45, effects: [.flash, .wiggle], speed: 1.4, intensity: 1),
             ready: StateStyle(color: "#3DDB99", tint: 0.26, effects: [.glow], speed: 0.8, intensity: 0.6),
             working: StateStyle(color: "#334DFF", tint: 0.26, effects: [.orbit], speed: 0.8, intensity: 0.7),
             idle: gray),
        Look(name: "farm fresh", author: "barn",
             waiting: StateStyle(color: "#FFD64D", tint: 0.4, effects: [.glow, .bounce], speed: 1, intensity: 0.9),
             ready: StateStyle(color: "#3DDB99", tint: 0.3, effects: [.shimmer], speed: 0.8, intensity: 0.5),
             working: StateStyle(color: "#8CB3FF", tint: 0.22),
             idle: gray),
        // Black and white glass that follows light/dark mode: gray when idle, an orbit while
        // working, lines sweeping across when it needs you, solid ink when it's done.
        Look(name: "mono", author: "barn",
             waiting: StateStyle(color: "#1C1C1E", tint: 0.18, effects: [.lines], speed: 1, intensity: 0.9, darkColor: "#FFFFFF"),
             ready: StateStyle(color: "#111113", tint: 0.92, darkColor: "#F5F5F7"),
             working: StateStyle(color: "#1C1C1E", tint: 0.06, effects: [.orbit], speed: 0.8, intensity: 0.9, darkColor: "#FFFFFF"),
             idle: StateStyle(color: "#8E8E93", tint: 0, darkColor: "#7C7C80")),
        Look(name: "sunset", author: "barn",
             waiting: StateStyle(color: "#FF5E3A", tint: 0.4, effects: [.glow, .pulse], speed: 0.9, intensity: 0.9),
             ready: StateStyle(color: "#FFB627", tint: 0.34, effects: [.shimmer], speed: 0.8, intensity: 0.6),
             working: StateStyle(color: "#C04BFF", tint: 0.28, effects: [.orbit], speed: 0.8, intensity: 0.85),
             idle: StateStyle(color: "#A08C99", tint: 0.06)),
        Look(name: "ocean", author: "barn",
             waiting: StateStyle(color: "#FF6F91", tint: 0.36, effects: [.lines], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#2EC4B6", tint: 0.32, effects: [.glow], speed: 0.7, intensity: 0.6),
             working: StateStyle(color: "#3A86FF", tint: 0.26, effects: [.orbit], speed: 0.7, intensity: 0.8),
             idle: StateStyle(color: "#8D99AE", tint: 0.06)),
        Look(name: "neon", author: "barn",
             waiting: StateStyle(color: "#FF2E97", tint: 0.4, effects: [.glow, .flash], speed: 1, intensity: 1),
             ready: StateStyle(color: "#39FF14", tint: 0.3, effects: [.glow], speed: 0.8, intensity: 0.8),
             working: StateStyle(color: "#00E5FF", tint: 0.28, effects: [.orbit], speed: 1.1, intensity: 1),
             idle: StateStyle(color: "#5C5C66", tint: 0.05)),
        Look(name: "disco", author: "barn",
             waiting: StateStyle(color: "#FF4FD8", tint: 0.4, effects: [.rainbow, .bounce], speed: 1.3, intensity: 1),
             ready: StateStyle(color: "#FFD64D", tint: 0.3, effects: [.glow], speed: 1.2, intensity: 0.8),
             working: StateStyle(color: "#7B5CFF", tint: 0.3, effects: [.orbit], speed: 1.2, intensity: 0.8),
             idle: gray),
    ] + retro

    /// Every opaque look, grouped, whether or not it's released yet.
    static let allSkinGroups: [(name: String, looks: [Look])] = [
        ("terminals", terminals), ("desktops", desktops), ("whimsy", whimsy), ("design", design), ("worlds", worlds), ("holidays", holidays), ("friends", friends),
    ]

    /// The groups the picker and menus show: unreleased looks only with the flag on.
    static var skinGroups: [(name: String, looks: [Look])] {
        allSkinGroups.map { ($0.name, $0.looks.filter(isListed)) }.filter { !$0.looks.isEmpty }
    }

    /// Looks still being worked on. They're hidden from the picker and menus (though one already
    /// in use keeps working) unless the flag is on:
    /// `defaults write dev.tony.barn showUnreleasedLooks -bool YES`
    static let unreleased: Set<String> = Set(["bauhaus", "mid century", "kawaii", "coquette"] + worlds.map(\.name))

    static var showUnreleased: Bool { UserDefaults.standard.bool(forKey: "showUnreleasedLooks") }

    static func isListed(_ look: Look) -> Bool { showUnreleased || !unreleased.contains(look.name) }
    static let retro: [Look] = terminals + desktops + whimsy + design + worlds + holidays + friends

    /// Which picker group a look id belongs to: "glass", a skin group's name, or "yours".
    static func group(of id: String) -> String {
        guard id.hasPrefix("preset:") else { return "yours" }
        let name = String(id.dropFirst("preset:".count))
        return allSkinGroups.first { $0.looks.contains { $0.name == name } }?.name ?? "glass"
    }

    /// Old computers' text screens. Each tries a pixel font first if you have one installed
    /// (Kreative's Print Char 21, int10h's Px437 fonts, VT323…), then falls back to the system's
    /// monospaced font.
    static let terminals: [Look] = [
        // Green phosphor on black, all caps. Waiting agents FLASH, working ones show the cursor.
        Look(name: "apple ][", author: "barn",
             waiting: StateStyle(color: "#33FF33", tint: 0, effects: [.blink], speed: 1),
             ready: StateStyle(color: "#33FF33", tint: 0.16),
             working: StateStyle(color: "#33FF33", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#1C8A1C", tint: 0, text: "#1C8A1C"),
             skin: Skin(background: "#030A03", text: "#33FF33", dim: "#1FA81F", border: .line,
                        borderColor: "#145A14", scanlines: 0.65, glow: 0.8, uppercase: true,
                        fonts: ["Print Char 21", "PR Number 3", "Apple ][", "Apple II"], prompt: "]")),
        // The hi-res palette: orange, green, blue and violet on black.
        Look(name: "apple ][ color", author: "barn",
             waiting: StateStyle(color: "#FF6A3C", tint: 1, effects: [.blink], speed: 0.9, text: "#000000"),
             ready: StateStyle(color: "#14F53C", tint: 1, text: "#000000"),
             working: StateStyle(color: "#14CFFD", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#FF44FD", tint: 0, text: "#9C9C9C"),
             skin: Skin(background: "#000000", text: "#FFFFFF", dim: "#9C9C9C", border: .line,
                        borderColor: "#444444", scanlines: 0.5, glow: 0.45, uppercase: true,
                        fonts: ["Print Char 21", "PR Number 3", "Apple ][", "Apple II"], prompt: "]")),
        // Text mode, CGA colors: white on blue in double-line boxes with drop shadows. Red when it
        // needs you, black on cyan when it's done.
        Look(name: "dos", author: "barn",
             waiting: StateStyle(color: "#AA0000", tint: 1, effects: [.blink], speed: 0.8, text: "#FFFF55"),
             ready: StateStyle(color: "#00AAAA", tint: 1, text: "#000000"),
             working: StateStyle(color: "#FFFF55", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#AAAAAA", tint: 0, text: "#AAAAAA"),
             skin: Skin(background: "#0000AA", text: "#FFFFFF", dim: "#AAAAAA", border: .double,
                        borderColor: "#55FFFF", shadow: .hard, scanlines: 0.2, uppercase: true,
                        fonts: ["Px437 IBM VGA 8x16", "PxPlus IBM VGA 8x16", "Px437 IBM VGA 9x16",
                                "Perfect DOS VGA 437", "Perfect DOS VGA 437 Win", "Web437 IBM VGA 8x16"],
                        prompt: "C:\\>")),
        // An amber monitor: warm glow, heavy scanlines, rounded glass.
        Look(name: "amber", author: "barn",
             waiting: StateStyle(color: "#FFB000", tint: 0, effects: [.blink], speed: 1),
             ready: StateStyle(color: "#FFB000", tint: 0.16),
             working: StateStyle(color: "#FFB000", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#8A5A00", tint: 0, text: "#8A5A00"),
             skin: Skin(background: "#120A00", text: "#FFB000", dim: "#B37A00", corner: 8,
                        scanlines: 0.8, glow: 0.9,
                        fonts: ["VT323", "Glass TTY VT220", "Px437 DEC VT220", "Px437 IBM 3270pc"], prompt: ">")),
        // Light blue on dark blue inside a fat border, READY.
        Look(name: "c64", author: "barn",
             waiting: StateStyle(color: "#883932", tint: 1, effects: [.blink], speed: 0.9, text: "#FFFFFF"),
             ready: StateStyle(color: "#55A049", tint: 1, text: "#FFFFFF"),
             working: StateStyle(color: "#67B6BD", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#6C6C6C", tint: 0, text: "#959595"),
             skin: Skin(background: "#352879", text: "#A59FFF", dim: "#7869C4", border: .thick,
                        borderColor: "#6C5EB5", scanlines: 0.35, glow: 0.4, uppercase: true,
                        fonts: ["C64 Pro Mono", "C64 Pro", "C64 User Mono", "Pet Me 64"], prompt: "READY.")),
        // A mainframe terminal: green fields, red errors, turquoise and yellow highlights.
        Look(name: "3270", author: "barn",
             waiting: StateStyle(color: "#FF3030", tint: 0, effects: [.blink], speed: 0.9),
             ready: StateStyle(color: "#40E0D0", tint: 0),
             working: StateStyle(color: "#FFFF00", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#5C9CFF", tint: 0, text: "#5C9CFF"),
             skin: Skin(background: "#000000", text: "#00FF00", dim: "#00A000", border: .line,
                        borderColor: "#0A3A0A", scanlines: 0.4, glow: 0.55, uppercase: true,
                        fonts: ["3270", "IBM 3270", "3270 Nerd Font", "Px437 IBM 3270pc"], prompt: "===>")),
        // Broadcast text pages: a colored header band per state that flashes when it needs you.
        Look(name: "teletext", author: "barn",
             waiting: StateStyle(color: "#FF0000", tint: 0, effects: [.blink], speed: 0.8),
             ready: StateStyle(color: "#00FF00", tint: 0),
             working: StateStyle(color: "#00FFFF", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#0000FF", tint: 0, text: "#FFFF00"),
             skin: Skin(background: "#000000", text: "#FFFFFF", dim: "#FFFF00", scanlines: 0.3, glow: 0.3,
                        fonts: ["MODE7GX3", "Bedstead", "European Teletext", "Teletext50"], prompt: "P100",
                        titleBar: Skin.TitleBar(height: 14, inactive: "#000000"))),
        // A green handheld LCD: four shades and a visible pixel grid.
        Look(name: "pocket lcd", author: "barn",
             waiting: StateStyle(color: "#0F380F", tint: 1, effects: [.blink], speed: 0.8),
             ready: StateStyle(color: "#306230", tint: 0.3),
             working: StateStyle(color: "#0F380F", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#306230", tint: 0, text: "#306230"),
             skin: Skin(background: "#9BBC0F", text: "#0F380F", dim: "#306230", border: .thick,
                        borderColor: "#306230", corner: 3, uppercase: true,
                        fonts: ["Early GameBoy", "Pokemon GB", "Press Start 2P", "PixelOperator"], prompt: "▶",
                        pattern: .grid, patternColors: ["#8BAC0F"], patternStrength: 0.7)),
    ]

    /// Desktop windows. A title bar that follows the state is the active window's color while
    /// working, gray when idle, and flashes when an agent needs you.
    static let desktops: [Look] = [
        // Black and white, one pixel deep: hard shadows and inverse video, in Geneva.
        Look(name: "1-bit", author: "barn",
             waiting: StateStyle(color: "#000000", tint: 0, effects: [.blink], speed: 0.8),
             ready: StateStyle(color: "#000000", tint: 1),
             working: StateStyle(color: "#000000", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#777777", tint: 0, text: "#777777"),
             skin: Skin(background: "#FFFFFF", text: "#000000", dim: "#555555", border: .line,
                        borderColor: "#000000", shadow: .hard, fonts: ["ChicagoFLF", "Chicago", "Geneva"],
                        fallback: .sans)),
        // White windows, gray frames, navy title bars.
        Look(name: "win 3.1", author: "barn",
             waiting: StateStyle(color: "#800000", tint: 0, effects: [.blink], speed: 0.8),
             ready: StateStyle(color: "#008080", tint: 0),
             working: StateStyle(color: "#000080", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#FFFFFF", tint: 0, text: "#808080"),
             skin: Skin(background: "#FFFFFF", text: "#000000", dim: "#808080", border: .thick,
                        borderColor: "#A8A8A8", fonts: ["Microsoft Sans Serif", "MS Sans Serif", "Arial"],
                        fallback: .sans,
                        titleBar: Skin.TitleBar(height: 15, buttons: .win, inactive: "#FFFFFF"))),
        // Gray 3D chrome and a fading title bar.
        Look(name: "win 98", author: "barn",
             waiting: StateStyle(color: "#800000", tint: 0, effects: [.blink], speed: 0.8),
             ready: StateStyle(color: "#008080", tint: 0),
             working: StateStyle(color: "#000080", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#808080", tint: 0, text: "#404040"),
             skin: Skin(background: "#C0C0C0", text: "#000000", dim: "#404040", border: .bevel,
                        borderColor: "#404040", fonts: ["Microsoft Sans Serif", "Tahoma", "Arial"], prompt: "Run:",
                        fallback: .sans,
                        titleBar: Skin.TitleBar(fade: 0.6, text: "#FFFFFF", height: 15, buttons: .win))),
        // Cream windows with glossy, rounded title bars and a red close button.
        Look(name: "xp", author: "barn",
             waiting: StateStyle(color: "#D7441F", tint: 0, effects: [.blink], speed: 0.8),
             ready: StateStyle(color: "#3C8D2F", tint: 0),
             working: StateStyle(color: "#0054E3", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#7A96DF", tint: 0, text: "#6D6D6D"),
             skin: Skin(background: "#ECE9D8", text: "#000000", dim: "#6D6D6D", border: .thick, corner: 7,
                        fonts: ["Tahoma", "Trebuchet MS"], fallback: .sans, stateFrame: true,
                        titleBar: Skin.TitleBar(fade: 0.2, direction: .down, text: "#FFFFFF", height: 17,
                                                buttons: .xp, gloss: 0.55, inactive: "#7A96DF"))),
        // Flat tiles of solid color with white type.
        Look(name: "metro", author: "barn",
             waiting: StateStyle(color: "#E51400", tint: 1, effects: [.blink], speed: 0.7, text: "#FFFFFF"),
             ready: StateStyle(color: "#60A917", tint: 1, text: "#FFFFFF"),
             working: StateStyle(color: "#1BA1E2", tint: 1, effects: [.shimmer], speed: 0.8, intensity: 0.5, text: "#FFFFFF"),
             idle: StateStyle(color: "#647687", tint: 1, text: "#FFFFFF"),
             skin: Skin(background: "#1D1D1D", text: "#FFFFFF", dim: "#E0E0E0",
                        fonts: ["Segoe UI", "Selawik", "Helvetica Neue"], fallback: .sans)),
        // Late classic Mac: light gray, striped title bars with a close box, lavender highlights.
        Look(name: "platinum", author: "barn",
             waiting: StateStyle(color: "#CC0000", tint: 0, effects: [.blink], speed: 0.8),
             ready: StateStyle(color: "#9999FF", tint: 0.5),
             working: StateStyle(color: "#3355CC", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#888888", tint: 0, text: "#666666"),
             skin: Skin(background: "#DDDDDD", text: "#000000", dim: "#555555", border: .bevel,
                        borderColor: "#000000", fonts: ["Charcoal", "ChicagoFLF", "Geneva"], fallback: .sans,
                        titleBar: Skin.TitleBar(color: "#DDDDDD", text: "#000000", height: 15, buttons: .mac,
                                                stripes: true))),
        // Pinstripes, gel buttons and traffic lights.
        Look(name: "aqua", author: "barn",
             waiting: StateStyle(color: "#E0443E", tint: 1, effects: [.pulse], speed: 0.9, intensity: 0.8, text: "#FFFFFF"),
             ready: StateStyle(color: "#3875D7", tint: 1, text: "#FFFFFF"),
             working: StateStyle(color: "#3875D7", tint: 0, effects: [.orbit], speed: 0.8, intensity: 0.8),
             idle: StateStyle(color: "#8E8E93", tint: 0, text: "#6E6E6E"),
             skin: Skin(background: "#FFFFFF", text: "#000000", dim: "#666666", border: .line,
                        borderColor: "#A0A0A0", corner: 9, fonts: ["Lucida Grande", "Helvetica Neue"],
                        fallback: .sans, pattern: .pinstripes, patternColors: ["#E4E4E4"], patternStrength: 1,
                        gloss: 0.35,
                        titleBar: Skin.TitleBar(color: "#ECECEC", end: "#C4C4C4", direction: .down, text: "#000000",
                                                height: 16, buttons: .aqua, gloss: 0.4))),
        // Grays and bevels under a black title bar, set in Helvetica.
        Look(name: "nextstep", author: "barn",
             waiting: StateStyle(color: "#000000", tint: 1, effects: [.blink], speed: 0.8),
             ready: StateStyle(color: "#FFFFFF", tint: 0.8),
             working: StateStyle(color: "#000000", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#555555", tint: 0, text: "#4A4A4A"),
             skin: Skin(background: "#AAAAAA", text: "#000000", dim: "#3A3A3A", border: .bevel,
                        borderColor: "#000000", fonts: ["Helvetica", "Helvetica Neue"], fallback: .sans,
                        titleBar: Skin.TitleBar(color: "#000000", text: "#FFFFFF", height: 15, buttons: .win))),
        // Blue, white, orange and black, with the shell's 1> prompt.
        Look(name: "workbench", author: "barn",
             waiting: StateStyle(color: "#FF8800", tint: 1, effects: [.blink], speed: 0.8, text: "#000022"),
             ready: StateStyle(color: "#FF8800", tint: 0),
             working: StateStyle(color: "#FFFFFF", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#000022", tint: 0, text: "#9DBDE8"),
             skin: Skin(background: "#0055AA", text: "#FFFFFF", dim: "#B8D0F0", border: .line,
                        borderColor: "#FFFFFF",
                        fonts: ["Topaz", "Topaz New", "Amiga Topaz", "Topaz a600a1200a400"], prompt: "1>",
                        titleBar: Skin.TitleBar(color: "#FFFFFF", text: "#0055AA", height: 14, buttons: .mac,
                                                stripes: true))),
    ]

    /// Design movements and the web's own styles.
    static let design: [Look] = [
        // Squiggles and confetti shapes in loud colors, thick black outlines, a hard shadow.
        Look(name: "memphis", author: "barn",
             waiting: StateStyle(color: "#FF3E7F", tint: 0.15, effects: [.wiggle], speed: 1, intensity: 0.7),
             ready: StateStyle(color: "#00A676", tint: 0.12),
             working: StateStyle(color: "#2D7DFF", tint: 0.06),
             idle: StateStyle(color: "#9A9A9A", tint: 0, text: "#6B6B6B"),
             skin: Skin(background: "#FFF6E9", text: "#1B1B1B", dim: "#5A5A5A", border: .thick, borderColor: "#1B1B1B",
                        corner: 4, shadow: .hard, fonts: ["Futura", "Avenir Next"], fallback: .sans,
                        pattern: .memphis, patternColors: ["#FF5FA2", "#00C2C7", "#FFD23F", "#7B5CFF", "#1B1B1B"],
                        patternStrength: 0.32)),
        // Primary circles, squares and bars on cream; square corners, all caps.
        Look(name: "bauhaus", author: "barn",
             waiting: StateStyle(color: "#E63A2E", tint: 0.2, effects: [.pulse], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#1F4FA3", tint: 0.12),
             working: StateStyle(color: "#E0A800", tint: 0.12),
             idle: StateStyle(color: "#8A8478", tint: 0, text: "#6E695F"),
             skin: Skin(background: "#F1E9DA", text: "#111111", dim: "#55524C", border: .thick, borderColor: "#111111",
                        corner: 0, uppercase: true, fonts: ["Futura", "Avenir Next"], fallback: .sans,
                        pattern: .bauhaus, patternColors: ["#E63A2E", "#1F4FA3", "#F2B705", "#111111"], patternStrength: 0.16)),
        // Atomic-age starbursts, mustard and teal, rounded and warm.
        Look(name: "mid century", author: "barn",
             waiting: StateStyle(color: "#D9542B", tint: 0.15, effects: [.pulse], speed: 0.9, intensity: 0.8),
             ready: StateStyle(color: "#2F8C79", tint: 0.12),
             working: StateStyle(color: "#D99A1E", tint: 0.1),
             idle: StateStyle(color: "#9C8F7E", tint: 0, text: "#7E7262"),
             skin: Skin(background: "#F4EBD9", text: "#2F2A24", dim: "#7A6E60", border: .line, borderColor: "#C9B79C",
                        corner: 14, fonts: ["Futura", "Gill Sans", "Avenir Next"], fallback: .sans,
                        pattern: .sparkles, patternColors: ["#D9822B"], patternStrength: 0.35)),
        // Swiss grid: Helvetica, all caps, a hairline grid, and solid blocks of red and black.
        Look(name: "modular type", author: "barn",
             waiting: StateStyle(color: "#FF2A00", tint: 0.85),
             ready: StateStyle(color: "#000000", tint: 0.9),
             working: StateStyle(color: "#0047FF", tint: 0.1),
             idle: StateStyle(color: "#9A9A9A", tint: 0, text: "#8A8A8A"),
             skin: Skin(background: "#FFFFFF", text: "#000000", dim: "#555555", border: .line, borderColor: "#000000",
                        corner: 0, uppercase: true, fonts: ["Helvetica Neue", "Helvetica"], fallback: .sans,
                        pattern: .grid, patternColors: ["#E6E6E6"], patternStrength: 1)),
        // Function first: warm off-white, a black rule, Helvetica, one safety-orange block when it needs you.
        Look(name: "utilitarian", author: "barn",
             waiting: StateStyle(color: "#E8582A", tint: 0.85),
             ready: StateStyle(color: "#5E7A5A", tint: 0.12),
             working: StateStyle(color: "#2B2B2B", tint: 0.04, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#A8A49C", tint: 0, text: "#7A766E"),
             skin: Skin(background: "#F1EFEA", text: "#111111", dim: "#55524C", border: .line, borderColor: "#111111",
                        corner: 0, fonts: ["Helvetica Neue", "Helvetica"], fallback: .sans,
                        titleBar: Skin.TitleBar(color: "#111111", fade: 0, text: "#F1EFEA", height: 10))),
        // Poster brutalism: off-white paper, huge condensed caps, raw red blocks, halftone.
        Look(name: "brutalism", author: "barn",
             waiting: StateStyle(color: "#E23B2E", tint: 0.85, effects: [.blink], speed: 1),
             ready: StateStyle(color: "#1A1A1A", tint: 0.88),
             working: StateStyle(color: "#3A3FB0", tint: 0.08),
             idle: StateStyle(color: "#8A8780", tint: 0, text: "#6E6A62"),
             skin: Skin(background: "#F2EEE6", text: "#1A1A1A", dim: "#4A4740", border: .thick, borderColor: "#1A1A1A",
                        corner: 0, uppercase: true, fonts: ["Bebas Neue", "Impact", "DIN Condensed", "Helvetica Neue"],
                        fallback: .sans, pattern: .dots, patternColors: ["#D9D3C7"], patternStrength: 0.7)),
        // Flat candy colors, thick black outlines, chunky hard shadows.
        Look(name: "neo-brutalism", author: "barn",
             waiting: StateStyle(color: "#FF6B6B", tint: 0.85, effects: [.wiggle], speed: 1, intensity: 0.6),
             ready: StateStyle(color: "#5EE08A", tint: 0.85),
             working: StateStyle(color: "#8FA8FF", tint: 0.6),
             idle: StateStyle(color: "#C9C3B6", tint: 0.3, text: "#4A463F"),
             skin: Skin(background: "#FFF4E0", text: "#000000", dim: "#3A3A3A", border: .thick, borderColor: "#000000",
                        corner: 8, shadow: .hard, fonts: ["Arial Black", "Helvetica Neue"], fallback: .sans)),
        // Pastel pink, hearts and stars, round type, a happy hop when it needs you.
        Look(name: "kawaii", author: "barn",
             waiting: StateStyle(color: "#FF6FA5", tint: 0.25, effects: [.bounce], speed: 1, intensity: 0.7),
             ready: StateStyle(color: "#5CCB8F", tint: 0.18, effects: [.shimmer], speed: 0.8, intensity: 0.6),
             working: StateStyle(color: "#6BB6FF", tint: 0.15),
             idle: StateStyle(color: "#C9A9BC", tint: 0, text: "#A07A92"),
             skin: Skin(background: "#FFF0F6", text: "#6B3A5B", dim: "#A07A92", border: .thick, borderColor: "#F27BAE",
                        corner: 20, fonts: ["Hiragino Maru Gothic ProN", "Arial Rounded MT Bold"], fallback: .rounded,
                        gradient: ["#FFE3F1"], pattern: .hearts, patternColors: ["#FFB3D1", "#B8E6FF", "#FFE07A"],
                        patternStrength: 0.5)),
        // Blush, ribbons of double rule, Didone serif, tiny hearts.
        Look(name: "coquette", author: "barn",
             waiting: StateStyle(color: "#E0607E", tint: 0.2, effects: [.pulse], speed: 0.8, intensity: 0.8),
             ready: StateStyle(color: "#7FAE8A", tint: 0.15),
             working: StateStyle(color: "#E39AAA", tint: 0.15),
             idle: StateStyle(color: "#C8B4B4", tint: 0, text: "#A88A8E"),
             skin: Skin(background: "#FFF7F5", text: "#7A2E3A", dim: "#A8707A", border: .double, borderColor: "#E8A0AE",
                        corner: 12, fonts: ["Bodoni 72", "Didot"], fallback: .serif,
                        pattern: .hearts, patternColors: ["#F7C6CF"], patternStrength: 0.4)),
    ]

    /// Moods, places and crafts.
    static let worlds: [Look] = [
        // Deep space: drifting stars in three depths, a nebula breathing in the state's colors.
        Look(name: "aurora", author: "barn",
             waiting: StateStyle(color: "#FF4FA3", tint: 0, speed: 1, intensity: 1),
             ready: StateStyle(color: "#7CC4FF", tint: 0),
             working: StateStyle(color: "#5CFFD0", tint: 0),
             idle: StateStyle(color: "#5A6A8A", tint: 0, text: "#8A9AB8"),
             skin: Skin(background: "#03040C", text: "#EEF4FF", dim: "#9AA8C8", border: .line, borderColor: "#1A2140",
                        corner: 16, glow: 0.85, fonts: ["Avenir Next"], fallback: .rounded, gradient: ["#070A1E", "#0D0A24"],
                        direction: .diagonal, glowColor: "#03040C", backdrop: .galaxy)),
        // Neon sun, mountains and a grid racing toward you.
        Look(name: "synthwave", author: "barn",
             waiting: StateStyle(color: "#FF2BD6", tint: 0.15, effects: [.glow], speed: 1, intensity: 0.9),
             ready: StateStyle(color: "#2BFFF1", tint: 0.1),
             working: StateStyle(color: "#FFB12B", tint: 0.05),
             idle: StateStyle(color: "#6A4A8A", tint: 0, text: "#A88AC8"),
             skin: Skin(background: "#12002B", text: "#FFE6FF", dim: "#C9A0E0", border: .line, borderColor: "#FF2BD6",
                        corner: 6, glow: 0.85, uppercase: true, fonts: ["Futura", "Avenir Next Condensed"], fallback: .sans,
                        gradient: ["#12002B", "#3B0A57", "#7A1A6B"], glowColor: "#0A0018", backdrop: .synthwave)),
        // Pastel sunset, checkerboard, glowing white type.
        Look(name: "vaporwave", author: "barn",
             waiting: StateStyle(color: "#FF71CE", tint: 0.2, effects: [.glow], speed: 0.8, intensity: 0.8),
             ready: StateStyle(color: "#05FFA1", tint: 0.15),
             working: StateStyle(color: "#01CDFE", tint: 0.1),
             idle: StateStyle(color: "#B8A3D9", tint: 0, text: "#F0E6FF"),
             skin: Skin(background: "#FF9ED8", text: "#FFFFFF", dim: "#FFF0FB", border: .line, borderColor: "#FFFFFF",
                        corner: 0, glow: 0.85, fonts: ["Hiragino Kaku Gothic ProN", "Helvetica Neue"], fallback: .sans,
                        gradient: ["#B967FF", "#01CDFE"], direction: .diagonal,
                        glowColor: "#4B1D7A", backdrop: .vaporwave)),
        // A wireframe world in glowing green: mountains, a crescent moon, a grid racing toward you.
        Look(name: "vector", author: "barn",
             waiting: StateStyle(color: "#FF4040", tint: 0, effects: [.flash], speed: 1, intensity: 0.8, text: "#FF6A6A"),
             ready: StateStyle(color: "#39FF6A", tint: 0),
             working: StateStyle(color: "#39FF6A", tint: 0),
             idle: StateStyle(color: "#1E7A3A", tint: 0, text: "#2FAF55"),
             skin: Skin(background: "#000000", text: "#39FF6A", dim: "#2BC452", border: .line, borderColor: "#1E7A3A",
                        corner: 4, scanlines: 0.25, glow: 0.85, uppercase: true, fonts: ["SF Mono", "Menlo"], fallback: .mono,
                        glowColor: "#000000", backdrop: .vectorGreen)),
        // The same in war-room blue.
        Look(name: "defcon", author: "barn",
             waiting: StateStyle(color: "#FF4040", tint: 0, effects: [.flash], speed: 1, intensity: 0.8, text: "#FF6A6A"),
             ready: StateStyle(color: "#3FB4FF", tint: 0),
             working: StateStyle(color: "#3FB4FF", tint: 0),
             idle: StateStyle(color: "#1E5A8A", tint: 0, text: "#3F86C4"),
             skin: Skin(background: "#000208", text: "#7FD0FF", dim: "#3FA0E0", border: .line, borderColor: "#1E5A8A",
                        corner: 4, scanlines: 0.25, glow: 0.85, uppercase: true, fonts: ["SF Mono", "Menlo"], fallback: .mono,
                        glowColor: "#000000", backdrop: .vectorBlue)),
        // HUD green on black, scanlines, a grid, alarms in red.
        Look(name: "cybercore", author: "barn",
             waiting: StateStyle(color: "#FF003C", tint: 0, effects: [.flash, .wiggle], speed: 1.2, intensity: 1, text: "#FF3B63"),
             ready: StateStyle(color: "#00E5FF", tint: 0, effects: [.lines], speed: 1, intensity: 0.7, text: "#00E5FF"),
             working: StateStyle(color: "#00FF9C", tint: 0, effects: [.cursor, .lines], speed: 1, intensity: 0.6),
             idle: StateStyle(color: "#2E5A48", tint: 0, text: "#3F7A62"),
             skin: Skin(background: "#050505", text: "#00FF9C", dim: "#00A86B", border: .double, borderColor: "#00FF9C",
                        corner: 0, scanlines: 0.35, glow: 0.6, uppercase: true, fonts: ["OCR A Std", "SF Mono", "Menlo"],
                        fallback: .mono, pattern: .grid, patternColors: ["#003B24"], patternStrength: 1)),
        // A cathedral at night: a stained-glass lancet window glowing in the state's color,
        // candlelight flickering, blackletter type.
        Look(name: "gothic", author: "barn",
             waiting: StateStyle(color: "#D4102E", tint: 0, speed: 1, intensity: 1),
             ready: StateStyle(color: "#3FA36B", tint: 0),
             working: StateStyle(color: "#5B5BE0", tint: 0),
             idle: StateStyle(color: "#4A3F4C", tint: 0, text: "#9A8F88"),
             skin: Skin(background: "#0B090C", text: "#EADFCB", dim: "#A89A86", border: .double, borderColor: "#6B5A3E",
                        corner: 2, glow: 0.85, fonts: ["UnifrakturMaguntia", "Old English Text MT", "Luminari", "Trattatello"],
                        fallback: .serif, gradient: ["#16111A", "#0B090C"], glowColor: "#050405", backdrop: .gothic)),
        // Brass gears with a metal sheen turning on a riveted iron plate, steam venting.
        Look(name: "steampunk", author: "barn",
             waiting: StateStyle(color: "#E04E2E", tint: 0.12, effects: [.glow], speed: 1, intensity: 0.7),
             ready: StateStyle(color: "#8DBF5A", tint: 0.08),
             working: StateStyle(color: "#E3A33B", tint: 0.05),
             idle: StateStyle(color: "#7A6248", tint: 0, text: "#B09878"),
             skin: Skin(background: "#1A1410", text: "#F2D7A6", dim: "#C4A77A", border: .double, borderColor: "#B8863A",
                        corner: 6, glow: 0.85, fonts: ["Copperplate", "Big Caslon", "Baskerville"], fallback: .serif,
                        gradient: ["#2E241C", "#15100C"], direction: .diagonal, glowColor: "#0A0705", backdrop: .steampunk)),
        // A 70s arch window: the sun rising over terracotta hills, pampas grass swaying.
        Look(name: "bohemian", author: "barn",
             waiting: StateStyle(color: "#C2492E", tint: 0.1, effects: [.pulse], speed: 0.8, intensity: 0.8),
             ready: StateStyle(color: "#6F8F4E", tint: 0.08),
             working: StateStyle(color: "#D9A441", tint: 0.06),
             idle: StateStyle(color: "#A48A76", tint: 0, text: "#8C6E5A"),
             skin: Skin(background: "#F3E3CF", text: "#4A2C2A", dim: "#8C5E4E", border: .none, corner: 10, glow: 0.85,
                        fonts: ["Didot", "Hoefler Text"], fallback: .serif, glowColor: "#F3E3CF", backdrop: .boho)),
        // A tarot card of the desert at night: moon, mesas, saguaros, sun rays, in woodcut colors.
        Look(name: "mystical western", author: "barn",
             waiting: StateStyle(color: "#E2574C", tint: 0.08, effects: [.pulse], speed: 0.8, intensity: 0.9),
             ready: StateStyle(color: "#7E9B78", tint: 0.06),
             working: StateStyle(color: "#D9A85B", tint: 0.04),
             idle: StateStyle(color: "#6B5A7A", tint: 0, text: "#A898B8"),
             skin: Skin(background: "#15122B", text: "#EADBC0", dim: "#C9A98A", border: .none, corner: 6, glow: 0.85,
                        uppercase: true, fonts: ["Rockwell", "Copperplate"], fallback: .serif, glowColor: "#15122B", backdrop: .tarot)),
        // A yellow license plate: red embossed type, a red sun, bolt slots, a sticker in the state's color.
        Look(name: "southwest", author: "barn",
             waiting: StateStyle(color: "#E2574C", tint: 0, effects: [.blink], speed: 1),
             ready: StateStyle(color: "#2E7F7A", tint: 0),
             working: StateStyle(color: "#2A5FA6", tint: 0),
             idle: StateStyle(color: "#8A7A50", tint: 0, text: "#8A5A20"),
             skin: Skin(background: "#F4C820", text: "#B5161B", dim: "#8A1A10", border: .none, corner: 10, glow: 0.85,
                        uppercase: true, fonts: ["DIN Condensed", "Avenir Next Condensed"], fallback: .sans,
                        glowColor: "#F4C820", backdrop: .plate)),
        // Rice paper, a brushed ensō that paints itself, a gold kintsugi seam, a red seal.
        Look(name: "wabi sabi", author: "barn",
             waiting: StateStyle(color: "#A6533A", tint: 0.08, effects: [.pulse], speed: 0.6, intensity: 0.7),
             ready: StateStyle(color: "#6E7F5A", tint: 0.06),
             working: StateStyle(color: "#8A7A64", tint: 0.04),
             idle: StateStyle(color: "#B5ADA1", tint: 0, text: "#8A8276"),
             skin: Skin(background: "#EDE6DA", text: "#2B2723", dim: "#6A645A", border: .none, corner: 4, glow: 0.85,
                        fonts: ["Hiragino Mincho ProN", "Hoefler Text"], fallback: .serif, glowColor: "#EDE6DA", backdrop: .enso)),
        // Sailcloth and navy: a rope border, signal flags, a lighthouse sweeping its beam, scalloped sea.
        Look(name: "nautical", author: "barn",
             waiting: StateStyle(color: "#C8262E", tint: 0.08, effects: [.wiggle], speed: 0.8, intensity: 0.6),
             ready: StateStyle(color: "#1F7A6B", tint: 0.06),
             working: StateStyle(color: "#2B5D8C", tint: 0.04),
             idle: StateStyle(color: "#9AA6B2", tint: 0, text: "#6E7C8A"),
             skin: Skin(background: "#F7F3E8", text: "#0E2A47", dim: "#4F6A86", border: .none, corner: 8, glow: 0.85,
                        uppercase: true, fonts: ["Copperplate", "Avenir Next Condensed"], fallback: .serif,
                        glowColor: "#F7F3E8", backdrop: .harbor)),
        // Engraved ivory: a hatched sperm whale spouting under a red-ink sun, a ship far off.
        Look(name: "scrimshaw", author: "barn",
             waiting: StateStyle(color: "#A3291E", tint: 0.1, effects: [.pulse], speed: 0.8, intensity: 0.8),
             ready: StateStyle(color: "#1F3A4A", tint: 0.08),
             working: StateStyle(color: "#3B3A35", tint: 0.04),
             idle: StateStyle(color: "#A89C80", tint: 0, text: "#7A6E52"),
             skin: Skin(background: "#F3EAD3", text: "#1C1A17", dim: "#5B5547", border: .double, borderColor: "#1C1A17",
                        corner: 2, glow: 0.85, fonts: ["Big Caslon", "Baskerville"], fallback: .serif, glowColor: "#F3EAD3",
                        backdrop: .whale)),
        // A riverside afternoon in dots of pure color that mix in the eye: sun, water glinting, a sailboat.
        Look(name: "pointillism", author: "barn",
             waiting: StateStyle(color: "#E4572E", tint: 0.08, effects: [.pulse], speed: 0.8, intensity: 0.8),
             ready: StateStyle(color: "#5E9A2E", tint: 0.06),
             working: StateStyle(color: "#3E7CB1", tint: 0.04),
             idle: StateStyle(color: "#A9A39A", tint: 0, text: "#7E786E"),
             skin: Skin(background: "#FBF7EE", text: "#1F2A44", dim: "#3A4A6A", border: .none, corner: 8, glow: 0.85,
                        fonts: ["Optima", "Gill Sans"], fallback: .sans, glowColor: "#FBF7EE", backdrop: .seurat)),
        // A designer's pad: blue grid paper, pen handwriting.
        Look(name: "concept sketch", author: "barn",
             waiting: StateStyle(color: "#E0533D", tint: 0.15, effects: [.wiggle], speed: 1, intensity: 0.5),
             ready: StateStyle(color: "#3A8F5C", tint: 0.1),
             working: StateStyle(color: "#3D6FB6", tint: 0.08),
             idle: StateStyle(color: "#A5A5A0", tint: 0, text: "#7E7E78"),
             skin: Skin(background: "#F7F7F2", text: "#2B2B2B", dim: "#6A6A6A", border: .line, borderColor: "#4A4A4A",
                        corner: 6, fonts: ["Bradley Hand", "Noteworthy", "Marker Felt"], fallback: .rounded,
                        pattern: .grid, patternColors: ["#D6E2F0"], patternStrength: 1)),
        // The whole card in 8-bit color cycling, like the party visualizer: neon working, fire and strobe when it needs you.
        Look(name: "color cycle", author: "barn",
             waiting: StateStyle(color: "#FF3355", tint: 0, effects: [.blink], speed: 1),
             ready: StateStyle(color: "#33FF88", tint: 0),
             working: StateStyle(color: "#33CCFF", tint: 0),
             idle: StateStyle(color: "#555577", tint: 0, text: "#C8C8FF"),
             skin: Skin(background: "#000000", text: "#FFFFFF", dim: "#E0E0FF", border: .line, borderColor: "#000000",
                        corner: 0, glow: 1, uppercase: true, fonts: ["Silom", "Chicago", "Monaco"], fallback: .mono,
                        glowColor: "#000000", backdrop: .colorCycle)),
    ]

    /// Seasonal looks, each with an animated scene.
    static let holidays: [Look] = [
        // Flat almond leaves drifting past rainbow arches; a gust when it needs you.
        Look(name: "autumn", author: "barn",
             waiting: StateStyle(color: "#C8372D", tint: 0.08, effects: [.pulse], speed: 0.9, intensity: 0.8),
             ready: StateStyle(color: "#7D8A3A", tint: 0.06),
             working: StateStyle(color: "#DD6B2A", tint: 0.04),
             idle: StateStyle(color: "#A89A86", tint: 0, text: "#7A6A58"),
             skin: Skin(background: "#F3EBDC", text: "#3A2216", dim: "#6B3A22", border: .line, borderColor: "#B5532A",
                        corner: 6, glow: 0.85, fonts: ["Futura"], fallback: .sans, glowColor: "#F3EBDC", backdrop: .leaves)),
        // A striped sun setting behind flat hills, wheat and pumpkins; geese heading south.
        Look(name: "thanksgiving", author: "barn",
             waiting: StateStyle(color: "#C8372D", tint: 0.06, effects: [.pulse], speed: 0.9, intensity: 0.8),
             ready: StateStyle(color: "#7D8A3A", tint: 0.04),
             working: StateStyle(color: "#E2A72E", tint: 0),
             idle: StateStyle(color: "#A89A86", tint: 0, text: "#7A6A58"),
             skin: Skin(background: "#F3EBDC", text: "#3A2216", dim: "#6B3A22", border: .thick, borderColor: "#6B3A22",
                        corner: 4, glow: 0.85, fonts: ["Rockwell", "Georgia"], fallback: .serif, glowColor: "#F3EBDC", backdrop: .harvest)),
        // Night snow on Swiss-poster pines and a white field; a blizzard when it needs you.
        Look(name: "snow day", author: "barn",
             waiting: StateStyle(color: "#E2574C", tint: 0.06, effects: [.pulse], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#8CC2B8", tint: 0.04),
             working: StateStyle(color: "#F3EBDC", tint: 0),
             idle: StateStyle(color: "#5A6E86", tint: 0, text: "#C8D2DE"),
             skin: Skin(background: "#1F3550", text: "#FFFFFF", dim: "#D8E4EE", border: .line, borderColor: "#8CC2B8",
                        corner: 6, glow: 0.85, fonts: ["Futura"], fallback: .sans, glowColor: "#1F3550", backdrop: .snow)),
        // Peppermint: a striped frame that crawls while it works, a spinning mint.
        Look(name: "candy cane", author: "barn",
             waiting: StateStyle(color: "#C8372D", tint: 0.1, effects: [.wiggle], speed: 1, intensity: 0.6),
             ready: StateStyle(color: "#1F5E3B", tint: 0.06),
             working: StateStyle(color: "#C8372D", tint: 0.03),
             idle: StateStyle(color: "#B0A0A0", tint: 0, text: "#7A5A5C"),
             skin: Skin(background: "#F7F4EE", text: "#8E1B1F", dim: "#A0363C", border: .none, corner: 4, glow: 0.85,
                        fonts: ["Rockwell", "Futura"], fallback: .serif, glowColor: "#F7F4EE", backdrop: .candyCane)),
        // A strand of flat bulbs that chase while it works, gold dots, a tree of stacked bars.
        Look(name: "christmas lights", author: "barn",
             waiting: StateStyle(color: "#C8372D", tint: 0.08, effects: [.blink], speed: 1),
             ready: StateStyle(color: "#1F5E3B", tint: 0.04),
             working: StateStyle(color: "#E2A72E", tint: 0),
             idle: StateStyle(color: "#A89A86", tint: 0, text: "#7A6A58"),
             skin: Skin(background: "#F3EBDC", text: "#1E1B18", dim: "#4A433B", border: .thick, borderColor: "#1E1B18",
                        corner: 2, glow: 0.85, fonts: ["Futura"], fallback: .sans, glowColor: "#F3EBDC", backdrop: .lights)),
        // Santa's suit in two inks: scalloped fur, a black belt, a gold buckle that glints.
        Look(name: "santa", author: "barn",
             waiting: StateStyle(color: "#E2A72E", tint: 0.04, effects: [.pulse], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#1F5E3B", tint: 0.08),
             working: StateStyle(color: "#F7F4EE", tint: 0),
             idle: StateStyle(color: "#8E4A42", tint: 0, text: "#F0C8C0"),
             skin: Skin(background: "#C8372D", text: "#FFFFFF", dim: "#F6DCD2", border: .none, corner: 4, glow: 0.85,
                        fonts: ["Rockwell", "Georgia"], fallback: .serif, glowColor: "#9E2A22", backdrop: .santa)),
        // A folk-art reindeer: trots while it works, jumps when it needs you, grazes when idle.
        Look(name: "reindeer", author: "barn",
             waiting: StateStyle(color: "#C8372D", tint: 0.04, effects: [.pulse], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#8CC2B8", tint: 0.04),
             working: StateStyle(color: "#E2A72E", tint: 0),
             idle: StateStyle(color: "#4A5A7A", tint: 0, text: "#A8B8D0"),
             skin: Skin(background: "#1B2A4A", text: "#F3EBDC", dim: "#C8D2DE", border: .line, borderColor: "#E2A72E",
                        corner: 6, glow: 0.85, fonts: ["Futura"], fallback: .sans, glowColor: "#1B2A4A", backdrop: .reindeer)),
        // A gold menorah on an art-deco sunburst: the shamash alone when idle, all nine otherwise.
        Look(name: "hanukkah", author: "barn",
             waiting: StateStyle(color: "#E2A72E", tint: 0.04, effects: [.pulse], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#FFFFFF", tint: 0.04),
             working: StateStyle(color: "#BFD3F2", tint: 0),
             idle: StateStyle(color: "#4A6A9A", tint: 0, text: "#A8B8E0"),
             skin: Skin(background: "#1F4E8C", text: "#FFFFFF", dim: "#D6E2F2", border: .double, borderColor: "#E2A72E",
                        corner: 4, glow: 0.85, fonts: ["Didot", "Georgia"], fallback: .serif, glowColor: "#1F4E8C", backdrop: .menorah)),
        // Mid-century trees in teal and red under atomic snowflakes and stars.
        Look(name: "atomic christmas", author: "barn",
             waiting: StateStyle(color: "#C8372D", tint: 0.08, effects: [.wiggle], speed: 1, intensity: 0.6),
             ready: StateStyle(color: "#2F8A84", tint: 0.06),
             working: StateStyle(color: "#2F8A84", tint: 0),
             idle: StateStyle(color: "#A89A86", tint: 0, text: "#7A6A58"),
             skin: Skin(background: "#F3EBDC", text: "#1E1B18", dim: "#4A433B", border: .line, borderColor: "#2F8A84",
                        corner: 4, glow: 0.85, fonts: ["Futura"], fallback: .sans, glowColor: "#F3EBDC", backdrop: .atomic)),
        // Swiss-poster tiles in green, red and paper, each shape turning a quarter at a time.
        Look(name: "bauhaus noel", author: "barn",
             waiting: StateStyle(color: "#C8372D", tint: 0.85, effects: [.blink], speed: 1),
             ready: StateStyle(color: "#1F5E3B", tint: 0.06),
             working: StateStyle(color: "#1E1B18", tint: 0),
             idle: StateStyle(color: "#A89A86", tint: 0, text: "#7A6A58"),
             skin: Skin(background: "#F3EBDC", text: "#1E1B18", dim: "#4A433B", border: .none, corner: 0, glow: 0.85,
                        fonts: ["Futura", "Helvetica Neue"], fallback: .sans, glowColor: "#F3EBDC", backdrop: .tiles)),
    ]

    /// Characters that act out each state at the top of the card (Mascot.swift).
    static let friends: [Look] = [
        // A dark visor with glowing eyes: asleep, scanning, wide-eyed, happy.
        Look(name: "robot eyes", author: "barn",
             waiting: StateStyle(color: "#FF4D6D", tint: 0, effects: [.glow], speed: 1, intensity: 0.7),
             ready: StateStyle(color: "#5CFFA8", tint: 0),
             working: StateStyle(color: "#4DD8FF", tint: 0),
             idle: StateStyle(color: "#5A6B7C", tint: 0, text: "#6F8090"),
             skin: Skin(background: "#0B0F14", text: "#CFF8FF", dim: "#6F8090", border: .line,
                        borderColor: "#22303C", corner: 18, glow: 0.5, fallback: .rounded,
                        gradient: ["#151D27"], gloss: 0.12, mascot: .eyes)),
        // A white plastic robot with a face on its screen: eyes and a mouth.
        Look(name: "robot face", author: "barn",
             waiting: StateStyle(color: "#FF5A7A", tint: 0, effects: [.wiggle], speed: 1, intensity: 0.6),
             ready: StateStyle(color: "#3DDC97", tint: 0),
             working: StateStyle(color: "#3FC8FF", tint: 0),
             idle: StateStyle(color: "#8A97A8", tint: 0, text: "#6E7888"),
             skin: Skin(background: "#F7F9FC", text: "#2A3340", dim: "#6E7888", border: .line,
                        borderColor: "#C9D2DC", corner: 20, fallback: .rounded,
                        gradient: ["#DDE3EA"], gloss: 0.5, mascot: .face)),
        // Asleep, pawing at the glass for help, running its wheel, drinking when it's done.
        Look(name: "chubby hamster", author: "barn",
             waiting: StateStyle(color: "#E2513A", tint: 0.1, effects: [.pulse], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#2F9E6A", tint: 0.08),
             working: StateStyle(color: "#C9701C", tint: 0),
             idle: StateStyle(color: "#A08C74", tint: 0, text: "#8F7A62"),
             skin: Skin(background: "#F6EBD6", text: "#3A2414", dim: "#7A5A3E", border: .none, corner: 8,
                        fonts: ["Futura", "Avenir Next"], fallback: .rounded, stateFrame: true, mascot: .hamster)),
        // A goldfish bowl drawn badly in Paint with the crayon brush, lines boiling.
        Look(name: "fishbowl", author: "barn",
             waiting: StateStyle(color: "#ED1C24", tint: 0.08, effects: [.pulse], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#22B14C", tint: 0.06),
             working: StateStyle(color: "#00A2E8", tint: 0),
             idle: StateStyle(color: "#7F7F7F", tint: 0, text: "#6E6E6E"),
             skin: Skin(background: "#FFFFFF", text: "#000000", dim: "#5A5A5A", border: .line,
                        borderColor: "#000000", corner: 3, fonts: ["Comic Sans MS"], fallback: .rounded,
                        mascot: .fishbowl)),
        // Pixel art in two-frame GIF loops: asleep, paws on the glass, in the wheel, at the bottle.
        Look(name: "pixel hamster", author: "barn",
             waiting: StateStyle(color: "#E8344E", tint: 0.08, effects: [.pulse], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#2F9E6A", tint: 0.06),
             working: StateStyle(color: "#C9701C", tint: 0),
             idle: StateStyle(color: "#A08C74", tint: 0, text: "#8F7A62"),
             skin: Skin(background: "#FFF8E7", text: "#3B2414", dim: "#8A6A4E", border: .bevel, corner: 0,
                        fonts: ["Comic Sans MS"], fallback: .rounded, mascot: .pixelHamster)),
        // Clock, beep beep, spinning under a warm light, food steaming.
        Look(name: "microwave", author: "barn",
             waiting: StateStyle(color: "#E5484D", tint: 0.08, effects: [.wiggle], speed: 1, intensity: 0.6),
             ready: StateStyle(color: "#2FA36B", tint: 0.06),
             working: StateStyle(color: "#E08A00", tint: 0.06, effects: [.glow], speed: 0.8, intensity: 0.6),
             idle: StateStyle(color: "#94A3B8", tint: 0, text: "#6F7B88"),
             skin: Skin(background: "#F8FAFC", text: "#2B2F36", dim: "#6F7B88", border: .line,
                        borderColor: "#C9D1D9", corner: 12, fallback: .rounded,
                        pattern: .grid, patternColors: ["#DCE3EA"], patternStrength: 0.8, mascot: .microwave)),
        // Cold, heating, whistling, and a cup of tea when it's done.
        Look(name: "kettle", author: "barn",
             waiting: StateStyle(color: "#D9473B", tint: 0.06, effects: [.wiggle], speed: 1, intensity: 0.5),
             ready: StateStyle(color: "#4F8F4B", tint: 0.06),
             working: StateStyle(color: "#C9701C", tint: 0),
             idle: StateStyle(color: "#A08C7C", tint: 0, text: "#8A7464"),
             skin: Skin(background: "#F3EBDC", text: "#1E1B18", dim: "#5A5248", border: .none, corner: 8,
                        fonts: ["Futura", "Avenir Next"], fallback: .rounded, mascot: .kettle)),
    ]

    /// Toys, school supplies and late-90s sparkle.
    static let whimsy: [Look] = [
        // Sky, water and grass, all gloss: liquid sloshing and bubbles rising while it works.
        Look(name: "frutiger aero", author: "barn",
             waiting: StateStyle(color: "#FF6FAE", tint: 0.45, effects: [.glow, .bubbles], speed: 1.1, intensity: 0.9),
             ready: StateStyle(color: "#6BE36B", tint: 0.4, effects: [.shimmer], speed: 0.8, intensity: 0.7),
             working: StateStyle(color: "#00C2FF", tint: 0.15, effects: [.wave, .bubbles], speed: 1, intensity: 0.9),
             idle: StateStyle(color: "#BFE6F7", tint: 0.35),
             skin: Skin(background: "#9EE3FF", text: "#FFFFFF", dim: "#EAF9FF", border: .line,
                        borderColor: "#FFFFFF", corner: 18, glow: 0.85,
                        fonts: ["Segoe UI", "Frutiger", "Myriad Pro", "Avenir Next"], fallback: .sans,
                        gradient: ["#3DB8F5", "#1E90E0", "#6FD86A"], pattern: .bubbles,
                        patternColors: ["#FFFFFF"], patternStrength: 0.6, gloss: 0.75, glowColor: "#0A5C99")),
        // Waxy primaries on paper; each state's frame is its crayon.
        Look(name: "crayon box", author: "barn",
             waiting: StateStyle(color: "#ED0A3F", tint: 0.12, effects: [.wiggle], speed: 1, intensity: 0.8),
             ready: StateStyle(color: "#1CAC78", tint: 0.12),
             working: StateStyle(color: "#1F75FE", tint: 0.08, effects: [.pulse], speed: 0.8, intensity: 0.6),
             idle: StateStyle(color: "#95918C", tint: 0, text: "#8A8580"),
             skin: Skin(background: "#FFFDF4", text: "#2B2B2B", dim: "#7A746C", border: .thick, corner: 14,
                        fonts: ["Chalkboard SE", "Marker Felt", "Comic Sans MS"], fallback: .rounded,
                        pattern: .grain, patternColors: ["#C8B89A"], patternStrength: 0.45, stateFrame: true)),
        // A neon rainbow with sparkles, outlined type and bouncing.
        Look(name: "rainbow sticker", author: "barn",
             waiting: StateStyle(color: "#FF2E97", tint: 0, effects: [.rainbow, .bounce], speed: 1.1, intensity: 1),
             ready: StateStyle(color: "#00E0B0", tint: 0, effects: [.glow], speed: 0.8, intensity: 0.8),
             working: StateStyle(color: "#7B2FFF", tint: 0, effects: [.shimmer], speed: 0.9, intensity: 0.8),
             idle: StateStyle(color: "#FFFFFF", tint: 0.55, text: "#5B1A8C"),
             skin: Skin(background: "#F72585", text: "#FFFFFF", dim: "#FFF0FA", border: .thick,
                        borderColor: "#FFFFFF", corner: 16, glow: 0.9,
                        fonts: ["Chalkboard SE", "Marker Felt"], fallback: .rounded,
                        gradient: ["#FF9E00", "#FFE14D", "#2EC4B6", "#4D96FF", "#B15EFF"], direction: .diagonal,
                        pattern: .sparkles, patternColors: ["#FFFFFF"], patternStrength: 0.85, gloss: 0.3,
                        glowColor: "#5B1A8C")),
        // Glowing pegs on a black board full of holes.
        Look(name: "peg board", author: "barn",
             waiting: StateStyle(color: "#FF3B3B", tint: 0, effects: [.glow, .pulse], speed: 1, intensity: 0.9, text: "#FF5A5A"),
             ready: StateStyle(color: "#3BFF6E", tint: 0, text: "#5CFF88"),
             working: StateStyle(color: "#3BB8FF", tint: 0, effects: [.cursor], speed: 1, text: "#5CC6FF"),
             idle: StateStyle(color: "#FFE14D", tint: 0, text: "#8A7A2A"),
             skin: Skin(background: "#0A0A0A", text: "#FFFFFF", dim: "#9A9A9A", corner: 6, glow: 1,
                        fonts: ["Arial Rounded MT Bold", "Chalkboard SE"], fallback: .rounded,
                        pattern: .dots, patternColors: ["#2E2E2E"], patternStrength: 0.9)),
        // Aluminum-gray screen in a fat red frame. Shake it when it needs you.
        Look(name: "sketch screen", author: "barn",
             waiting: StateStyle(color: "#3A3A3A", tint: 0, effects: [.wiggle], speed: 1.2, intensity: 1),
             ready: StateStyle(color: "#3A3A3A", tint: 0.18),
             working: StateStyle(color: "#3A3A3A", tint: 0, effects: [.cursor], speed: 0.8),
             idle: StateStyle(color: "#808078", tint: 0, text: "#6E6E66"),
             skin: Skin(background: "#CFCFC6", text: "#2E2E2E", dim: "#5E5E58", border: .heavy,
                        borderColor: "#D0021B", corner: 10, fonts: ["Noteworthy", "Bradley Hand", "Chalkboard SE"],
                        fallback: .rounded, pattern: .grain, patternColors: ["#9A9A92"], patternStrength: 0.35)),
        // Ruled paper in pen, highlighted when it needs you.
        Look(name: "notebook", author: "barn",
             waiting: StateStyle(color: "#FFE600", tint: 0.55, effects: [.bounce], speed: 0.8, intensity: 0.7),
             ready: StateStyle(color: "#9BFF5A", tint: 0.5),
             working: StateStyle(color: "#2251FF", tint: 0, effects: [.cursor], speed: 1),
             idle: StateStyle(color: "#9AA3B5", tint: 0, text: "#7D869A"),
             skin: Skin(background: "#FFFFFF", text: "#1F2A44", dim: "#6B7A99", corner: 2,
                        fonts: ["Noteworthy", "Bradley Hand", "Marker Felt"], fallback: .rounded,
                        pattern: .ruled, patternColors: ["#A7C7E7"], patternStrength: 1)),
        // A neon-on-midnight school binder with confetti.
        Look(name: "binder", author: "barn",
             waiting: StateStyle(color: "#FF2E97", tint: 1, effects: [.blink], speed: 0.8),
             ready: StateStyle(color: "#39FF14", tint: 0, effects: [.glow], speed: 0.8, intensity: 0.8),
             working: StateStyle(color: "#00E5FF", tint: 0, effects: [.lines], speed: 1, intensity: 0.8),
             idle: StateStyle(color: "#8A7FB0", tint: 0, text: "#8A7FB0"),
             skin: Skin(background: "#1B1B3A", text: "#FFFFFF", dim: "#B8B0E0", border: .thick,
                        borderColor: "#00E5FF", corner: 4, shadow: .hard, glow: 0.3, uppercase: true,
                        fonts: ["Futura", "Avenir Next Condensed"], fallback: .sans,
                        gradient: ["#2D1B4E"], direction: .diagonal,
                        pattern: .confetti, patternColors: ["#FF2E97", "#00E5FF", "#FFE14D", "#39FF14"],
                        patternStrength: 0.3)),
        // Bubbly chrome, sparkles and Comic Sans.
        Look(name: "y2k", author: "barn",
             waiting: StateStyle(color: "#FF00CC", tint: 0.75, effects: [.rainbow], speed: 1, intensity: 0.9, text: "#FFFFFF"),
             ready: StateStyle(color: "#00CC66", tint: 0.7),
             working: StateStyle(color: "#0066FF", tint: 0, effects: [.orbit], speed: 1, intensity: 0.9),
             idle: StateStyle(color: "#6A7480", tint: 0, text: "#5E6874"),
             skin: Skin(background: "#F5F7FA", text: "#1A1A6E", dim: "#5A6478", border: .line,
                        borderColor: "#7A8BA0", corner: 18, fonts: ["Comic Sans MS"], prompt: "★", fallback: .rounded,
                        gradient: ["#B8C2CC", "#E8ECF0", "#A9B4C0"], pattern: .sparkles,
                        patternColors: ["#FFFFFF"], patternStrength: 0.9, gloss: 0.6)),
    ]
}

// MARK: Sharing (JSON)

extension Look: Codable {
    private enum Keys: String, CodingKey {
        case version = "barn-look", name, author, states, skin
    }

    /// The state names in shared JSON, chosen to read well to people.
    static func key(for state: AgentState) -> String {
        switch state {
        case .waiting: "needs-you"
        case .ready: "ready"
        case .working: "working"
        case .idle: "idle"
        }
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: Keys.self)
        guard c.contains(.version) || c.contains(.states) else {
            throw DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "not a barn look"))
        }
        let states = try c.decodeIfPresent([String: LenientStyle].self, forKey: .states) ?? [:]
        let name = (try? c.decodeIfPresent(String.self, forKey: .name)).flatMap { $0 }?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        self = .barn
        self.name = name?.isEmpty == false ? String(name!.prefix(40)) : "shared look"
        author = (try? c.decodeIfPresent(String.self, forKey: .author)).flatMap { $0 }.map { String($0.prefix(40)) }
        for state in AgentState.allCases {
            if let s = states[Self.key(for: state)] { self[state] = s.apply(to: Look.barn[state]) }
        }
        skin = (try? c.decodeIfPresent(LenientSkin.self, forKey: .skin)).flatMap { $0 }?.skin
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(Self.formatVersion, forKey: .version)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(author, forKey: .author)
        var states: [String: LenientStyle] = [:]
        for state in AgentState.allCases { states[Self.key(for: state)] = LenientStyle(self[state]) }
        try c.encode(states, forKey: .states)
        try c.encodeIfPresent(skin.map(LenientSkin.init), forKey: .skin)
    }

    /// The JSON people paste to each other.
    var json: String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return (try? encoder.encode(self)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
    }

    /// Parses shared JSON, tolerating the extra text people paste around it (a ```json fence,
    /// a chat message).
    static func parse(_ text: String) throws -> Look {
        guard let start = text.firstIndex(of: "{"), let end = text.lastIndex(of: "}"), start < end else {
            throw LookError.notJSON
        }
        do {
            return try JSONDecoder().decode(Look.self, from: Data(text[start...end].utf8))
        } catch DecodingError.dataCorrupted(let ctx) where ctx.codingPath.isEmpty && ctx.underlyingError == nil {
            throw LookError.notALook
        } catch {
            throw LookError.notJSON
        }
    }
}

enum LookError: LocalizedError {
    case notJSON, notALook
    var errorDescription: String? {
        switch self {
        case .notJSON: "that isn't JSON barn can read"
        case .notALook: "that JSON isn't a barn look (it has no \"barn-look\" or \"states\")"
        }
    }
}

/// One state in shared JSON. Every field is optional; bad values fall back instead of failing.
private struct LenientStyle: Codable {
    var color: String?
    var darkColor: String?
    var tint: Double?
    var effects: [String]?
    var speed: Double?
    var intensity: Double?
    var text: String?

    enum CodingKeys: String, CodingKey {
        case color, darkColor = "dark-color", tint, effects, speed, intensity, text
    }

    init(_ s: StateStyle) {
        color = s.color
        darkColor = s.darkColor
        tint = s.tint
        effects = s.effects.map(\.rawValue)
        speed = s.speed
        intensity = s.intensity
        text = s.text
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        color = try? c.decodeIfPresent(String.self, forKey: .color)
        darkColor = try? c.decodeIfPresent(String.self, forKey: .darkColor)
        tint = try? c.decodeIfPresent(Double.self, forKey: .tint)
        effects = (try? c.decodeIfPresent([String].self, forKey: .effects))
            ?? (try? c.decodeIfPresent(String.self, forKey: .effects)).flatMap { $0.map { [$0] } }
        speed = try? c.decodeIfPresent(Double.self, forKey: .speed)
        intensity = try? c.decodeIfPresent(Double.self, forKey: .intensity)
        text = try? c.decodeIfPresent(String.self, forKey: .text)
    }

    func apply(to base: StateStyle) -> StateStyle {
        var s = base
        if let color, NSColor(hex: color) != nil { s.color = color }
        // A shared look that sets a color without a dark one means that color in both modes.
        if color != nil || darkColor != nil { s.darkColor = darkColor }
        if let tint { s.tint = tint }
        if let effects { s.effects = effects.compactMap { Effect(rawValue: $0.lowercased()) } }
        if let speed { s.speed = speed }
        if let intensity { s.intensity = intensity }
        if let text { s.text = text }
        return s.clamped()
    }
}

/// A skin in shared JSON. Only a background and text color are needed; anything bad or
/// missing falls back.
private struct LenientSkin: Codable {
    var background: String?
    var text: String?
    var dim: String?
    var border: String?
    var borderColor: String?
    var corner: Double?
    var shadow: String?
    var scanlines: Double?
    var glow: Double?
    var uppercase: Bool?
    var fonts: [String]?
    var prompt: String?
    var fallback: String?
    var gradient: [String]?
    var direction: String?
    var pattern: String?
    var patternColors: [String]?
    var patternStrength: Double?
    var gloss: Double?
    var glowColor: String?
    var stateFrame: Bool?
    var titleBar: LenientTitleBar?
    var mascot: String?
    var backdrop: String?

    enum CodingKeys: String, CodingKey {
        case background, text, dim, border, borderColor = "border-color", corner, shadow, scanlines, glow,
             uppercase, fonts, prompt, fallback, gradient, direction, pattern, patternColors = "pattern-colors",
             patternStrength = "pattern-strength", gloss, glowColor = "glow-color", stateFrame = "state-frame",
             titleBar = "title-bar", mascot, backdrop
    }

    /// Writes only what differs from a plain skin, so shared JSON stays short.
    init(_ s: Skin) {
        background = s.background
        text = s.text
        dim = s.dim
        border = s.border.rawValue
        borderColor = s.borderColor
        corner = s.corner
        shadow = s.shadow.rawValue
        scanlines = s.scanlines
        glow = s.glow
        uppercase = s.uppercase
        fonts = s.fonts.isEmpty ? nil : s.fonts
        prompt = s.prompt
        fallback = s.fallback == .mono ? nil : s.fallback.rawValue
        gradient = s.gradient.isEmpty ? nil : s.gradient
        direction = s.gradient.isEmpty ? nil : s.direction.rawValue
        pattern = s.pattern == .none ? nil : s.pattern.rawValue
        patternColors = s.patternColors.isEmpty ? nil : s.patternColors
        patternStrength = s.pattern == .none ? nil : s.patternStrength
        gloss = s.gloss == 0 ? nil : s.gloss
        glowColor = s.glowColor
        stateFrame = s.stateFrame ? true : nil
        titleBar = s.titleBar.map(LenientTitleBar.init)
        mascot = s.mascot == .none ? nil : s.mascot.rawValue
        backdrop = s.backdrop == .none ? nil : s.backdrop.rawValue
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func string(_ k: CodingKeys) -> String? { (try? c.decodeIfPresent(String.self, forKey: k)).flatMap { $0 } }
        func number(_ k: CodingKeys) -> Double? { (try? c.decodeIfPresent(Double.self, forKey: k)).flatMap { $0 } }
        func list(_ k: CodingKeys) -> [String]? {
            (try? c.decodeIfPresent([String].self, forKey: k)).flatMap { $0 } ?? string(k).map { [$0] }
        }
        background = string(.background)
        text = string(.text)
        dim = string(.dim)
        border = string(.border)
        borderColor = string(.borderColor)
        corner = number(.corner)
        shadow = string(.shadow)
        scanlines = number(.scanlines)
        glow = number(.glow)
        uppercase = (try? c.decodeIfPresent(Bool.self, forKey: .uppercase)).flatMap { $0 }
        fonts = list(.fonts)
        prompt = string(.prompt)
        fallback = string(.fallback)
        gradient = list(.gradient)
        direction = string(.direction)
        pattern = string(.pattern)
        patternColors = list(.patternColors)
        patternStrength = number(.patternStrength)
        gloss = number(.gloss)
        glowColor = string(.glowColor)
        stateFrame = (try? c.decodeIfPresent(Bool.self, forKey: .stateFrame)).flatMap { $0 }
        titleBar = (try? c.decodeIfPresent(LenientTitleBar.self, forKey: .titleBar)).flatMap { $0 }
        mascot = string(.mascot)
        backdrop = string(.backdrop)
    }

    var skin: Skin? {
        guard let background, NSColor(hex: background) != nil else { return nil }
        var s = Skin(background: background, text: text ?? "#FFFFFF")
        s.dim = dim
        s.border = border.flatMap { Skin.Border(rawValue: $0.lowercased()) } ?? .none
        s.borderColor = borderColor
        s.corner = corner ?? 0
        s.shadow = shadow.flatMap { Skin.Shadow(rawValue: $0.lowercased()) } ?? .none
        s.scanlines = scanlines ?? 0
        s.glow = glow ?? 0
        s.uppercase = uppercase ?? false
        s.fonts = fonts ?? []
        s.prompt = prompt
        s.fallback = fallback.flatMap { Skin.Fallback(rawValue: $0.lowercased()) } ?? .mono
        s.gradient = gradient ?? []
        s.direction = direction.flatMap { Skin.Direction(rawValue: $0.lowercased()) } ?? .down
        s.pattern = pattern.flatMap { Skin.Pattern(rawValue: $0.lowercased()) } ?? .none
        s.patternColors = patternColors ?? []
        s.patternStrength = patternStrength ?? 0.5
        s.gloss = gloss ?? 0
        s.glowColor = glowColor
        s.stateFrame = stateFrame ?? false
        s.titleBar = titleBar?.bar
        s.mascot = mascot.flatMap { Skin.Mascot(rawValue: $0.lowercased()) } ?? .none
        s.backdrop = backdrop.flatMap { Skin.Backdrop(rawValue: $0.lowercased()) } ?? .none
        return s.clamped()
    }
}

private struct LenientTitleBar: Codable {
    var color: String?
    var end: String?
    var fade: Double?
    var direction: String?
    var text: String?
    var height: Double?
    var buttons: String?
    var stripes: Bool?
    var gloss: Double?
    var inactive: String?

    init(_ b: Skin.TitleBar) {
        color = b.color
        end = b.end
        fade = b.fade == 0 ? nil : b.fade
        direction = b.direction.rawValue
        text = b.text
        height = b.height
        buttons = b.buttons == .none ? nil : b.buttons.rawValue
        stripes = b.stripes ? true : nil
        gloss = b.gloss == 0 ? nil : b.gloss
        inactive = b.inactive
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        func string(_ k: CodingKeys) -> String? { (try? c.decodeIfPresent(String.self, forKey: k)).flatMap { $0 } }
        func number(_ k: CodingKeys) -> Double? { (try? c.decodeIfPresent(Double.self, forKey: k)).flatMap { $0 } }
        color = string(.color)
        end = string(.end)
        fade = number(.fade)
        direction = string(.direction)
        text = string(.text)
        height = number(.height)
        buttons = string(.buttons)
        stripes = (try? c.decodeIfPresent(Bool.self, forKey: .stripes)).flatMap { $0 }
        gloss = number(.gloss)
        inactive = string(.inactive)
    }

    var bar: Skin.TitleBar {
        var b = Skin.TitleBar()
        b.color = color
        b.end = end
        b.fade = fade ?? 0
        b.direction = direction.flatMap { Skin.Direction(rawValue: $0.lowercased()) } ?? .across
        b.text = text
        b.height = height ?? 15
        b.buttons = buttons.flatMap { Skin.TitleBar.Buttons(rawValue: $0.lowercased()) } ?? .none
        b.stripes = stripes ?? false
        b.gloss = gloss ?? 0
        b.inactive = inactive
        return b.clamped()
    }
}

/// A look saved in the user's library. Presets aren't saved; they're always the built-in ones.
struct SavedLook: Codable, Identifiable, Equatable {
    var id: String
    var look: Look
}

extension AgentState: CaseIterable {
    static var allCases: [AgentState] { [.waiting, .ready, .working, .idle] }
}

extension NSColor {
    /// "#RGB", "#RRGGBB" or "#RRGGBBAA" (the # is optional).
    convenience init?(hex: String) {
        var s = hex.trimmingCharacters(in: .whitespaces)
        if s.hasPrefix("#") { s.removeFirst() }
        if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
        guard s.count == 6 || s.count == 8, let v = UInt64(s, radix: 16) else { return nil }
        let rgba = s.count == 6 ? v << 8 | 0xFF : v
        self.init(srgbRed: CGFloat(rgba >> 24 & 0xFF) / 255, green: CGFloat(rgba >> 16 & 0xFF) / 255,
                  blue: CGFloat(rgba >> 8 & 0xFF) / 255, alpha: CGFloat(rgba & 0xFF) / 255)
    }

    var hex: String {
        let c = usingColorSpace(.sRGB) ?? self
        let v = [c.redComponent, c.greenComponent, c.blueComponent].map { Int(($0 * 255).rounded()) }
        return String(format: "#%02X%02X%02X", v[0], v[1], v[2])
    }
}
