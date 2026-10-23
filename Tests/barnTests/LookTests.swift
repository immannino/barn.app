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

    func testHex() {
        XCTAssertEqual(NSColor(hex: "#FF5C61")?.hex, "#FF5C61")
        XCTAssertEqual(NSColor(hex: "fff")?.hex, "#FFFFFF")
        XCTAssertNil(NSColor(hex: "#12345"))
    }
}
