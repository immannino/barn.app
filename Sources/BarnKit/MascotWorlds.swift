import AppKit
import QuartzCore

// A scene rather than a character (Mascot.swift has the helpers): a palette-cycled pixel
// waterfall. Same 64×48 design space, y down.

extension MascotArt {
    // MARK: Color cycling

    /// A pixel waterfall at night. Nothing moves: the waterfall, pool, mist and stars are drawn in
    /// palette slots whose colors rotate, the way old demo and game art animated water.
    func colorCycle() -> [CALayer] {
        var grid = PixelGrid()
        let sky: [Character] = ["a", "b", "c", "d", "e"]
        for y in 0..<PixelGrid.rows { for x in 0..<PixelGrid.cols { grid.set(x, y, sky[min(4, y / 3)]) } }
        for (x, y) in [(3, 1), (9, 3), (15, 0), (28, 6), (6, 6), (19, 4), (30, 2)] { grid.set(x, y, (x + y) % 2 == 0 ? "s" : "t") }
        for y in 0..<6 { for x in 0..<6 where hypot(Double(x) - 2.5, Double(y) - 2.5) < 2.6 { grid.set(24 + x, 1 + y, "m") } }
        for (x, y) in [(25, 2), (26, 4)] { grid.set(x, y, "M") }
        if state == .ready {
            // A rainbow in the spray.
            let bands: [Character] = ["R", "O", "Y", "G", "B"]
            for y in 0..<PixelGrid.rows { for x in 0..<PixelGrid.cols {
                let d = hypot(Double(x) - 15.5, Double(y) - 16)
                let i = Int(13 - d)
                if (0..<5).contains(i), y < 14 { grid.set(x, y, bands[i]) }
            } }
        }
        // Cliffs, lit along the top.
        let left = [9, 8, 8, 9, 10, 10, 11, 11], right = [9, 10, 10, 9, 9, 8, 8]
        for x in 0..<11 {
            let top = left[min(left.count - 1, x * left.count / 11)] - (x < 4 ? 1 : 0)
            for y in top..<19 { grid.set(x, y, y == top ? "K" : "k") }
        }
        for x in 21..<32 {
            let top = right[min(right.count - 1, (x - 21) * right.count / 11)] + 2
            for y in top..<19 { grid.set(x, y, y == top ? "K" : "k") }
        }
        // The falls: slots by row, so the colors run downward.
        for y in 8..<19 { for x in 11..<21 {
            let slot = ((-y + (x % 3 == 0 ? 1 : 0)) % 4 + 4) % 4
            grid.set(x, y, Character(String(slot)))
        } }
        for y in 19..<PixelGrid.rows { for x in 0..<PixelGrid.cols {
            grid.set(x, y, Character(String(4 + (x + 2 * y) % 4)))
        } }
        for x in 9..<23 { grid.set(x, 18, x % 2 == 0 ? "8" : "9"); if x % 3 != 0 { grid.set(x, 19, x % 2 == 0 ? "9" : "8") } }

        let falls = state == .waiting ? ["#FFFFFF", "#FFD23F", "#FF6A3D", "#C81D25"] : ["#FFFFFF", "#9FE7FF", "#3FA9F5", "#1B5FBF"]
        let pool = ["#1B5FBF", "#2E86DE", "#9FE7FF", "#2E86DE"]
        let (fast, slow): (Double, Double) = switch state {
        case .working: (0.48, 0.9)
        case .waiting: (0.36, 0.7)
        case .ready: (0.9, 1.4)
        case .idle: (2.4, 3.6)
        }
        var cycles: [Character: (palette: [String], slot: Int, period: Double)] = [:]
        for i in 0..<4 {
            cycles[Character(String(i))] = (falls, i, fast)
            cycles[Character(String(4 + i))] = (pool, i, slow)
        }
        cycles["8"] = (["#FFFFFF", "#BDEBFF"], 0, fast)
        cycles["9"] = (["#FFFFFF", "#BDEBFF"], 1, fast)
        cycles["s"] = (["#FFFFFF", "#0A0A2E"], 0, state == .waiting ? 0.4 : 1.2)
        cycles["t"] = (["#FFFFFF", "#0A0A2E"], 1, state == .waiting ? 0.4 : 1.6)
        let fixed: [Character: String] = [
            "a": "#0A0A2E", "b": "#16124F", "c": "#2B1670", "d": "#4C1D7A", "e": "#7A2A7A",
            "m": "#FFFBE6", "M": "#D9D2FF", "k": "#0E0718", "K": "#5B3FA0",
            "R": "#FF3355", "O": "#FF9A2E", "Y": "#FFE14D", "G": "#3DDB6E", "B": "#3FA9F5",
        ]

        let frame = CALayer()
        frame.frame = CGRect(origin: .zero, size: Self.canvas)
        let px: CGFloat = 2, bleed: CGFloat = 0.04
        var paths: [Character: CGMutablePath] = [:]
        for y in 0..<PixelGrid.rows {
            var x = 0
            while x < PixelGrid.cols {
                let ch = grid.cells[y][x]
                var end = x + 1
                while end < PixelGrid.cols, grid.cells[y][end] == ch { end += 1 }
                if ch != "." {
                    let path = paths[ch] ?? CGMutablePath()
                    paths[ch] = path
                    path.addRect(CGRect(x: CGFloat(x) * px - bleed, y: CGFloat(y) * px - bleed,
                                        width: CGFloat(end - x) * px + 2 * bleed, height: px + 2 * bleed))
                }
                x = end
            }
        }
        for (ch, path) in paths.sorted(by: { $0.key < $1.key }) {
            if let cycle = cycles[ch] {
                let colors = cycle.palette.indices.map { NSColor(hex: cycle.palette[(cycle.slot + $0) % cycle.palette.count])!.cgColor }
                let layer = shape(path, fill: NSColor(cgColor: colors[0]))
                if !still {
                    let a = CAKeyframeAnimation(keyPath: "fillColor")
                    a.values = colors
                    a.keyTimes = (0...colors.count).map { NSNumber(value: Double($0) / Double(colors.count)) }
                    a.calculationMode = .discrete
                    let duration = cycle.period / max(0.25, speed)
                    a.duration = duration
                    a.repeatCount = .infinity
                    a.isRemovedOnCompletion = false
                    a.timeOffset = Date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: duration)
                    layer.add(a, forKey: "cycle")
                }
                frame.addSublayer(layer)
            } else {
                frame.addSublayer(shape(path, fill: NSColor(hex: fixed[ch] ?? "#FF00FF")!))
            }
        }
        return [frame]
    }
}
