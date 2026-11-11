@testable import BarnKit
import XCTest

final class LookTests: XCTestCase {
    func testRoundTrip() throws {
        for preset in Look.presets {
            XCTAssertEqual(try Look.parse(preset.json), preset, preset.name)
        }
    }

    func testSharedJSONReadsWell() {
        let json = Look.presets[2].json
        XCTAssert(json.contains(#""barn-look" : 1"#))
        XCTAssert(json.contains(#""needs-you" : {"#))
        XCTAssert(json.contains(#""effects" : ["#))
    }

    func testForgivingDecode() throws {
        let look = try Look.parse("""
        here's my look!
        ```json
        { "barn-look": 1, "name": "  spooky  ",
          "states": { "needs-you": { "color": "#a0f", "effects": ["Glow", "lasers", "glow"], "speed": 99, "tint": -1 },
                      "ready": { "color": "not a color" } } }
        ```
        """)
        XCTAssertEqual(look.name, "spooky")
        XCTAssertEqual(look.waiting.color, "#A0F")
        XCTAssertEqual(look.waiting.effects, [.glow]) // unknown and duplicate effects dropped
        XCTAssertEqual(look.waiting.speed, 3)
        XCTAssertEqual(look.waiting.tint, 0)
        XCTAssertEqual(look.ready, Look.barn.ready) // bad color: barn's default
        XCTAssertEqual(look.working, Look.barn.working) // missing state: barn's default
        XCTAssertNil(look.author)
    }

    func testSingleEffectString() throws {
        let look = try Look.parse(#"{"states": {"idle": {"effects": "bounce"}}}"#)
        XCTAssertEqual(look.idle.effects, [.bounce])
        XCTAssertEqual(look.name, "shared look")
    }

    func testRejectsOtherJSON() {
        XCTAssertThrowsError(try Look.parse(#"{"hello": "world"}"#)) { XCTAssertEqual($0 as? LookError, .notALook) }
        XCTAssertThrowsError(try Look.parse("nope")) { XCTAssertEqual($0 as? LookError, .notJSON) }
        XCTAssertThrowsError(try Look.parse("{ broken")) { XCTAssertEqual($0 as? LookError, .notJSON) }
    }

    func testSkinRoundTripsAndReadsWell() throws {
        let dos = try XCTUnwrap(Look.retro.first { $0.name == "dos" })
        XCTAssertEqual(try Look.parse(dos.json), dos)
        XCTAssert(dos.json.contains(#""skin" : {"#))
        XCTAssert(dos.json.contains(#""border" : "double""#))
        XCTAssertNil(Look.barn.skin)
        XCTAssertFalse(Look.barn.json.contains("skin"), "glass looks share without a skin")
    }

    func testUnreleasedLooksAreHidden() throws {
        XCTAssertFalse(Look.showUnreleased)
        let listed = Set(Look.skinGroups.flatMap(\.looks).map(\.name))
        XCTAssertFalse(Look.skinGroups.contains { $0.name == "worlds" })
        XCTAssertEqual(Look.skinGroups.first { $0.name == "design" }?.looks.map(\.name),
                       ["memphis", "modular type", "utilitarian", "brutalism", "neo-brutalism"])
        XCTAssert(listed.isDisjoint(with: Look.unreleased))
        // Still known, so a look already in use keeps working.
        XCTAssertEqual(Look.group(of: "preset:steampunk"), "worlds")
        XCTAssertNotNil(Look.presets.first { $0.name == "gothic" })
        for gone in ["glassmorphism", "neo frutiger aero"] { XCTAssertNil(Look.presets.first { $0.name == gone }) }
        var look = try XCTUnwrap(Look.worlds.first)
        for backdrop in Skin.Backdrop.allCases {
            look.skin?.backdrop = backdrop
            XCTAssertEqual(try Look.parse(look.json).skin?.backdrop, backdrop)
        }
    }

    func testFriendsHaveCharacters() throws {
        XCTAssertEqual(Look.group(of: "preset:pixel hamster"), "friends")
        for look in Look.friends { XCTAssertNotEqual(look.skin?.mascot, Skin.Mascot.none, look.name) }
        var look = Look.friends[0]
        for mascot in Skin.Mascot.allCases {
            look.skin?.mascot = mascot
            XCTAssertEqual(try Look.parse(look.json).skin?.mascot, mascot)
        }
    }

    func testForgivingSkin() throws {
        let look = try Look.parse(#"""
        { "states": { "ready": { "text": "#000" } },
          "skin": { "background": "#0000aa", "border": "Double", "shadow": "lasers", "glow": 9, "fonts": "Px437 IBM VGA 8x16" } }
        """#)
        let skin = try XCTUnwrap(look.skin)
        XCTAssertEqual(skin.background, "#0000AA")
        XCTAssertEqual(skin.text, "#FFFFFF") // missing: white
        XCTAssertEqual(skin.border, .double)
        XCTAssertEqual(skin.shadow, .none) // unknown: none
        XCTAssertEqual(skin.glow, 1)
        XCTAssertEqual(skin.fonts, ["Px437 IBM VGA 8x16"])
        XCTAssertEqual(look.ready.text, "#000")
        // A skin without a usable background is dropped, leaving glass.
        XCTAssertNil(try Look.parse(#"{"states": {}, "skin": {"background": "nope"}}"#).skin)
    }

    func testSolidSkinTextInverts() {
        let skin = Skin(background: "#000000", text: "#33FF33")
        let green = NSColor(hex: "#33FF33")!
        XCTAssertEqual(skin.ink(on: green, solid: true).hex, "#000000") // green on black → black on green
        XCTAssertEqual(skin.ink(on: .black, solid: false).hex, "#33FF33")
        XCTAssertGreaterThan(NSColor.white.contrast(with: .black), 20)
    }

    func testBlinkFlipsFill() {
        XCTAssertEqual(StateStyle(color: "#33FF33", tint: 0).inverted(true).tint, 1)
        XCTAssertEqual(StateStyle(color: "#AA0000", tint: 1).inverted(true).tint, 0)
        XCTAssertEqual(StateStyle(color: "#AA0000", tint: 1).inverted(false).tint, 1)
    }

    func testRetroTextIsReadable() {
        // Every retro state's text stays legible on its own card, blinking or not.
        // Text outlined by a strong halo of another color reads on anything.
        for look in Look.retro where !(look.skin!.glowColor != nil && look.skin!.glow >= 0.8) {
            let skin = look.skin!
            for state in AgentState.allCases {
                for inverted in [false, true] {
                    let style = look[state].inverted(inverted)
                    let bg = skin.fill(for: style, dark: true)
                    let text = skin.ink(for: style, on: bg)
                    XCTAssertGreaterThan(text.contrast(with: bg), 2.5, "\(look.name) \(state) inverted: \(inverted)")
                }
            }
        }
    }

    func testTitleBarsAreReadable() {
        // Title bar text reads on its bar in every state, flashing or not.
        for look in Look.retro where look.skin?.titleBar != nil {
            for state in AgentState.allCases {
                for inverted in [false, true] {
                    let bar = look.barPaint(for: state, dark: true, inverted: inverted)!
                    let mid = bar.start.blended(withFraction: 0.5, of: bar.end)!
                    XCTAssertGreaterThan(bar.text.contrast(with: mid), 2.5, "\(look.name) \(state) inverted: \(inverted)")
                }
            }
        }
    }

    func testForgivingTitleBarAndPattern() throws {
        let look = try Look.parse(#"""
        { "states": {}, "skin": { "background": "#C0C0C0", "gradient": "#FFFFFF", "direction": "Across",
          "pattern": "paisley", "fallback": "SANS", "state-frame": true,
          "title-bar": { "fade": 4, "buttons": "XP", "height": 100, "color": "nope" } } }
        """#)
        let skin = try XCTUnwrap(look.skin)
        XCTAssertEqual(skin.gradient, ["#FFFFFF"])
        XCTAssertEqual(skin.direction, .across)
        XCTAssertEqual(skin.pattern, .none) // unknown: none
        XCTAssertEqual(skin.fallback, .sans)
        XCTAssertTrue(skin.stateFrame)
        let bar = try XCTUnwrap(skin.titleBar)
        XCTAssertEqual(bar.fade, 1)
        XCTAssertEqual(bar.buttons, .xp)
        XCTAssertEqual(bar.height, Skin.TitleBar.heightRange.upperBound)
        XCTAssertTrue(bar.followsState) // a bad color follows the state
    }

    func testFollowingTitleBarFlashesInsteadOfTheCard() {
        let win98 = Look.desktops.first { $0.name == "win 98" }!
        let on = win98.barPaint(for: .waiting, dark: false, inverted: false)!
        let off = win98.barPaint(for: .waiting, dark: false, inverted: true)!
        XCTAssertNotEqual(on.start.hex, off.start.hex)
        XCTAssertEqual(win98.paint(for: .waiting, dark: false, inverted: true).background?.hex,
                       win98.paint(for: .waiting, dark: false).background?.hex)
    }

    func testGroups() {
        XCTAssertEqual(Look.group(of: "preset:barn"), "glass")
        XCTAssertEqual(Look.group(of: "preset:dos"), "terminals")
        XCTAssertEqual(Look.group(of: "preset:xp"), "desktops")
        XCTAssertEqual(Look.group(of: "preset:crayon box"), "whimsy")
        XCTAssertEqual(Look.group(of: "B1E5…"), "yours")
        XCTAssertEqual(Set(Look.presets.map(\.name)).count, Look.presets.count, "preset names are ids, so they must be unique")
    }

    func testHex() {
        XCTAssertEqual(NSColor(hex: "#FF5C61")?.hex, "#FF5C61")
        XCTAssertEqual(NSColor(hex: "fff")?.hex, "#FFFFFF")
        XCTAssertNil(NSColor(hex: "#12345"))
    }
}
