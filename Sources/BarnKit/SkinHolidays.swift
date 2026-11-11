import AppKit
import QuartzCore

// Holiday backdrops (SkinBackdrop.swift has the view and helpers), drawn flat: solid shapes in a
// few inks on paper, like a 1950s–60s greeting card or a Swiss poster. No gradients, no glows;
// motion comes from shapes moving, turning and swapping inks. Card size, y down.

enum Ink {
    static let paper = NSColor(hex: "#F3EBDC")!
    static let red = NSColor(hex: "#C8372D")!
    static let green = NSColor(hex: "#1F5E3B")!
    static let teal = NSColor(hex: "#2F8A84")!
    static let paleTeal = NSColor(hex: "#8CC2B8")!
    static let mustard = NSColor(hex: "#E2A72E")!
    static let orange = NSColor(hex: "#DD6B2A")!
    static let rust = NSColor(hex: "#B5532A")!
    static let olive = NSColor(hex: "#7D8A3A")!
    static let brown = NSColor(hex: "#6B3A22")!
    static let ink = NSColor(hex: "#1E1B18")!
    static let navy = NSColor(hex: "#1B2A4A")!
    static let snow = NSColor(hex: "#F7F4EE")!
}

extension BackdropArt {
    // MARK: Autumn

    /// Almond leaves drifting down past rainbow arches in the corner.
    func leaves(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 17)
        out.append(contentsOf: arches(at: CGPoint(x: w * 0.86, y: h + 1), radius: min(h * 0.62, w * 0.3),
                                      [Ink.orange, Ink.mustard, Ink.olive, Ink.paper], size: size))
        let colors = [Ink.orange, Ink.mustard, Ink.red, Ink.olive, Ink.brown]
        let (count, period, gust): (Int, Double, CGFloat) = switch state {
        case .idle: (3, 14, 0.05)
        case .working: (8, 8, 0.15)
        case .waiting: (11, 4, 0.5)
        case .ready: (5, 10, 0.1)
        }
        for i in 0..<count {
            let s = h * (0.14 + 0.06 * CGFloat(rng.next()))
            let leaf = leafLayer(size: s, color: colors[i % colors.count])
            let x0 = CGFloat(rng.next()) * w * (1 + gust) - w * gust
            let sway = w * (0.04 + 0.05 * CGFloat(rng.next()))
            let turns = (rng.next() < 0.5 ? -1.0 : 1.0) * (1 + 2 * rng.next())
            leaf.position = CGPoint(x: x0, y: h * CGFloat(rng.next()))
            leaf.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(rng.next()) * 6.28))
            var path: [NSValue] = []
            for k in 0...16 {
                let t = CGFloat(k) / 16
                let x = x0 + sway * sin(t * 2 * .pi * 1.5) + w * gust * t
                path.append(NSValue(point: NSPoint(x: x, y: -s + (h + 2 * s) * t)))
            }
            let p = period * (0.8 + 0.4 * rng.next())
            animate(leaf, "position", path, period: p, offset: Double(i) / Double(count), linear: true)
            animate(leaf, "transform.rotation.z", [0, turns * 2 * .pi], period: p, offset: Double(i) / Double(count), linear: true)
            animate(leaf, "transform.scale.x", [1, 0.3, 1], period: p / 3, offset: Double(i) / Double(count))
            out.append(leaf)
        }
        return out
    }

    /// Solid half-discs stacked big to small, sitting on `base`.
    private func arches(at base: CGPoint, radius: CGFloat, _ colors: [NSColor], size: CGSize) -> [CALayer] {
        colors.enumerated().map { k, color in
            let r = radius * (1 - 0.22 * CGFloat(k))
            let p = CGMutablePath()
            p.addArc(center: base, radius: r, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
            p.closeSubpath()
            return fillLayer(p, size, color)
        }
    }

    /// A mid-century leaf, `s` long, centered on its own position: an almond with a pale vein.
    private func leafLayer(size s: CGFloat, color: NSColor) -> CALayer {
        let l = CALayer()
        l.bounds = CGRect(x: -s / 2, y: -s / 2, width: s, height: s)
        l.addSublayer(fillLayer(almond(CGPoint(x: 0, y: -s * 0.06), length: s * 0.84, width: s * 0.5, angle: 0), l.bounds.size, color)
            .moved(to: l.bounds))
        let vein = CGMutablePath()
        vein.move(to: CGPoint(x: 0, y: -s * 0.3))
        vein.addLine(to: CGPoint(x: 0, y: s * 0.28))
        l.addSublayer(strokeLayer(vein, l.bounds.size, Ink.paper, max(0.6, s * 0.06)).moved(to: l.bounds))
        let stem = CGMutablePath()
        stem.move(to: CGPoint(x: 0, y: s * 0.34))
        stem.addQuadCurve(to: CGPoint(x: s * 0.08, y: s * 0.5), control: CGPoint(x: 0, y: s * 0.45))
        l.addSublayer(strokeLayer(stem, l.bounds.size, color, max(0.8, s * 0.07)).moved(to: l.bounds))
        return l
    }

    /// A pointed oval `length` long, turned `angle` from upright.
    func almond(_ c: CGPoint, length: CGFloat, width: CGFloat, angle: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: 0, y: -length / 2))
        p.addQuadCurve(to: CGPoint(x: 0, y: length / 2), control: CGPoint(x: width, y: 0))
        p.addQuadCurve(to: CGPoint(x: 0, y: -length / 2), control: CGPoint(x: -width, y: 0))
        var t = CGAffineTransform(translationX: c.x, y: c.y).rotated(by: angle)
        return p.copy(using: &t) ?? p
    }

    // MARK: Thanksgiving

    /// A striped sun setting behind flat hills, wheat, pumpkins, geese.
    func harvest(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 23)
        // The sun: a solid disc with paper stripes cut across its lower half.
        let r = min(h * 0.36, w * 0.2)
        let sun = CALayer()
        sun.frame = CGRect(x: w * 0.7 - r, y: h * 0.62 - r, width: 2 * r, height: 2 * r)
        sun.addSublayer(fillLayer(CGPath(ellipseIn: sun.bounds, transform: nil), sun.bounds.size, Ink.mustard))
        let stripes = CGMutablePath()
        for k in 0..<4 {
            stripes.addRect(CGRect(x: -1, y: r * (1.0 + 0.24 * CGFloat(k)), width: 2 * r + 2, height: r * (0.05 + 0.03 * CGFloat(k))))
        }
        sun.addSublayer(fillLayer(stripes, sun.bounds.size, Ink.paper))
        if state == .waiting { animate(sun, "transform.scale", [1, 1.08, 1], period: 1) }
        out.append(sun)
        // Two flat hills.
        for (i, color) in [Ink.rust, Ink.brown].enumerated() {
            let hill = CGMutablePath()
            let base = h * (0.74 + 0.1 * CGFloat(i))
            hill.move(to: CGPoint(x: 0, y: h))
            hill.addLine(to: CGPoint(x: 0, y: base))
            hill.addCurve(to: CGPoint(x: w, y: base - h * 0.04), control1: CGPoint(x: w * 0.3, y: base - h * 0.1),
                          control2: CGPoint(x: w * 0.6, y: base + h * 0.07))
            hill.addLine(to: CGPoint(x: w, y: h))
            hill.closeSubpath()
            out.append(fillLayer(hill, size, color))
        }
        // Wheat on the right, swaying in a wave that travels across.
        let sway: (angle: Double, period: Double)? = switch state {
        case .idle: nil
        case .working: (0.12, 2.6)
        case .waiting: (0.2, 1.1)
        case .ready: (0.06, 3.6)
        }
        let n = max(4, Int(w / 40))
        for i in 0..<n {
            let x = w * (0.42 + 0.3 * CGFloat(i) / CGFloat(n)) + CGFloat(rng.next()) * 4
            let tall = h * (0.34 + 0.1 * CGFloat(rng.next()))
            let stalk = CALayer()
            stalk.bounds = CGRect(x: -12, y: -tall, width: 24, height: tall)
            stalk.anchorPoint = CGPoint(x: 0.5, y: 1)
            stalk.position = CGPoint(x: x, y: h + 1)
            let stem = CGMutablePath()
            stem.move(to: .zero)
            stem.addLine(to: CGPoint(x: 0, y: -tall * 0.6))
            stalk.addSublayer(strokeLayer(stem, stalk.bounds.size, Ink.mustard, max(1, h * 0.015)).moved(to: stalk.bounds))
            let grains = CGMutablePath()
            let g = tall * 0.17
            for k in 0..<4 {
                let y = -tall * 0.5 - CGFloat(k) * g * 0.7
                grains.addPath(almond(CGPoint(x: -g * 0.32, y: y), length: g, width: g * 0.4, angle: -0.5))
                grains.addPath(almond(CGPoint(x: g * 0.32, y: y), length: g, width: g * 0.4, angle: 0.5))
            }
            grains.addPath(almond(CGPoint(x: 0, y: -tall * 0.5 - 3.3 * g * 0.7), length: g, width: g * 0.4, angle: 0))
            stalk.addSublayer(fillLayer(grains, stalk.bounds.size, Ink.mustard).moved(to: stalk.bounds))
            if let sway {
                animate(stalk, "transform.rotation.z", [-sway.angle * 0.3, sway.angle, -sway.angle * 0.3], period: sway.period,
                        offset: Double(1 - x / w) * 0.6)
            }
            out.append(stalk)
        }
        for (cx, pr) in [(w * 0.86, h * 0.14), (w * 0.95, h * 0.1)] {
            out.append(contentsOf: pumpkin(at: CGPoint(x: cx, y: h - pr * 0.85), r: pr, size: size))
        }
        if state == .working || state == .ready {
            let v = CGMutablePath()
            for k in 0..<5 {
                let bx = CGFloat(k) * 5, by = CGFloat(abs(k - 2)) * 3
                v.move(to: CGPoint(x: bx - 2.4, y: by - 1.2))
                v.addLine(to: CGPoint(x: bx, y: by))
                v.addLine(to: CGPoint(x: bx + 2.4, y: by - 1.2))
            }
            let birds = strokeLayer(v, CGSize(width: 24, height: 10), Ink.ink, 1)
            birds.frame = CGRect(x: 0, y: 0, width: 24, height: 10)
            birds.position = CGPoint(x: -20, y: h * 0.2)
            animate(birds, "position", [NSValue(point: NSPoint(x: w + 20, y: h * 0.12)), NSValue(point: NSPoint(x: -20, y: h * 0.28))],
                    period: state == .working ? 9 : 14, linear: true)
            out.append(birds)
        }
        return out
    }

    /// A flat pumpkin: darker side lobes behind a lighter middle, a green stem and leaf.
    private func pumpkin(at c: CGPoint, r: CGFloat, size: CGSize) -> [CALayer] {
        let sides = CGMutablePath(), middle = CGMutablePath()
        sides.addEllipse(in: CGRect(x: c.x - r * 1.25, y: c.y - r * 0.9, width: r * 1.5, height: r * 1.8))
        sides.addEllipse(in: CGRect(x: c.x - r * 0.25, y: c.y - r * 0.9, width: r * 1.5, height: r * 1.8))
        middle.addEllipse(in: CGRect(x: c.x - r * 0.45, y: c.y - r, width: r * 0.9, height: r * 2))
        let stem = CGMutablePath()
        stem.move(to: CGPoint(x: c.x, y: c.y - r * 0.85))
        stem.addQuadCurve(to: CGPoint(x: c.x + r * 0.25, y: c.y - r * 1.35), control: CGPoint(x: c.x, y: c.y - r * 1.2))
        return [fillLayer(sides, size, Ink.rust), fillLayer(middle, size, Ink.orange),
                strokeLayer(stem, size, Ink.green, max(1.5, r * 0.18)),
                fillLayer(almond(CGPoint(x: c.x - r * 0.35, y: c.y - r * 1.05), length: r * 0.6, width: r * 0.22, angle: -1.2),
                          size, Ink.olive)]
    }

    // MARK: Snow

    /// Night, snow falling on Swiss-poster pines and a white field.
    func snow(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 31)
        // A flat moon.
        let mr = h * 0.12
        out.append(fillLayer(CGPath(ellipseIn: CGRect(x: w * 0.62 - mr, y: h * 0.2 - mr, width: 2 * mr, height: 2 * mr), transform: nil),
                             size, Ink.paper))
        for (i, color) in [Ink.paleTeal, Ink.snow].enumerated() {
            let field = CGMutablePath()
            let base = h * (0.8 + 0.08 * CGFloat(i))
            field.move(to: CGPoint(x: 0, y: h))
            field.addLine(to: CGPoint(x: 0, y: base))
            field.addCurve(to: CGPoint(x: w, y: base + h * 0.02), control1: CGPoint(x: w * 0.35, y: base - h * 0.08),
                           control2: CGPoint(x: w * 0.65, y: base + h * 0.06))
            field.addLine(to: CGPoint(x: w, y: h))
            field.closeSubpath()
            out.append(fillLayer(field, size, color))
            if i == 0 {
                for (x, tall, color) in [(w * 0.74, h * 0.42, Ink.teal), (w * 0.84, h * 0.58, Ink.paleTeal), (w * 0.93, h * 0.4, Ink.teal)] {
                    out.append(contentsOf: pine(at: CGPoint(x: x, y: h * 0.86), height: tall, color: color, size: size))
                }
            }
        }
        let (rate, wind): (Float, CGFloat) = switch state {
        case .idle: (0.3, 0)
        case .working: (1, 4)
        case .waiting: (2.4, 26)
        case .ready: (0.7, 2)
        }
        out.append(contentsOf: snowfall(size, rate: rate, wind: wind, rng: &rng))
        return out
    }

    /// Flat dots falling at two depths; still, a scatter of them.
    func snowfall(_ size: CGSize, rate: Float, wind: CGFloat, rng: inout Scribble) -> [CALayer] {
        let w = size.width, h = size.height
        guard !still else {
            let dots = CGMutablePath()
            for _ in 0..<Int(w * h / 300) {
                let r = 0.6 + CGFloat(rng.next()) * 1.1
                dots.addEllipse(in: CGRect(x: CGFloat(rng.next()) * w, y: CGFloat(rng.next()) * h, width: 2 * r, height: 2 * r))
            }
            return [fillLayer(dots, size, Ink.snow)]
        }
        let emitter = CAEmitterLayer()
        emitter.frame = CGRect(origin: .zero, size: size)
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: w / 2 - wind, y: -4)
        emitter.emitterSize = CGSize(width: w * 1.4, height: 1)
        emitter.emitterCells = [(scale: 0.05, speed: 9.0, birth: 0.05), (scale: 0.09, speed: 15.0, birth: 0.025)].map { d in
            let cell = CAEmitterCell()
            cell.contents = Self.flake
            cell.birthRate = rate * Float(w * d.birth) * Float(max(0.5, speed))
            cell.velocity = CGFloat(d.speed) * CGFloat(max(0.5, speed))
            cell.velocityRange = 4
            cell.emissionLongitude = .pi / 2
            cell.emissionRange = 0.3
            cell.xAcceleration = wind
            cell.lifetime = Float(h / CGFloat(d.speed * 0.8)) + 1
            cell.scale = d.scale
            cell.scaleRange = d.scale * 0.3
            cell.color = Ink.snow.cgColor
            return cell
        }
        emitter.beginTime = CACurrentMediaTime() - Double(h / 6)
        return [emitter]
    }

    /// A hard-edged round flake.
    private static let flake: CGImage? = {
        guard let ctx = CGContext(data: nil, width: 32, height: 32, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fillEllipse(in: CGRect(x: 1, y: 1, width: 30, height: 30))
        return ctx.makeImage()
    }()

    /// Three stacked triangles on a short trunk.
    private func pine(at base: CGPoint, height: CGFloat, color: NSColor, size: CGSize) -> [CALayer] {
        let green = CGMutablePath()
        for k in 0..<3 {
            let top = base.y - height + CGFloat(k) * height * 0.25
            let bottom = top + height * 0.4
            let half = height * (0.16 + 0.07 * CGFloat(k))
            green.addLines(between: [CGPoint(x: base.x, y: top), CGPoint(x: base.x + half, y: bottom), CGPoint(x: base.x - half, y: bottom)])
            green.closeSubpath()
        }
        let trunk = CGPath(rect: CGRect(x: base.x - height * 0.03, y: base.y - height * 0.06, width: height * 0.06, height: height * 0.1),
                           transform: nil)
        return [fillLayer(trunk, size, Ink.brown), fillLayer(green, size, color)]
    }

    // MARK: Candy cane

    /// A striped peppermint frame that crawls like a barber pole, and a spinning mint.
    func candyCane(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        let band = max(4, min(w, h) * 0.065)
        let period = band * 2.6
        let stripes = CGMutablePath()
        var x = -h - period
        while x < w + h + period {
            stripes.addLines(between: [CGPoint(x: x, y: h), CGPoint(x: x + h, y: 0), CGPoint(x: x + h + period * 0.45, y: 0),
                                       CGPoint(x: x + period * 0.45, y: h)])
            stripes.closeSubpath()
            x += period
        }
        let ring = CALayer()
        ring.frame = CGRect(origin: .zero, size: size)
        ring.addSublayer(fillLayer(CGPath(rect: ring.bounds, transform: nil), size, Ink.snow))
        let red = fillLayer(stripes, size, Ink.red)
        let crawl: Double? = switch state {
        case .working: 2.5
        case .waiting: 0.8
        case .ready: 6
        case .idle: nil
        }
        if let crawl { animate(red, "transform.translation.x", [0, Double(period)], period: crawl, linear: true) }
        ring.addSublayer(red)
        let cut = CAShapeLayer()
        let hole = CGMutablePath()
        hole.addRect(ring.bounds)
        hole.addRect(ring.bounds.insetBy(dx: band, dy: band))
        cut.path = hole
        cut.fillRule = .evenOdd
        ring.mask = cut
        out.append(ring)
        // The mint: red wedges on a white disc with a red rim.
        let r = min(h * 0.2, w * 0.12)
        let mint = CALayer()
        mint.frame = CGRect(x: w - band - r * 2.4, y: band + r * 0.4, width: 2 * r, height: 2 * r)
        let disc = fillLayer(CGPath(ellipseIn: mint.bounds.insetBy(dx: 0.5, dy: 0.5), transform: nil), mint.bounds.size, Ink.snow)
        disc.strokeColor = Ink.red.cgColor
        disc.lineWidth = 1
        let swirl = CAShapeLayer()
        swirl.frame = mint.bounds
        let s = CGMutablePath()
        let c = CGPoint(x: r, y: r)
        for k in stride(from: 0, to: 8, by: 2) {
            let a0 = CGFloat(k) * .pi / 4
            s.move(to: c)
            s.addArc(center: c, radius: r * 0.8, startAngle: a0, endAngle: a0 + .pi / 4, clockwise: false)
            s.closeSubpath()
        }
        swirl.path = s
        swirl.fillColor = Ink.red.cgColor
        if let crawl { animate(swirl, "transform.rotation.z", [0, 2 * Double.pi], period: crawl * 3, linear: true) }
        mint.addSublayer(disc)
        mint.addSublayer(swirl)
        out.append(mint)
        return out
    }

    // MARK: Christmas lights

    /// A strand of flat bulbs along the top, gold dots, and a Swiss-poster tree of stacked bars.
    func lights(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 47)
        let dots = CGMutablePath()
        for _ in 0..<max(6, Int(w / 18)) {
            let d = 1.4 + CGFloat(rng.next()) * 1.6
            dots.addEllipse(in: CGRect(x: CGFloat(rng.next()) * w * 0.65, y: h * (0.45 + 0.65 * CGFloat(rng.next())), width: d, height: d))
        }
        out.append(fillLayer(dots, size, Ink.mustard))
        out.append(contentsOf: barTree(base: CGPoint(x: w * 0.84, y: h * 0.94), height: h * 0.66, size: size))

        let palette = [Ink.red, Ink.mustard, Ink.teal, Ink.green]
        let swags = max(2, Int(w / 120))
        let wire = CGMutablePath()
        var bulbs: [(CGPoint, CGFloat)] = []
        let sag = h * 0.14, top = h * 0.03
        for k in 0..<swags {
            let x0 = w * (0.42 + 0.58 * CGFloat(k) / CGFloat(swags)), x1 = w * (0.42 + 0.58 * CGFloat(k + 1) / CGFloat(swags))
            wire.move(to: CGPoint(x: x0 - 2, y: top))
            wire.addQuadCurve(to: CGPoint(x: x1 + 2, y: top), control: CGPoint(x: (x0 + x1) / 2, y: top + sag * 2))
            for j in 1...4 {
                let t = CGFloat(j) / 5
                let slope = (sag * 2 * 2 * (1 - 2 * t)) / (x1 - x0)
                bulbs.append((CGPoint(x: x0 + (x1 - x0) * t, y: top + sag * 2 * 2 * t * (1 - t)), atan(slope)))
            }
        }
        out.append(strokeLayer(wire, size, Ink.ink, 1))
        let bulbR = max(2.4, h * 0.05)
        for (i, (p, tilt)) in bulbs.enumerated() {
            let bulb = CALayer()
            bulb.bounds = CGRect(x: -bulbR * 1.2, y: -bulbR * 0.5, width: bulbR * 2.4, height: bulbR * 3.4)
            bulb.anchorPoint = CGPoint(x: 0.5, y: 0)
            bulb.position = p
            bulb.setAffineTransform(CGAffineTransform(rotationAngle: tilt * 0.5))
            let g = CGMutablePath()
            g.move(to: CGPoint(x: -bulbR * 0.45, y: bulbR * 0.4))
            g.addCurve(to: CGPoint(x: 0, y: bulbR * 2.8), control1: CGPoint(x: -bulbR * 1.1, y: bulbR * 1.4),
                       control2: CGPoint(x: -bulbR * 0.5, y: bulbR * 2.6))
            g.addCurve(to: CGPoint(x: bulbR * 0.45, y: bulbR * 0.4), control1: CGPoint(x: bulbR * 0.5, y: bulbR * 2.6),
                       control2: CGPoint(x: bulbR * 1.1, y: bulbR * 1.4))
            g.closeSubpath()
            let glass = fillLayer(g, bulb.bounds.size, palette[i % palette.count]).moved(to: bulb.bounds)
            let cap = fillLayer(CGPath(rect: CGRect(x: -bulbR * 0.45, y: -bulbR * 0.3, width: bulbR * 0.9, height: bulbR * 0.8), transform: nil),
                                bulb.bounds.size, Ink.ink).moved(to: bulb.bounds)
            bulb.addSublayer(glass)
            bulb.addSublayer(cap)
            switch state {
            case .idle:
                // Unlit: paper glass, ink outline.
                glass.fillColor = Ink.paper.cgColor
                glass.strokeColor = Ink.ink.cgColor
                glass.lineWidth = 0.8
            case .working:
                // Chasing: the colors march along the strand.
                let colors = palette.indices.map { palette[(i + palette.count - $0) % palette.count].cgColor }
                step(glass, "fillColor", colors, period: 2.4)
            case .waiting:
                step(glass, "fillColor", [Ink.red.cgColor, Ink.paper.cgColor], period: 0.7, offset: i % 2 == 0 ? 0 : 0.5)
            case .ready:
                // Steady, with one bulb at a time winking.
                let color = palette[i % palette.count].cgColor
                step(glass, "fillColor", [color, Ink.paper.cgColor, color], times: [0, 0.9, 0.95, 1], period: 5,
                     offset: Double(i) / Double(bulbs.count))
            }
            out.append(bulb)
        }
        return out
    }

    /// Stacked rounded bars in green, red baubles at the ends, a gold star on top.
    private func barTree(base: CGPoint, height: CGFloat, size: CGSize) -> [CALayer] {
        let rows = 5
        let barH = height / (CGFloat(rows) + 1.2)
        let bars = CGMutablePath(), baubles = CGMutablePath()
        var top = base.y
        for k in 0..<rows {
            let width = barH * (5.4 - CGFloat(k) * 1.05)
            top = base.y - CGFloat(k + 1) * barH
            bars.addRoundedRect(in: CGRect(x: base.x - width / 2, y: top, width: width, height: barH * 0.98),
                                cornerWidth: barH * 0.49, cornerHeight: barH * 0.49)
            if k < rows - 1 {
                let side: CGFloat = k % 2 == 0 ? 1 : -1
                let br = barH * 0.42
                let bx = base.x + side * (width / 2 - br * 0.6)
                baubles.addEllipse(in: CGRect(x: bx - br, y: top + barH * 0.5 - br, width: 2 * br, height: 2 * br))
            }
        }
        let tree = fillLayer(bars, size, Ink.green)
        let red = fillLayer(baubles, size, Ink.red)
        let star = CAShapeLayer()
        let sr = barH * 0.75
        star.bounds = CGRect(x: -sr, y: -sr, width: 2 * sr, height: 2 * sr)
        star.position = CGPoint(x: base.x, y: top - sr * 0.9)
        star.path = concaveStar(.zero, sr)
        star.fillColor = Ink.mustard.cgColor
        switch state {
        case .waiting: animate(star, "transform.rotation.z", [0, Double.pi / 2], period: 0.8, linear: true)
        case .ready: animate(star, "transform.scale", [1, 1.25, 1], period: 1.6)
        default: break
        }
        return [tree, red, star]
    }

    /// A four-pointed star with curved sides, the 60s card kind.
    func concaveStar(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let pts = [CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x + r, y: c.y), CGPoint(x: c.x, y: c.y + r), CGPoint(x: c.x - r, y: c.y)]
        p.move(to: pts[0])
        for k in 1...4 {
            let a = pts[k - 1], b = pts[k % 4]
            p.addQuadCurve(to: b, control: CGPoint(x: c.x + (a.x + b.x - 2 * c.x) * 0.12, y: c.y + (a.y + b.y - 2 * c.y) * 0.12))
        }
        p.closeSubpath()
        return p
    }

    /// Like `animate`, but jumping between values (an ink swap) instead of blending.
    func step(_ layer: CALayer, _ keyPath: String, _ values: [Any], times: [Double]? = nil, period: Double, offset: Double = 0) {
        guard !still else { return }
        let a = CAKeyframeAnimation(keyPath: keyPath)
        a.values = values
        a.calculationMode = .discrete
        a.keyTimes = (times ?? (0...values.count).map { Double($0) / Double(values.count) }).map { NSNumber(value: $0) }
        let duration = period / max(0.25, speed)
        a.duration = duration
        a.repeatCount = .infinity
        a.isRemovedOnCompletion = false
        a.timeOffset = (Date.timeIntervalSinceReferenceDate + offset * duration).truncatingRemainder(dividingBy: duration)
        layer.add(a, forKey: keyPath + "\(ObjectIdentifier(a).hashValue)")
    }

    // MARK: Santa

    /// The suit, printed in two inks: a scalloped fur band, a black belt, a gold buckle.
    func santa(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 41)
        let dots = CGMutablePath()
        for _ in 0..<max(8, Int(w / 14)) {
            let d = 1.4 + CGFloat(rng.next()) * 1.4
            dots.addEllipse(in: CGRect(x: CGFloat(rng.next()) * w, y: h * (0.3 + 0.55 * CGFloat(rng.next())), width: d, height: d))
        }
        out.append(fillLayer(dots, size, Ink.mustard))
        let beltY = h * 0.5, beltH = h * 0.16
        out.append(fillLayer(CGPath(rect: CGRect(x: 0, y: beltY, width: w, height: beltH), transform: nil), size, Ink.ink))
        let bw = beltH * 1.9
        let buckle = CALayer()
        buckle.frame = CGRect(x: w * 0.72 - bw / 2, y: beltY - beltH * 0.25, width: bw, height: beltH * 1.5)
        let frame = CGMutablePath()
        frame.addRect(buckle.bounds)
        frame.addRect(buckle.bounds.insetBy(dx: bw * 0.2, dy: beltH * 0.32))
        let metal = fillLayer(frame, buckle.bounds.size, Ink.mustard)
        metal.fillRule = .evenOdd
        buckle.addSublayer(metal)
        buckle.addSublayer(fillLayer(CGPath(rect: CGRect(x: bw * 0.45, y: beltH * 0.6, width: bw * 0.4, height: beltH * 0.3), transform: nil),
                                     buckle.bounds.size, Ink.mustard))
        if state != .idle {
            // A flat paper glint sliding across the metal.
            let glint = CALayer()
            glint.frame = buckle.bounds
            let mask = CAShapeLayer()
            mask.path = frame
            mask.fillRule = .evenOdd
            glint.mask = mask
            let bar = CGMutablePath()
            bar.addLines(between: [CGPoint(x: 0, y: buckle.bounds.height), CGPoint(x: bw * 0.25, y: 0), CGPoint(x: bw * 0.4, y: 0),
                                   CGPoint(x: bw * 0.15, y: buckle.bounds.height)])
            bar.closeSubpath()
            let shine = fillLayer(bar, buckle.bounds.size, Ink.paper)
            animate(shine, "transform.translation.x", [-Double(bw) * 0.5, -Double(bw) * 0.5, Double(bw)], times: [0, 0.7, 1],
                    period: state == .waiting ? 1.2 : 4)
            glint.addSublayer(shine)
            buckle.addSublayer(glint)
        }
        if state == .waiting { animate(buckle, "transform.translation.y", [0, -1.5, 0, -1, 0], period: 0.5) }
        out.append(buckle)
        // Fur: a paper band with a scalloped edge.
        let fur = CGMutablePath()
        let tuft = max(4, h * 0.08)
        fur.addRect(CGRect(x: 0, y: h * 0.88, width: w, height: h * 0.12))
        var x: CGFloat = 0
        while x < w + tuft {
            fur.addEllipse(in: CGRect(x: x - tuft, y: h * 0.88 - tuft, width: 2 * tuft, height: 2 * tuft))
            x += tuft * 1.7
        }
        out.append(fillLayer(fur, size, Ink.snow))
        return out
    }

    // MARK: Sleigh

    /// The team crossing a flat moon over rooftops, Rudolph's nose blinking.
    func sleigh(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 53)
        for i in 0..<max(5, Int(w / 28)) {
            let r = h * (0.025 + 0.025 * CGFloat(rng.next()))
            let star = CAShapeLayer()
            star.bounds = CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)
            star.position = CGPoint(x: CGFloat(rng.next()) * w, y: CGFloat(rng.next()) * h * 0.55)
            star.path = concaveStar(.zero, r)
            star.fillColor = Ink.mustard.cgColor
            animate(star, "transform.scale", [0.6, 1.1, 0.6], period: 2 + Double(i % 4) * 0.5, offset: Double(i) / 7)
            out.append(star)
        }
        let mr = h * 0.3
        out.append(fillLayer(CGPath(ellipseIn: CGRect(x: w * 0.68 - mr, y: h * 0.38 - mr, width: 2 * mr, height: 2 * mr), transform: nil),
                             size, Ink.paper))

        let team = CALayer()
        let unit = h * 0.07
        team.bounds = CGRect(x: 0, y: 0, width: unit * 34, height: unit * 9)
        let deer = CGMutablePath(), lines = CGMutablePath()
        for k in 0..<4 {
            let x = unit * (13 + CGFloat(k) * 5.2), y = unit * 4.5 - CGFloat(k) * unit * 0.4
            deer.addEllipse(in: CGRect(x: x - unit * 1.6, y: y - unit * 0.7, width: unit * 3.2, height: unit * 1.4))
            deer.addEllipse(in: CGRect(x: x + unit * 1.6, y: y - unit * 1.9, width: unit * 1.1, height: unit * 0.8))
            lines.move(to: CGPoint(x: x + unit * 1.1, y: y - unit * 0.3)); lines.addLine(to: CGPoint(x: x + unit * 1.9, y: y - unit * 1.5))
            lines.move(to: CGPoint(x: x + unit * 1.9, y: y - unit * 1.8)); lines.addLine(to: CGPoint(x: x + unit * 1.5, y: y - unit * 3))
            lines.move(to: CGPoint(x: x + unit * 1.7, y: y - unit * 2.4)); lines.addLine(to: CGPoint(x: x + unit * 1.1, y: y - unit * 2.8))
            lines.move(to: CGPoint(x: x + unit * 2.1, y: y - unit * 1.8)); lines.addLine(to: CGPoint(x: x + unit * 2.4, y: y - unit * 2.9))
            lines.move(to: CGPoint(x: x + unit, y: y + unit * 0.4)); lines.addLine(to: CGPoint(x: x + unit * 2, y: y + unit * 1.3))
            lines.move(to: CGPoint(x: x - unit, y: y + unit * 0.4)); lines.addLine(to: CGPoint(x: x - unit * 2.1, y: y + unit * 1.1))
            lines.move(to: CGPoint(x: x - unit * 1.4, y: y)); lines.addLine(to: CGPoint(x: x - unit * 3.6, y: y + unit * 0.2))
        }
        deer.move(to: CGPoint(x: unit * 1, y: unit * 5.5))
        deer.addLine(to: CGPoint(x: unit * 8.5, y: unit * 5.5))
        deer.addQuadCurve(to: CGPoint(x: unit * 9, y: unit * 3.4), control: CGPoint(x: unit * 9.6, y: unit * 5))
        deer.addLine(to: CGPoint(x: unit * 2.5, y: unit * 3.6))
        deer.closeSubpath()
        deer.addEllipse(in: CGRect(x: unit * 2.2, y: unit * 1.4, width: unit * 2.6, height: unit * 2.6))
        deer.addEllipse(in: CGRect(x: unit * 5.2, y: unit * 1.6, width: unit * 1.8, height: unit * 2.2))
        lines.move(to: CGPoint(x: 0, y: unit * 6.3))
        lines.addLine(to: CGPoint(x: unit * 9.5, y: unit * 6.3))
        lines.addQuadCurve(to: CGPoint(x: unit * 10.5, y: unit * 5), control: CGPoint(x: unit * 10.8, y: unit * 6.3))
        team.addSublayer(fillLayer(deer, team.bounds.size, Ink.ink))
        team.addSublayer(strokeLayer(lines, team.bounds.size, Ink.ink, max(0.8, unit * 0.35)))
        let nosePoint = CGPoint(x: unit * (13 + 3 * 5.2) + unit * 2.7, y: unit * 4.5 - 3 * unit * 0.4 - unit * 1.5)
        let nose = fillLayer(CGPath(ellipseIn: CGRect(x: nosePoint.x - unit * 0.4, y: nosePoint.y - unit * 0.4,
                                                      width: unit * 0.8, height: unit * 0.8), transform: nil),
                             team.bounds.size, Ink.red)
        step(nose, "fillColor", [Ink.red.cgColor, Ink.ink.cgColor], period: state == .waiting ? 0.5 : 1.4)
        team.addSublayer(nose)
        team.position = CGPoint(x: w * 0.68, y: h * 0.38)
        if state == .idle {
            team.setAffineTransform(CGAffineTransform(scaleX: 0.8, y: 0.8))
        } else {
            let span = Double(team.bounds.width) / 2
            let path: [NSValue] = (0...16).map { k in
                let t = Double(k) / 16
                return NSValue(point: NSPoint(x: -span + (Double(w) + 2 * span) * t, y: Double(h) * (0.5 - 0.3 * sin(t * .pi))))
            }
            animate(team, "position", path, period: state == .working ? 8 : state == .waiting ? 5 : 12, linear: true)
        }
        out.append(team)
        let roofs = CGMutablePath(), snowLine = CGMutablePath(), windows = CGMutablePath()
        var x: CGFloat = -4
        while x < w {
            let bw = h * (0.22 + 0.14 * CGFloat(rng.next())), roofH = h * (0.08 + 0.06 * CGFloat(rng.next()))
            let wallTop = h * (0.76 + 0.08 * CGFloat(rng.next()))
            roofs.addLines(between: [CGPoint(x: x, y: h), CGPoint(x: x, y: wallTop), CGPoint(x: x + bw / 2, y: wallTop - roofH),
                                     CGPoint(x: x + bw, y: wallTop), CGPoint(x: x + bw, y: h)])
            roofs.closeSubpath()
            snowLine.move(to: CGPoint(x: x - 1, y: wallTop + 0.5))
            snowLine.addLine(to: CGPoint(x: x + bw / 2, y: wallTop - roofH))
            snowLine.addLine(to: CGPoint(x: x + bw + 1, y: wallTop + 0.5))
            if rng.next() < 0.75 {
                let s = h * 0.05
                windows.addRect(CGRect(x: x + bw / 2 - s / 2, y: wallTop + h * 0.05, width: s, height: s * 1.2))
            }
            x += bw - 1
        }
        out.append(fillLayer(roofs, size, Ink.ink))
        out.append(strokeLayer(snowLine, size, Ink.snow, max(1.2, h * 0.025)))
        out.append(fillLayer(windows, size, Ink.mustard))
        return out
    }

    // MARK: Menorah

    /// A gold menorah on an art-deco sunburst; the shamash alone when idle, all nine otherwise.
    func menorah(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        let cx = w * 0.7, span = min(w * 0.46, h * 1.2)
        let armY = h * 0.52, baseY = h * 0.9
        // Sunburst: alternating wedges, turning slowly.
        let burst = CALayer()
        let reach = hypot(w, h)
        burst.bounds = CGRect(x: -reach, y: -reach, width: 2 * reach, height: 2 * reach)
        burst.position = CGPoint(x: cx, y: armY)
        let rays = CGMutablePath()
        for k in stride(from: 0, to: 32, by: 2) {
            let a = CGFloat(k) * .pi / 16
            rays.move(to: .zero)
            rays.addArc(center: .zero, radius: reach, startAngle: a, endAngle: a + .pi / 16, clockwise: false)
            rays.closeSubpath()
        }
        burst.addSublayer(fillLayer(rays, burst.bounds.size, NSColor(hex: "#2A5FA6")!).moved(to: burst.bounds))
        switch state {
        case .working: animate(burst, "transform.rotation.z", [0, Double.pi / 8], period: 12, linear: true)
        case .waiting: animate(burst, "transform.rotation.z", [0, Double.pi / 8], period: 2, linear: true)
        default: break
        }
        out.append(burst)

        let metal = CGMutablePath()
        metal.addRect(CGRect(x: cx - span * 0.16, y: baseY, width: span * 0.32, height: h * 0.05))
        metal.addRect(CGRect(x: cx - span * 0.025, y: armY, width: span * 0.05, height: baseY - armY))
        let arms = CGMutablePath()
        for k in 1...4 {
            let dx = span / 2 * CGFloat(k) / 4
            arms.move(to: CGPoint(x: cx - dx, y: armY - h * 0.02))
            arms.addQuadCurve(to: CGPoint(x: cx + dx, y: armY - h * 0.02), control: CGPoint(x: cx, y: armY + dx * 1.15))
        }
        var cups: [CGPoint] = []
        for k in -4...4 {
            let x = cx + span / 2 * CGFloat(k) / 4
            let y = k == 0 ? armY - h * 0.12 : armY - h * 0.02
            cups.append(CGPoint(x: x, y: y))
            metal.addRect(CGRect(x: x - span * 0.03, y: y - h * 0.035, width: span * 0.06, height: h * 0.04))
        }
        metal.addRect(CGRect(x: cx - span * 0.012, y: armY - h * 0.12, width: span * 0.024, height: h * 0.12))
        out.append(strokeLayer(arms, size, Ink.mustard, max(1.2, span * 0.025)))
        out.append(fillLayer(metal, size, Ink.mustard))

        let candleH = h * 0.14, candleW = max(2, span * 0.03)
        for (i, cup) in cups.enumerated() {
            let isShamash = i == 4
            let candle = CGRect(x: cup.x - candleW / 2, y: cup.y - h * 0.035 - candleH, width: candleW, height: candleH)
            out.append(fillLayer(CGPath(rect: candle, transform: nil), size, isShamash ? Ink.snow : NSColor(hex: "#BFD3F2")!))
            guard isShamash || state != .idle else { continue }
            let fh = h * 0.1, fw = fh * 0.45
            let flame = CAShapeLayer()
            flame.bounds = CGRect(x: -fw, y: -fh, width: 2 * fw, height: fh)
            flame.anchorPoint = CGPoint(x: 0.5, y: 1)
            flame.position = CGPoint(x: cup.x, y: candle.minY - 1)
            let f = CGMutablePath()
            f.move(to: .zero)
            f.addQuadCurve(to: CGPoint(x: 0, y: -fh), control: CGPoint(x: fw * 1.3, y: -fh * 0.35))
            f.addQuadCurve(to: .zero, control: CGPoint(x: -fw * 1.3, y: -fh * 0.35))
            flame.path = f
            flame.fillColor = Ink.mustard.cgColor
            let core = CAShapeLayer()
            let c = CGMutablePath()
            c.move(to: CGPoint(x: 0, y: -fh * 0.05))
            c.addQuadCurve(to: CGPoint(x: 0, y: -fh * 0.5), control: CGPoint(x: fw * 0.6, y: -fh * 0.2))
            c.addQuadCurve(to: CGPoint(x: 0, y: -fh * 0.05), control: CGPoint(x: -fw * 0.6, y: -fh * 0.2))
            core.path = c
            core.fillColor = Ink.snow.cgColor
            flame.addSublayer(core.moved(to: flame.bounds))
            let jitter = Double(i) / 9, big = state == .waiting ? 1.35 : 1.18
            animate(flame, "transform.scale.y", [1, big, 0.92, 1.1, 1], period: 0.9 + 0.13 * Double(i % 3), offset: jitter)
            animate(flame, "transform.rotation.z", [-0.06, 0.07, -0.03, 0.05, -0.06], period: 1.3 + 0.1 * Double(i % 4), offset: jitter)
            out.append(flame)
        }
        return out
    }

    // MARK: Atomic Christmas

    /// Mid-century trees, spindly and striped in teal and red, under atomic snowflakes and stars.
    func atomic(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 71)
        let ground = h * 0.93
        // Flakes and stars, turning.
        let spin: Double? = switch state {
        case .working: 8
        case .waiting: 1.6
        case .ready: 14
        case .idle: nil
        }
        for i in 0..<max(4, Int(w / 34)) {
            let r = h * (0.06 + 0.05 * CGFloat(rng.next()))
            let c = CGPoint(x: w * (0.5 + 0.48 * CGFloat(rng.next())), y: h * (0.1 + 0.3 * CGFloat(rng.next())))
            let flake = CALayer()
            flake.bounds = CGRect(x: -r, y: -r, width: 2 * r, height: 2 * r)
            flake.position = c
            let color = i % 3 == 0 ? Ink.red : Ink.teal
            if i % 2 == 0 {
                let arms = CGMutablePath(), tips = CGMutablePath()
                for k in 0..<3 {
                    let a = CGFloat(k) * .pi / 3
                    let d = CGPoint(x: cos(a) * r * 0.8, y: sin(a) * r * 0.8)
                    arms.move(to: CGPoint(x: -d.x, y: -d.y))
                    arms.addLine(to: d)
                    for e in [d, CGPoint(x: -d.x, y: -d.y)] {
                        tips.addEllipse(in: CGRect(x: e.x - r * 0.12, y: e.y - r * 0.12, width: r * 0.24, height: r * 0.24))
                    }
                }
                flake.addSublayer(strokeLayer(arms, flake.bounds.size, color, max(0.7, r * 0.08)).moved(to: flake.bounds))
                flake.addSublayer(fillLayer(tips, flake.bounds.size, color).moved(to: flake.bounds))
            } else {
                flake.addSublayer(fillLayer(concaveStar(.zero, r * 0.7), flake.bounds.size, Ink.mustard).moved(to: flake.bounds))
            }
            if let spin {
                animate(flake, "transform.rotation.z", [0, (i % 2 == 0 ? 1.0 : -1.0) * Double.pi], period: spin * (0.8 + 0.4 * rng.next()),
                        offset: Double(i) / 5, linear: true)
            }
            out.append(flake)
        }
        let trees: [(x: CGFloat, tall: CGFloat, half: CGFloat, color: NSColor, striped: Bool)] = [
            (0.64, 0.5, 0.05, Ink.red, false), (0.72, 0.74, 0.07, Ink.teal, true), (0.8, 0.56, 0.05, Ink.paleTeal, false),
            (0.88, 0.82, 0.07, Ink.red, true), (0.96, 0.52, 0.05, Ink.teal, false),
        ]
        for (i, t) in trees.enumerated() {
            let tall = h * t.tall, half = max(w * t.half, h * 0.12)
            let tree = CALayer()
            tree.bounds = CGRect(x: -half, y: -tall - h * 0.1, width: 2 * half, height: tall + h * 0.1)
            tree.anchorPoint = CGPoint(x: 0.5, y: 1)
            tree.position = CGPoint(x: w * t.x, y: ground)
            let body = CGMutablePath()
            body.move(to: CGPoint(x: 0, y: -tall))
            if t.striped {
                body.addLine(to: CGPoint(x: half, y: 0))
                body.addLine(to: CGPoint(x: -half, y: 0))
            } else {
                body.addQuadCurve(to: CGPoint(x: half, y: 0), control: CGPoint(x: half * 0.12, y: -tall * 0.25))
                body.addLine(to: CGPoint(x: -half, y: 0))
                body.addQuadCurve(to: CGPoint(x: 0, y: -tall), control: CGPoint(x: -half * 0.12, y: -tall * 0.25))
            }
            body.closeSubpath()
            tree.addSublayer(fillLayer(body, tree.bounds.size, t.color).moved(to: tree.bounds))
            let lines = CGMutablePath()
            // A thin stick through the top, with a bead.
            lines.move(to: CGPoint(x: 0, y: -tall - h * 0.07))
            lines.addLine(to: CGPoint(x: 0, y: -tall * 0.6))
            if t.striped {
                for k in 0..<4 {
                    let y = -tall * (0.7 - 0.17 * CGFloat(k))
                    let reach = half * (1 + y / tall) * 0.92
                    lines.move(to: CGPoint(x: -reach, y: y))
                    lines.addLine(to: CGPoint(x: reach, y: y))
                }
            }
            tree.addSublayer(strokeLayer(lines, tree.bounds.size, Ink.paper, max(0.7, h * 0.012)).moved(to: tree.bounds))
            let bead = CGPath(ellipseIn: CGRect(x: -h * 0.025, y: -tall - h * 0.095, width: h * 0.05, height: h * 0.05), transform: nil)
            tree.addSublayer(fillLayer(bead, tree.bounds.size, t.color == Ink.red ? Ink.teal : Ink.red).moved(to: tree.bounds))
            if state == .waiting {
                animate(tree, "transform.rotation.z", [-0.06, 0.06, -0.06], period: 0.6, offset: Double(i) / 5)
            }
            out.append(tree)
        }
        out.append(fillLayer(CGPath(rect: CGRect(x: w * 0.55, y: ground, width: w * 0.45, height: max(1, h * 0.012)), transform: nil),
                             size, Ink.ink))
        return out
    }

    // MARK: Bauhaus Christmas

    /// A grid of square tiles in green, red and paper, each with one shape (a quarter circle, half
    /// circle, star, tree), turning a quarter at a time.
    func tiles(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 83)
        let t = h / 3
        let cols = max(2, Int((w * 0.48 / t).rounded(.up)))
        let grounds = [Ink.green, Ink.red, Ink.teal, Ink.paper, Ink.green, Ink.red]
        let period: Double? = switch state {
        case .working: 9
        case .waiting: 2.4
        case .ready: 18
        case .idle: nil
        }
        for row in 0..<3 {
            for col in 0..<cols {
                let i = row * cols + col
                let rect = CGRect(x: w - CGFloat(cols - col) * t, y: CGFloat(row) * t, width: t, height: t)
                let ground = grounds[(i * 7 + row) % grounds.count]
                let tile = CALayer()
                tile.frame = rect
                tile.masksToBounds = true
                tile.backgroundColor = ground.cgColor
                let inks: [NSColor] = [Ink.paper, Ink.red, Ink.green]
                let figure: NSColor = inks.first { $0 !== ground } ?? Ink.paper
                let motif = CAShapeLayer()
                motif.bounds = CGRect(x: -t / 2, y: -t / 2, width: t, height: t)
                motif.position = CGPoint(x: t / 2, y: t / 2)
                let p = CGMutablePath()
                switch Int(rng.next() * 5) {
                case 0:
                    p.move(to: CGPoint(x: -t / 2, y: -t / 2))
                    p.addArc(center: CGPoint(x: -t / 2, y: -t / 2), radius: t, startAngle: 0, endAngle: .pi / 2, clockwise: false)
                    p.closeSubpath()
                case 1:
                    p.addArc(center: CGPoint(x: 0, y: t / 2), radius: t / 2, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
                    p.closeSubpath()
                case 2:
                    p.addPath(concaveStar(.zero, t * 0.42))
                case 3:
                    p.addLines(between: [CGPoint(x: -t / 2, y: t / 2), CGPoint(x: t / 2, y: -t / 2), CGPoint(x: t / 2, y: t / 2)])
                    p.closeSubpath()
                default:
                    p.addEllipse(in: CGRect(x: -t * 0.3, y: -t * 0.3, width: t * 0.6, height: t * 0.6))
                }
                motif.path = p
                motif.fillColor = figure.cgColor
                motif.setAffineTransform(CGAffineTransform(rotationAngle: CGFloat(Int(rng.next() * 4)) * .pi / 2))
                let phase = rng.next()
                if let period {
                    // Four quarter turns a loop: rest, then a quick snap to the next quarter.
                    var values: [Double] = [0], times: [Double] = [0]
                    for q in 0..<4 {
                        values += [Double(q) * .pi / 2, Double(q + 1) * .pi / 2]
                        times += [Double(q) / 4 + 0.18, Double(q + 1) / 4]
                    }
                    animate(motif, "transform.rotation.z", values, times: times, period: period, offset: phase, linear: true)
                }
                tile.addSublayer(motif)
                out.append(tile)
            }
        }
        return out
    }
}

extension CALayer {
    /// Puts a layer drawn in `bounds` coordinates into its parent's bounds.
    func moved(to bounds: CGRect) -> Self {
        frame = bounds
        self.bounds = bounds
        return self
    }
}
