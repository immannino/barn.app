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
    ]
}

// MARK: Sharing (JSON)

extension Look: Codable {
    private enum Keys: String, CodingKey {
        case version = "barn-look", name, author, states
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
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: Keys.self)
        try c.encode(Self.formatVersion, forKey: .version)
        try c.encode(name, forKey: .name)
        try c.encodeIfPresent(author, forKey: .author)
        var states: [String: LenientStyle] = [:]
        for state in AgentState.allCases { states[Self.key(for: state)] = LenientStyle(self[state]) }
        try c.encode(states, forKey: .states)
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

    enum CodingKeys: String, CodingKey {
        case color, darkColor = "dark-color", tint, effects, speed, intensity
    }

    init(_ s: StateStyle) {
        color = s.color
        darkColor = s.darkColor
        tint = s.tint
        effects = s.effects.map(\.rawValue)
        speed = s.speed
        intensity = s.intensity
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
        return s.clamped()
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
