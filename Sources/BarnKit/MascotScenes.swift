import AppKit
import QuartzCore

// More mascots (Mascot.swift has the robots, the hamster and the drawing helpers): a microwave
// and a kettle. Same 64×48 design space, y down.

extension MascotArt {
    // MARK: Microwave

    func microwave() -> [CALayer] {
        var out: [CALayer] = []
        let body = group(pivot: CGPoint(x: 32, y: 44))
        body.addSublayer(shape(roundRect(8, 41, 6, 3, 1), fill: NSColor(hex: "#8C8C8C")!))
        body.addSublayer(shape(roundRect(50, 41, 6, 3, 1), fill: NSColor(hex: "#8C8C8C")!))
        body.addSublayer(shape(roundRect(4, 7, 56, 35, 4), fill: NSColor(hex: "#EDEDED")!, stroke: NSColor(hex: "#8C8C8C")!, width: 1))
        body.addSublayer(shape(roundRect(8, 11, 36, 27, 3), fill: NSColor(hex: "#23282E")!, stroke: NSColor(hex: "#6F6F6F")!, width: 1))
        let light = shape(roundRect(10, 13, 32, 23, 2), fill: NSColor(hex: "#FFD27A")!)
        light.shadowColor = NSColor(hex: "#FFB347")!.cgColor
        light.shadowOffset = .zero
        light.shadowRadius = 4
        light.shadowOpacity = 0.8
        light.opacity = switch state {
        case .idle: 0
        case .waiting: 0.3
        case .working: 0.9
        case .ready: 0.55
        }
        body.addSublayer(light)
        if state == .working { animate(light, "opacity", [0.8, 0.95, 0.85, 0.95, 0.8], period: 0.9) }
        body.addSublayer(shape(ellipse(26, 33, 24, 4.5), fill: NSColor(hex: "#F6F6F6")!.withAlphaComponent(0.8),
                               stroke: NSColor(hex: "#BBBBBB")!, width: 0.6))
        let food = group(pivot: CGPoint(x: 26, y: 30))
        let bowl = CGMutablePath()
        bowl.move(to: CGPoint(x: 20.5, y: 27.5))
        bowl.addQuadCurve(to: CGPoint(x: 31.5, y: 27.5), control: CGPoint(x: 26, y: 35.5))
        bowl.closeSubpath()
        food.addSublayer(shape(bowl, fill: NSColor(hex: "#5BA4E6")!, stroke: NSColor(hex: "#2F6FAF")!, width: 0.6))
        food.addSublayer(shape(ellipse(26, 27.5, 11, 2.4), fill: NSColor(hex: "#E8B04A")!))
        if state == .working {
            // The turntable carries the bowl around.
            animate(food, "transform.translation.x", [-5, 5, -5], period: 3)
        }
        food.opacity = state == .idle ? 0.35 : 1
        body.addSublayer(food)
        body.addSublayer(shape(roundRect(40.5, 14, 1.6, 21, 0.8), fill: NSColor(hex: "#A0A0A0")!))
        // Control panel.
        body.addSublayer(shape(roundRect(47, 11, 10, 6, 1.2), fill: NSColor(hex: "#101418")!))
        for y in [22.0, 27.0, 32.0] {
            for x in [49.5, 54.5] { body.addSublayer(shape(circle(x, y, 1.3), fill: NSColor(hex: "#C4C4C4")!)) }
        }
        body.addSublayer(shape(circle(52, 37.6, 2.2), fill: NSColor(hex: "#BDBDBD")!, stroke: NSColor(hex: "#8C8C8C")!, width: 0.6))
        let digits = NSColor(hex: "#3DFF7A")!
        let display = group(pivot: CGPoint(x: 52, y: 14))
        switch state {
        case .idle:
            display.addSublayer(shape(roundRect(48.3, 13.5, 2.8, 1, 0.3), fill: digits.withAlphaComponent(0.8)))
            display.addSublayer(shape(circle(52, 13.4, 0.35), fill: digits))
            display.addSublayer(shape(circle(52, 15, 0.35), fill: digits))
            display.addSublayer(shape(roundRect(52.9, 13.5, 2.8, 1, 0.3), fill: digits.withAlphaComponent(0.8)))
        case .working:
            for i in 0..<3 {
                let seg = shape(roundRect(48.4 + CGFloat(i) * 2.6, 13.4, 2, 1.4, 0.3), fill: digits)
                animate(seg, "opacity", [1, 0.25, 1], period: 1.2, offset: Double(i) / 3)
                display.addSublayer(seg)
            }
        case .waiting:
            display.addSublayer(shape(roundRect(48, 12.5, 8, 3.2, 0.6), fill: NSColor(hex: "#FF5A4E")!))
            animate(display, "opacity", [1, 0], times: [0, 0.5, 1], period: 0.5, discrete: true)
        case .ready:
            let check = CGMutablePath()
            check.move(to: CGPoint(x: 49.6, y: 14))
            check.addLine(to: CGPoint(x: 51.4, y: 15.6))
            check.addLine(to: CGPoint(x: 54.6, y: 12.4))
            display.addSublayer(shape(check, fill: nil, stroke: digits, width: 1))
        }
        body.addSublayer(display)
        out.append(body)

        switch state {
        case .waiting:
            animate(body, "transform.translation.x", [-0.6, 0.6, -0.6], period: 0.16)
            out.append(beeps(at: CGPoint(x: 58, y: 4)))
        case .ready:
            out.append(contentsOf: steam(at: [CGPoint(x: 23.5, y: 25), CGPoint(x: 28.5, y: 25)], rise: 8, color: .white))
            out.append(emphasis(at: [(5, 4, 2, 1), (9, 2.5, 9, -1)]))
        default:
            break
        }
        return out
    }

    // MARK: Kettle

    func kettle() -> [CALayer] {
        var out: [CALayer] = []
        out.append(shape(roundRect(4, 44, 56, 3.5, 1.2), fill: NSColor(hex: "#1E1B18")!))
        if state == .working || state == .waiting {
            for (i, x) in [21.0, 25.5, 30.0, 34.5, 39.0].enumerated() {
                let flame = group(pivot: CGPoint(x: x, y: 44))
                flame.addSublayer(shape(teardrop(x, 44, 5.5, 2.6), fill: NSColor(hex: "#2A5FA6")!))
                flame.addSublayer(shape(teardrop(x, 44, 3, 1.3), fill: NSColor(hex: "#E2A72E")!))
                animate(flame, "transform.scale.y", [0.7, 1.15, 0.7], period: 0.32 + 0.04 * Double(i % 3), offset: Double(i) / 5)
                out.append(flame)
            }
        }
        let pot = group(pivot: CGPoint(x: 30, y: 42))
        let red = NSColor(hex: "#2F8A84")!, dark = NSColor(hex: "#1F5E58")!, black = NSColor(hex: "#1E1B18")!
        let spout = CGMutablePath()
        spout.move(to: CGPoint(x: 40.5, y: 31))
        spout.addLine(to: CGPoint(x: 52, y: 21.5))
        spout.addLine(to: CGPoint(x: 54.2, y: 23.8))
        spout.addLine(to: CGPoint(x: 42.5, y: 36))
        spout.closeSubpath()
        pot.addSublayer(shape(spout, fill: red))
        pot.addSublayer(shape(circle(53.4, 22.4, 1.7), fill: black))
        let body = CGMutablePath()
        body.move(to: CGPoint(x: 17, y: 42))
        body.addCurve(to: CGPoint(x: 24, y: 20), control1: CGPoint(x: 12.5, y: 34), control2: CGPoint(x: 16, y: 22))
        body.addLine(to: CGPoint(x: 36, y: 20))
        body.addCurve(to: CGPoint(x: 43, y: 42), control1: CGPoint(x: 44, y: 22), control2: CGPoint(x: 47.5, y: 34))
        body.closeSubpath()
        pot.addSublayer(shape(body, fill: red))
        pot.addSublayer(shape(roundRect(15.5, 32, 29, 3.4, 0), fill: NSColor(hex: "#F3EBDC")!))
        let handle = CGMutablePath()
        handle.move(to: CGPoint(x: 21, y: 21))
        handle.addCurve(to: CGPoint(x: 39, y: 21), control1: CGPoint(x: 21, y: 8), control2: CGPoint(x: 39, y: 8))
        pot.addSublayer(shape(handle, fill: nil, stroke: black, width: 2.6))
        let lid = group(pivot: CGPoint(x: 30, y: 20))
        lid.addSublayer(shape(ellipse(30, 20, 14, 3.4), fill: dark))
        lid.addSublayer(shape(circle(30, 16.8, 2.2), fill: black))
        pot.addSublayer(lid)
        out.append(pot)

        switch state {
        case .idle:
            break
        case .working:
            out.append(contentsOf: steam(at: [CGPoint(x: 54.5, y: 19)], rise: 9, color: ink.withAlphaComponent(0.45), period: 3))
        case .waiting:
            // Whistling: steam blasting from the spout, the kettle rattling, the lid hopping.
            animate(pot, "transform.rotation.z", [-0.03, 0.03, -0.03], period: 0.14)
            animate(lid, "transform.translation.y", [0, -1.6, 0], period: 0.26)
            for i in 0..<4 {
                let puff = group(pivot: CGPoint(x: 55, y: 20))
                puff.addSublayer(shape(circle(55, 20, 1.6 + CGFloat(i % 2)), fill: ink.withAlphaComponent(0.25)))
                animate(puff, "transform.translation.x", [0, 6], period: 0.8, offset: Double(i) / 4, linear: true)
                animate(puff, "transform.translation.y", [0, -13], period: 0.8, offset: Double(i) / 4, linear: true)
                animate(puff, "opacity", [1, 0], period: 0.8, offset: Double(i) / 4)
                out.append(puff)
            }
            out.append(beeps(at: CGPoint(x: 58, y: 10)))
        case .ready:
            // Tea's poured: a cup steaming beside the kettle.
            pot.setAffineTransform(CGAffineTransform(translationX: 5, y: 0))
            out.append(shape(ellipse(9, 43, 15, 2.6), fill: NSColor(hex: "#1E1B18")!.withAlphaComponent(0.15)))
            let cup = CGMutablePath()
            cup.move(to: CGPoint(x: 3, y: 33))
            cup.addLine(to: CGPoint(x: 14, y: 33))
            cup.addCurve(to: CGPoint(x: 8.5, y: 42), control1: CGPoint(x: 14, y: 39), control2: CGPoint(x: 12, y: 42))
            cup.addCurve(to: CGPoint(x: 3, y: 33), control1: CGPoint(x: 5, y: 42), control2: CGPoint(x: 3, y: 39))
            out.append(shape(cup, fill: NSColor(hex: "#C8372D")!))
            out.append(shape(ellipse(8.5, 33.6, 10, 1.6), fill: NSColor(hex: "#B5652A")!))
            let ear = CGMutablePath()
            ear.move(to: CGPoint(x: 13.6, y: 35))
            ear.addCurve(to: CGPoint(x: 13.2, y: 39.5), control1: CGPoint(x: 17.5, y: 35), control2: CGPoint(x: 17, y: 39.5))
            out.append(shape(ear, fill: nil, stroke: NSColor(hex: "#C8372D")!, width: 1.4))
            out.append(contentsOf: steam(at: [CGPoint(x: 6.5, y: 30), CGPoint(x: 10.5, y: 30)], rise: 9, color: ink.withAlphaComponent(0.5)))
        }
        return out
    }

    /// A flame, `h` tall and `w` wide, sitting on (x, y).
    private func teardrop(_ x: CGFloat, _ y: CGFloat, _ h: CGFloat, _ w: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x, y: y))
        p.addQuadCurve(to: CGPoint(x: x, y: y - h), control: CGPoint(x: x + w * 1.4, y: y - h * 0.3))
        p.addQuadCurve(to: CGPoint(x: x, y: y), control: CGPoint(x: x - w * 1.4, y: y - h * 0.3))
        return p
    }

    // MARK: Shared pieces

    /// Points along a circle from angle `a` to `b` (radians; y down, so increasing goes clockwise).
    func arcPath(_ c: CGPoint, _ r: CGFloat, from a: CGFloat, to b: CGFloat, closed: Bool) -> CGPath {
        let p = CGMutablePath()
        let steps = 48
        for i in 0...steps {
            let t = a + (b - a) * CGFloat(i) / CGFloat(steps)
            let pt = CGPoint(x: c.x + r * cos(t), y: c.y + r * sin(t))
            if i == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
        if closed { p.closeSubpath() }
        return p
    }

    /// Bubbles rising from each point to the `to` line, one after another.
    func rising(from points: [CGPoint], to top: CGFloat, period: Double) -> [CALayer] {
        points.enumerated().map { i, p in
            let bubble = group(pivot: p)
            bubble.addSublayer(shape(circle(p.x, p.y, 0.9 + 0.3 * CGFloat(i % 2)), fill: NSColor.white.withAlphaComponent(0.3),
                                     stroke: .white, width: 0.6))
            animate(bubble, "transform.translation.y", [0, Double(top - p.y)], period: period, offset: Double(i) / Double(points.count), linear: true)
            animate(bubble, "opacity", [0, 1, 1, 0], times: [0, 0.1, 0.85, 1], period: period, offset: Double(i) / Double(points.count))
            return bubble
        }
    }

    /// Wisps of steam curling up from each point.
    private func steam(at points: [CGPoint], rise: CGFloat, color: NSColor, period: Double = 2.2) -> [CALayer] {
        points.enumerated().map { i, p in
            let wisp = CGMutablePath()
            wisp.move(to: p)
            wisp.addCurve(to: CGPoint(x: p.x, y: p.y - rise), control1: CGPoint(x: p.x + 3, y: p.y - rise * 0.35),
                          control2: CGPoint(x: p.x - 3, y: p.y - rise * 0.65))
            let layer = group(pivot: p)
            layer.addSublayer(shape(wisp, fill: nil, stroke: color, width: 1.2))
            animate(layer, "transform.translation.y", [1, -3], period: period, offset: Double(i) / Double(points.count), linear: true)
            animate(layer, "opacity", [0, 1, 0], period: period, offset: Double(i) / Double(points.count))
            return layer
        }
    }

    /// Sound arcs: ))) flashing.
    private func beeps(at p: CGPoint) -> CALayer {
        let arcs = CGMutablePath()
        for (i, r) in [2.5, 4.5, 6.5].enumerated() {
            arcs.addArc(center: CGPoint(x: p.x - 7, y: p.y + 2), radius: r, startAngle: -0.7, endAngle: 0.7, clockwise: false)
            if i < 2 { arcs.move(to: CGPoint(x: p.x - 7 + [4.5, 6.5][i] * cos(-0.7), y: p.y + 2 + [4.5, 6.5][i] * sin(-0.7))) }
        }
        let layer = shape(arcs, fill: nil, stroke: ink, width: 1.2)
        animate(layer, "opacity", [1, 0], times: [0, 0.5, 1], period: 0.5, discrete: true)
        return layer
    }

    /// Little "look at me" dashes, flashing.
    func emphasis(at strokes: [(CGFloat, CGFloat, CGFloat, CGFloat)]) -> CALayer {
        let p = CGMutablePath()
        for (x1, y1, x2, y2) in strokes {
            p.move(to: CGPoint(x: x1, y: y1))
            p.addLine(to: CGPoint(x: x2, y: y2))
        }
        let layer = shape(p, fill: nil, stroke: ink, width: 1.3)
        animate(layer, "opacity", [1, 0], times: [0, 0.5, 1], period: 0.6, discrete: true)
        return layer
    }
}
