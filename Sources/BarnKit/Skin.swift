import AppKit
import SwiftUI

/// An opaque surface for a look's cards in place of glass, for looks after old computers,
/// desktops and toys: a solid or gradient background, a fixed text palette, frames, title bars,
/// patterns, scanlines, gloss and glow. A look without a skin is glass. In shared JSON:
///
///     "skin" : { "background" : "#C0C0C0", "text" : "#000000", "border" : "bevel",
///                "title-bar" : { "fade" : 0.6, "buttons" : "win" },
///                "fonts" : ["Microsoft Sans Serif"], "fallback" : "sans" }
///
/// With a skin, a state's `tint` is how far its color fills the card (1 is a solid block of
/// that color, like inverse video), and its color is used for status text and dots wherever it
/// reads on the background. The drawing is in SkinViews.swift.
struct Skin: Equatable {
    /// "#RRGGBB" behind every card: the gradient's first stop.
    var background: String
    /// Primary text.
    var text: String
    /// Secondary text (times, badges); nil dims `text`.
    var dim: String? = nil
    var border: Border = .none
    /// nil uses `text`.
    var borderColor: String? = nil
    /// Corner radius in points at size m; 0 is square.
    var corner: Double = 0
    var shadow: Shadow = .none
    /// CRT lines across the card, 0…1.
    var scanlines: Double = 0
    /// Bloom around the text, 0…1.
    var glow: Double = 0
    var uppercase: Bool = false
    /// Font families to try in order. The first one installed wins, else the system font in `fallback`.
    var fonts: [String] = []
    /// Stands in for the switcher's search icon, like Apple II's "]" or DOS's "C:\>".
    var prompt: String? = nil
    var fallback: Fallback = .mono
    /// More background stops after `background`, for a gradient.
    var gradient: [String] = []
    var direction: Direction = .down
    var pattern: Pattern = .none
    /// The pattern's colors; nil uses the text color. Confetti cycles through all of them.
    var patternColors: [String] = []
    /// 0…1.
    var patternStrength: Double = 0.5
    /// A glassy highlight over the top half, 0…1.
    var gloss: Double = 0
    /// The glow's color; nil glows in the text's own color. A dark one outlines light text.
    var glowColor: String? = nil
    /// The frame takes each state's color instead of `borderColor`.
    var stateFrame: Bool = false
    /// A window title bar across the top of each card.
    var titleBar: TitleBar? = nil
    /// A character at the top of each card that acts out the state (Mascot.swift).
    var mascot: Mascot = .none
    /// An animated scene filling the whole card behind its text.
    var backdrop: Backdrop = .none

    enum Backdrop: String, CaseIterable, Codable {
        case none
        /// Stars drifting in three depths and a nebula breathing in the state's colors.
        case galaxy
        /// A striped neon sun over mountains and a grid floor racing toward you.
        case synthwave
        /// The same horizon in pastels.
        case vaporwave
        /// A wireframe horizon in glowing green, like a vector arcade game.
        case vectorGreen = "vector-green"
        /// The same in war-room blue.
        case vectorBlue = "vector-blue"
        /// Brass gears with a metal sheen turning on a riveted plate, steam venting.
        case steampunk
        /// A stained-glass lancet window glowing in the state's color, candlelight flickering.
        case gothic
        /// Maple leaves tumbling down onto a pile.
        case leaves
        /// A wheat field swaying under a low harvest sun, pumpkins, geese flying over.
        case harvest
        /// Snow falling in layers onto drifts and pines.
        case snow
        /// A striped peppermint frame and a spinning peppermint.
        case candyCane = "candy-cane"
        /// Swags of Christmas lights that chase, flash or glow.
        case lights
        /// Santa's suit: velvet, fur trim, a belt with a glinting buckle.
        case santa
        /// The sleigh and reindeer crossing the moon over snowy rooftops.
        case sleigh
        /// A menorah, its candles flickering.
        case menorah
        /// Mid-century trees and atomic snowflakes.
        case atomic
        /// Bauhaus tiles in green, red and paper, turning.
        case tiles
        /// The whole card cycling through an 8-bit palette.
        case colorCycle = "color-cycle"
        /// A yellow license plate with a red sun.
        case plate
        /// A tarot card of the desert at night.
        case tarot
        /// A riverside scene painted in dots.
        case seurat
        /// An ensō, a kintsugi seam, a seal.
        case enso
        /// An engraved whale under a red sun.
        case whale
        /// Rope, signal flags, a lighthouse.
        case harbor
        /// An arch window with a sun and pampas grass.
        case boho
        /// One folk-art reindeer.
        case reindeer
    }

    enum Mascot: String, CaseIterable, Codable {
        case none
        /// A robot's glowing eyes.
        case eyes
        /// A robot's face on a little screen: eyes and a mouth.
        case face
        /// A hamster: asleep, pawing at the glass, running its wheel, drinking.
        case hamster
        /// A crayon goldfish, badly drawn in Paint: dozing, at the glass blowing bubbles, swimming
        /// laps, eating flakes.
        case fishbowl
        /// A microwave: showing the clock, beeping, spinning and glowing, food steaming.
        case microwave
        /// A kettle on the stove: cold, heating, whistling, a cup of tea poured.
        case kettle
        /// A pixel-art hamster in two-frame GIF animation, after the old web's dancing hamsters.
        case pixelHamster = "pixel-hamster"
        /// A pixel waterfall at night, animated by cycling its palette like old demo art.
        case colorCycle = "color-cycle"
    }

    enum Border: String, CaseIterable, Codable {
        /// No frame.
        case none
        /// A one-pixel frame.
        case line
        /// Two thin frames, like DOS's ╔═╗ boxes.
        case double
        /// A heavy frame.
        case thick
        /// A very heavy frame, like a toy's plastic case.
        case heavy
        /// Lit from the top left: a raised button.
        case bevel
    }

    enum Shadow: String, CaseIterable, Codable {
        case none
        /// A solid offset block, like DOS dialogs and old Mac windows.
        case hard
    }

    enum Fallback: String, CaseIterable, Codable {
        case mono, sans, rounded, serif

        var design: Font.Design {
            switch self {
            case .mono: .monospaced
            case .sans: .default
            case .rounded: .rounded
            case .serif: .serif
            }
        }
    }

    enum Direction: String, CaseIterable, Codable {
        case down, across, diagonal

        var points: (UnitPoint, UnitPoint) {
            switch self {
            case .down: (.top, .bottom)
            case .across: (.leading, .trailing)
            case .diagonal: (.topLeading, .bottomTrailing)
            }
        }
    }

    enum Pattern: String, CaseIterable, Codable {
        case none
        /// A 50% pixel checkerboard, the classic 1-bit gray.
        case dither
        case checker
        /// Diagonal stripes.
        case stripes
        /// Thin horizontal lines, like early Mac OS X.
        case pinstripes
        /// Notebook paper: blue lines and a red margin.
        case ruled
        /// An LCD's pixel grid.
        case grid
        /// Peg holes.
        case dots
        /// Paper and crayon texture.
        case grain
        /// 80s scattered shapes.
        case confetti
        /// Twinkles.
        case sparkles
        /// Glossy bubbles.
        case bubbles
        /// Bold squiggles, zigzags and shapes, Memphis Group style.
        case memphis
        /// Big circles, half circles and squares in primaries.
        case bauhaus
        /// Rows of scalloped waves.
        case waves
        /// Pen crosshatching.
        case hatch
        /// Dots of many colors, like a pointillist painting.
        case stipple
        /// Zigzags and stepped diamonds, like a woven blanket.
        case chevrons
        /// Little hearts and dots.
        case hearts
        /// Gear outlines.
        case gears
        /// Tartan: crossing bands and fine lines.
        case plaid
    }

    /// A window title bar. Following the state (no `color`), it's the window's active color
    /// while working, and a waiting agent's bar flashes like a window asking for attention.
    struct TitleBar: Equatable {
        /// nil takes each state's color.
        var color: String? = nil
        /// The gradient's far end; nil lightens `color` by `fade`.
        var end: String? = nil
        /// 0 is flat.
        var fade: Double = 0
        var direction: Direction = .across
        /// nil picks black or white.
        var text: String? = nil
        /// Points at size m.
        var height: Double = 15
        var buttons: Buttons = .none
        /// Horizontal stripes, like old Mac windows.
        var stripes: Bool = false
        /// 0…1.
        var gloss: Double = 0
        /// The flash's off color, for bars that follow the state; nil is gray.
        var inactive: String? = nil

        var followsState: Bool { color == nil }

        enum Buttons: String, CaseIterable, Codable {
            case none
            /// A gray × box on the right.
            case win
            /// A red rounded × on the right.
            case xp
            /// A close box on the left.
            case mac
            /// Red, yellow and green lights on the left.
            case aqua
        }

        static let heightRange = 10.0...24.0

        func clamped() -> TitleBar {
            var b = self
            b.color = color.flatMap { NSColor(hex: $0) != nil ? $0.uppercased() : nil }
            b.end = end.flatMap { NSColor(hex: $0) != nil ? $0.uppercased() : nil }
            b.text = text.flatMap { NSColor(hex: $0) != nil ? $0.uppercased() : nil }
            b.inactive = inactive.flatMap { NSColor(hex: $0) != nil ? $0.uppercased() : nil }
            b.fade = min(1, max(0, fade))
            b.gloss = min(1, max(0, gloss))
            b.height = min(Self.heightRange.upperBound, max(Self.heightRange.lowerBound, height))
            return b
        }
    }

    static let cornerRange = 0.0...20.0
    /// How far the hard shadow falls, at size m.
    static let shadowOffset: CGFloat = 4

    func clamped() -> Skin {
        var s = self
        func hex(_ h: String, _ fallback: String) -> String { NSColor(hex: h) != nil ? h.uppercased() : fallback }
        func hexes(_ list: [String]) -> [String] { Array(list.filter { NSColor(hex: $0) != nil }.map { $0.uppercased() }.prefix(8)) }
        s.background = hex(background, "#000000")
        s.text = hex(text, "#FFFFFF")
        s.dim = dim.flatMap { NSColor(hex: $0) != nil ? $0.uppercased() : nil }
        s.borderColor = borderColor.flatMap { NSColor(hex: $0) != nil ? $0.uppercased() : nil }
        s.glowColor = glowColor.flatMap { NSColor(hex: $0) != nil ? $0.uppercased() : nil }
        s.corner = min(Self.cornerRange.upperBound, max(Self.cornerRange.lowerBound, corner))
        s.scanlines = min(1, max(0, scanlines))
        s.glow = min(1, max(0, glow))
        s.gloss = min(1, max(0, gloss))
        s.patternStrength = min(1, max(0, patternStrength))
        s.gradient = hexes(gradient)
        s.patternColors = hexes(patternColors)
        s.fonts = Array(fonts.map { String($0.prefix(60)) }.filter { !$0.isEmpty }.prefix(8))
        s.prompt = prompt.map { String($0.prefix(8)) }.flatMap { $0.isEmpty ? nil : $0 }
        s.titleBar = titleBar?.clamped()
        return s
    }

    var backgroundColor: NSColor { NSColor(hex: background) ?? .black }
    var textColor: NSColor { NSColor(hex: text) ?? .white }
    var dimColor: NSColor { dim.flatMap(NSColor.init(hex:)) ?? textColor.withAlphaComponent(0.62) }
    var frameColor: NSColor { borderColor.flatMap(NSColor.init(hex:)) ?? textColor }
    var patternPalette: [NSColor] {
        let list = patternColors.compactMap(NSColor.init(hex:))
        return list.isEmpty ? [textColor] : list
    }

    /// Light or dark, by the background, so system controls on the skin pick readable colors.
    var colorScheme: ColorScheme { backgroundColor.luminance > 0.4 ? .light : .dark }

    func cased(_ s: String) -> String { uppercase ? s.uppercased() : s }

    // MARK: Fonts

    /// Font family → how many members it has installed (0: not installed).
    @MainActor private static var installed: [String: Int] = [:]

    @MainActor private static func members(_ name: String) -> Int {
        if let known = installed[name] { return known }
        let count = NSFontManager.shared.availableMembers(ofFontFamily: name)?.count ?? 0
        installed[name] = count
        return count
    }

    /// The first of `fonts` that's installed, or nil for the system font.
    @MainActor var family: String? { fonts.first { Self.members($0) > 0 } }

    /// Pixel fonts have one weight, and asking for another makes the system fake it, smearing
    /// them; the weight applies only to families that have more than one.
    @MainActor func font(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        if let family {
            return Self.members(family) > 1 ? .custom(family, size: size).weight(weight) : .custom(family, size: size)
        }
        return .system(size: size, weight: weight, design: fallback.design)
    }
}

/// The colors one card is drawn in, whether it's glass or a skin.
struct CardPaint {
    /// nil is glass.
    var background: NSColor?
    /// The skin's background stops, filled toward the state color.
    var fills: [NSColor] = []
    var primary: AnyShapeStyle
    var secondary: AnyShapeStyle
    var detail: AnyShapeStyle
    /// The glow's color, or nil for none.
    var glow: Color?
    /// The cursor effect's block: the status text's color.
    var cursor: NSColor
    /// The skin's frame.
    var frame: NSColor = .clear
    /// The card is a solid block of its state color, so the skin's pattern steps back.
    var solid = false
}

/// A title bar's colors for one state.
struct BarPaint: Equatable {
    var start: NSColor
    var end: NSColor
    var text: NSColor
}

extension StateStyle {
    /// The blink effect's off beat: an empty card fills with its color, a solid one empties.
    func inverted(_ on: Bool) -> StateStyle {
        guard on else { return self }
        var s = self
        s.tint = isSolid ? 0 : 1
        return s
    }
}

extension Look {
    /// A title bar that follows the state flashes itself on the blink's off beat, and the card
    /// holds still under it.
    private func bodyInverted(_ inverted: Bool) -> Bool {
        inverted && !(skin?.titleBar?.followsState ?? false)
    }

    /// How a card in `state` is colored. `inverted` is the off beat of the blink effect: the
    /// card fills with its state color (or, if it's already solid, empties).
    func paint(for state: AgentState, dark: Bool, inverted: Bool = false) -> CardPaint {
        let style = self[state].inverted(bodyInverted(inverted))
        guard let skin else {
            return CardPaint(background: nil, primary: style.primaryText(dark: dark),
                             secondary: style.secondaryText(dark: dark),
                             detail: style.detailText(for: state, dark: dark), glow: nil,
                             cursor: style.isSolid ? NSColor(style.contrast(dark: dark)) : style.resolved(dark: dark))
        }
        let fills = skin.fills(for: style, dark: dark)
        let bg = fills[0]
        let primary = skin.ink(for: style, on: bg)
        let stateColor = style.resolved(dark: dark)
        let detail: NSColor = if style.text != nil || style.isSolid {
            primary
        } else if state != .idle && stateColor.contrast(with: bg) >= 2.6 {
            stateColor
        } else {
            primary
        }
        let secondary = style.isSolid || style.text != nil ? primary.withAlphaComponent(0.7) : skin.dimColor
        // A frame the same color as the card would vanish; it takes the text's color there.
        let wanted = skin.stateFrame ? stateColor : skin.frameColor
        let frame = wanted.contrast(with: bg) < 1.6 ? detail : wanted
        let glow = skin.glowColor.flatMap(NSColor.init(hex:)) ?? primary
        return CardPaint(background: bg, fills: fills,
                         primary: AnyShapeStyle(Color(nsColor: primary)),
                         secondary: AnyShapeStyle(Color(nsColor: secondary)),
                         detail: AnyShapeStyle(Color(nsColor: detail)),
                         glow: skin.glow > 0 ? Color(nsColor: glow).opacity(0.35 + 0.6 * skin.glow) : nil,
                         cursor: detail, frame: frame, solid: style.isSolid)
    }

    /// The status dot's color on this look's card.
    func dotColor(for state: AgentState, dark: Bool, inverted: Bool = false) -> NSColor {
        let style = self[state].inverted(bodyInverted(inverted))
        guard let skin else {
            return style.isSolid ? NSColor(style.contrast(dark: dark)) : style.nsColor
        }
        let bg = skin.fills(for: style, dark: dark)[0]
        if style.text != nil { return skin.ink(for: style, on: bg) }
        let color = style.resolved(dark: dark)
        if style.isSolid || color.contrast(with: bg) < 2.6 {
            return skin.ink(on: bg, solid: style.isSolid)
        }
        return color
    }

    /// The title bar's colors in `state`, or nil without one.
    func barPaint(for state: AgentState, dark: Bool, inverted: Bool = false) -> BarPaint? {
        guard let skin, let bar = skin.titleBar else { return nil }
        var start = bar.color.flatMap(NSColor.init(hex:)) ?? self[state].resolved(dark: dark)
        if bar.followsState && inverted {
            start = bar.inactive.flatMap(NSColor.init(hex:)) ?? NSColor(hex: "#808080")!
        }
        let end = bar.end.flatMap(NSColor.init(hex:)) ?? start.lightened(bar.fade)
        let mid = start.blended(withFraction: 0.5, of: end) ?? start
        let text: NSColor = if let own = bar.text.flatMap(NSColor.init(hex:)), own.contrast(with: mid) >= 2.5 {
            own
        } else {
            NSColor.white.contrast(with: mid) >= NSColor.black.contrast(with: mid) ? .white : .black
        }
        return BarPaint(start: start, end: end, text: text)
    }
}

extension Skin {
    /// The card's background stops in a state: the skin's, filled toward the state color by its tint.
    func fills(for style: StateStyle, dark: Bool) -> [NSColor] {
        let stops = [backgroundColor] + gradient.compactMap(NSColor.init(hex:))
        guard style.tint > 0 else { return stops }
        let color = style.resolved(dark: dark)
        return stops.map { $0.blended(withFraction: style.tint, of: color) ?? $0 }
    }

    /// The card's main background in a state (the first stop).
    func fill(for style: StateStyle, dark: Bool) -> NSColor { fills(for: style, dark: dark)[0] }

    /// A state's text on `bg`: its own color while that reads (a blinking card flips its fill
    /// under it), else the skin's choice.
    func ink(for style: StateStyle, on bg: NSColor) -> NSColor {
        if let own = style.text.flatMap(NSColor.init(hex:)), own.contrast(with: bg) >= 2.5 { return own }
        return ink(on: bg, solid: style.isSolid)
    }

    /// Text on `bg`: the skin's text color, or on a solid card whichever of the skin's two colors
    /// reads better (green on black becomes black on green), or failing both, black or white.
    func ink(on bg: NSColor, solid: Bool) -> NSColor {
        guard solid else { return textColor }
        let best = [textColor, backgroundColor].max { $0.contrast(with: bg) < $1.contrast(with: bg) }!
        if best.contrast(with: bg) >= 3 { return best }
        return bg.luminance > 0.3 ? .black : .white
    }
}

extension NSColor {
    /// Relative luminance (WCAG), 0…1.
    var luminance: Double {
        let c = usingColorSpace(.sRGB) ?? .gray
        func lin(_ v: CGFloat) -> Double {
            let v = Double(v)
            return v <= 0.03928 ? v / 12.92 : pow((v + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * lin(c.redComponent) + 0.7152 * lin(c.greenComponent) + 0.0722 * lin(c.blueComponent)
    }

    /// WCAG contrast ratio, 1…21.
    func contrast(with other: NSColor) -> Double {
        let a = luminance, b = other.luminance
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    /// Brighter and a little paler, keeping the hue: navy fades to a bright blue, not lavender.
    func lightened(_ amount: Double) -> NSColor {
        guard amount > 0, let c = usingColorSpace(.sRGB) else { return self }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        c.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h, saturation: s * (1 - 0.3 * amount), brightness: min(1, b + 0.65 * amount), alpha: a)
    }
}
