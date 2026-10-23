@testable import BarnKit
import AppKit
import XCTest

@MainActor
final class ChimeTests: XCTestCase {
    func testCuesAreAudibleWithoutClipping() {
        for cue in Chimes.Cue.allCases {
            let samples = Synth.render(Chimes.score(cue))
            let peak = samples.map(abs).max() ?? 0
            XCTAssert(peak > 0.2 && peak < 0.95, "\(cue) peaks at \(peak)")
            XCTAssertLessThan(Double(samples.count) / Synth.rate, 1, "\(cue) is too long")
            XCTAssertLessThan(abs(samples.last ?? 1), 0.01, "\(cue) ends with a click")
        }
    }

    func testWAVsDecode() throws {
        for cue in Chimes.Cue.allCases {
            let data = Synth.wav(Chimes.score(cue))
            XCTAssertNotNil(NSSound(data: data), "\(cue)")
            if let dir = ProcessInfo.processInfo.environment["CHIMES_OUT"] {
                try data.write(to: URL(fileURLWithPath: dir).appendingPathComponent("\(cue).wav"))
            }
        }
    }
}
