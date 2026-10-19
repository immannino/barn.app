@testable import BarnKit
import XCTest

final class MenuBarTests: XCTestCase {
    // 14" MacBook Pro: the notch covers x 663…848 of a 1512-point-wide screen.
    private let laptop = (frame: NSRect(x: 0, y: 0, width: 1512, height: 982),
                          notchRight: NSRect(x: 848, y: 950, width: 664, height: 32) as NSRect?)

    private func hidden(x: CGFloat, y: CGFloat = 945, screens: [(frame: NSRect, notchRight: NSRect?)]) -> Bool {
        AppDelegate.isHidden(statusItem: NSRect(x: x, y: y, width: 65, height: 37), screens: screens)
    }

    func testNotch() {
        XCTAssertFalse(hidden(x: 851, screens: [laptop]), "right of the notch")
        XCTAssertTrue(hidden(x: 677, screens: [laptop]), "under the notch")
        XCTAssertTrue(hidden(x: 400, screens: [laptop]), "pushed past it")
        XCTAssertFalse(hidden(x: 851, y: 990, screens: [laptop]), "auto-hidden menu bar sits above the screen")
    }

    func testOtherScreens() {
        let external = (frame: NSRect(x: 1512, y: 0, width: 2560, height: 1440), notchRight: NSRect?.none)
        XCTAssertFalse(hidden(x: 1600, screens: [laptop, external]), "no notch, nothing to hide behind")
        XCTAssertFalse(hidden(x: 2400, screens: [laptop, external]))
        XCTAssertTrue(hidden(x: -500, screens: [laptop, external]), "off every screen")
    }
}
