import AppKit
import QuartzCore

// Worlds backdrops (SkinBackdrop.swift has the view and helpers; SkinHolidays.swift has `Ink`,
// `step`, `almond` and `concaveStar`): 8-bit color cycling, a license plate, a tarot card, a dot
// painting, an ensō, a scrimshaw whale, a harbor, a boho arch, a folk reindeer. Flat shapes in
// a few inks, drawn for the card's size, y down.

private func hex(_ s: String) -> NSColor { NSColor(hex: s)! }

extension BackdropArt {
    // MARK: Color cycle

    /// A plasma picture in 16 brightness levels; the darkest stays black and the other 15 walk
    /// through a palette, so the whole card strobes through colors like an 8-bit demo.
    func colorCycle(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        let px = max(3, (h / 30).rounded())
        let cols = Int((w / px).rounded(.up)), rows = Int((h / px).rounded(.up))
        let (palette, steps): ([String], Double) = switch state {
        case .working: (Self.hauntedNeon, 10)
        case .waiting: (Self.pumpkinFire, 20)
        case .ready: (Self.ectoplasm, 4)
        case .idle: (Self.dosEGA, 1.5)
        }
        let c1 = (x: Double(cols) * 0.78, y: Double(rows) * 0.5), c2 = (x: Double(cols) * 0.15, y: Double(rows) * 1.2)
        let paths = (0..<16).map { _ in CGMutablePath() }
        for y in 0..<rows {
            var start = 0, run = -1
            for x in 0...cols {
                var level = -1
                if x < cols {
                    let fx = Double(x), fy = Double(y)
                    let a = sin(fx * 0.16) + sin(fy * 0.21 + fx * 0.06)
                    let b = sin(hypot(fx - c1.x, fy - c1.y) * 0.42) + sin(hypot(fx - c2.x, fy - c2.y) * 0.3)
                    level = min(15, max(0, Int((a + b + 4) / 8 * 16)))
                }
                if level != run {
                    if run >= 0 {
                        paths[run].addRect(CGRect(x: CGFloat(start) * px - 0.25, y: CGFloat(y) * px - 0.25,
                                                  width: CGFloat(x - start) * px + 0.5, height: px + 0.5))
                    }
                    start = x
                    run = level
                }
            }
        }
        var out: [CALayer] = []
        for (level, path) in paths.enumerated() where !path.isEmpty {
            guard level > 0 else { out.append(fillLayer(path, size, .black)); continue }
            let colors = (0..<15).map { hex(palette[(level - 1 + $0) % 15]).cgColor }
            let layer = fillLayer(path, size, NSColor(cgColor: colors[0])!)
            step(layer, "fillColor", colors, period: 15 / steps)
            out.append(layer)
        }
        if state == .waiting {
            // A strobe on the beat, like the party's flash.
            let flash = fillLayer(CGPath(rect: CGRect(origin: .zero, size: size), transform: nil), size, .white)
            flash.opacity = 0
            step(flash, "opacity", [0.0, 0.0, 0.0, 0.4], period: 0.8)
            out.append(flash)
        }
        return out
    }

    // Palettes from the party visualizer.
    static let hauntedNeon = ["#2b0047", "#5a00b5", "#9d00ff", "#ff00c8", "#ff2a2a", "#ff6a00", "#ffb000", "#ffe600", "#b6ff00",
                              "#39ff14", "#00ff9c", "#00e5ff", "#0080ff", "#2a2aff", "#7a00ff"]
    static let pumpkinFire = ["#1a0000", "#400000", "#7a0000", "#b30000", "#ff0000", "#ff4000", "#ff7a00", "#ffa000", "#ffd000",
                              "#fff200", "#ffffff", "#fff200", "#ff9000", "#ff3000", "#800000"]
    static let ectoplasm = ["#0a1a14", "#12332a", "#1d5c47", "#2e8a6b", "#5fd3a6", "#a8ffe0", "#e8fff7", "#ffffff", "#c8ffe8",
                            "#7affc8", "#3cbf8f", "#1f7a5c", "#145c45", "#0d3d2e", "#081f17"]
    static let dosEGA = ["#000033", "#000066", "#0000aa", "#0055ff", "#00aaff", "#55ffff", "#ffffff", "#ff55ff", "#aa00aa",
                         "#550055", "#ff5555", "#aa0000", "#ffff55", "#aa5500", "#00aa00"]

    // MARK: License plate

    /// A yellow plate: embossed rim, bolt slots, a red sun, and a registration sticker in the
    /// state's color.
    func plate(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        let red = hex("#B5161B")
        let rim = CGMutablePath()
        rim.addRoundedRect(in: CGRect(origin: .zero, size: size).insetBy(dx: 4, dy: 4), cornerWidth: 6, cornerHeight: 6)
        out.append(strokeLayer(rim, size, hex("#C99A0A"), 1.6))
        let slots = CGMutablePath()
        for x in [w * 0.22, w * 0.78] {
            slots.addRoundedRect(in: CGRect(x: x - 5, y: h - 11, width: 10, height: 4), cornerWidth: 2, cornerHeight: 2)
        }
        out.append(fillLayer(slots, size, hex("#4A3A12")))
        // The sun: a disc with a ring cut in it, long and short rays.
        let reach = h * 0.44, sr = h * 0.13
        let sun = CALayer()
        sun.bounds = CGRect(x: -reach, y: -reach, width: 2 * reach, height: 2 * reach)
        sun.position = CGPoint(x: w * 0.7, y: h * 0.52)
        let rays = CGMutablePath()
        for k in 0..<16 {
            let a = CGFloat(k) * .pi / 8, tip = sr * (k % 2 == 0 ? 3.2 : 2.4)
            rays.addLines(between: [CGPoint(x: cos(a - 0.08) * sr * 1.3, y: sin(a - 0.08) * sr * 1.3), CGPoint(x: cos(a) * tip, y: sin(a) * tip),
                                    CGPoint(x: cos(a + 0.08) * sr * 1.3, y: sin(a + 0.08) * sr * 1.3)])
            rays.closeSubpath()
        }
        let rayLayer = fillLayer(rays, sun.bounds.size, red).moved(to: sun.bounds)
        sun.addSublayer(rayLayer)
        sun.addSublayer(fillLayer(CGPath(ellipseIn: CGRect(x: -sr, y: -sr, width: 2 * sr, height: 2 * sr), transform: nil),
                                  sun.bounds.size, red).moved(to: sun.bounds))
        sun.addSublayer(strokeLayer(CGPath(ellipseIn: CGRect(x: -sr * 0.62, y: -sr * 0.62, width: sr * 1.24, height: sr * 1.24), transform: nil),
                                    sun.bounds.size, hex("#F4C820"), sr * 0.14).moved(to: sun.bounds))
        switch state {
        case .working: animate(rayLayer, "transform.rotation.z", [0, Double.pi / 4], period: 8, linear: true)
        case .waiting: animate(sun, "transform.scale", [1, 1.12, 1], period: 0.6)
        default: break
        }
        out.append(sun)
        // The sticker, top right.
        let sticker = CGRect(x: w - 30, y: 9, width: 20, height: 12)
        out.append(fillLayer(CGPath(roundedRect: sticker, cornerWidth: 2, cornerHeight: 2, transform: nil), size, accent))
        let marks = CGMutablePath()
        marks.addRect(CGRect(x: sticker.minX + 3, y: sticker.minY + 3, width: 8, height: 2))
        marks.addRect(CGRect(x: sticker.minX + 3, y: sticker.minY + 7, width: 13, height: 1.5))
        out.append(fillLayer(marks, size, hex("#1E1B18").withAlphaComponent(0.7)))
        return out
    }

    // MARK: Tarot

    /// A tarot card of the desert at night: a cream frame, a crescent moon, sun rays behind the
    /// mesas, saguaros, in woodcut colors.
    func tarot(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 89)
        let cream = hex("#EADBC0"), gold = hex("#D9A85B"), night = hex("#15122B")
        let horizon = h * 0.74
        // Stars.
        let still = CGMutablePath(), twinkle = CGMutablePath()
        for i in 0..<max(12, Int(w / 9)) {
            let r = 0.4 + CGFloat(rng.next()) * 0.7
            let rect = CGRect(x: CGFloat(rng.next()) * w, y: CGFloat(rng.next()) * horizon * 0.85, width: 2 * r, height: 2 * r)
            (i % 3 == 0 ? twinkle : still).addEllipse(in: rect)
        }
        out.append(fillLayer(still, size, cream))
        let twinkling = fillLayer(twinkle, size, cream)
        if state != .idle { animate(twinkling, "opacity", [1, 0.2, 1], period: 1.6) }
        out.append(twinkling)
        // Rays fanning up from behind the mesas.
        let hp = CGPoint(x: w * 0.72, y: horizon)
        let fan = CALayer()
        fan.bounds = CGRect(origin: .zero, size: size)
        fan.anchorPoint = CGPoint(x: hp.x / w, y: hp.y / h)
        fan.position = hp
        let rays = CGMutablePath()
        for k in 1..<14 {
            let a = CGFloat.pi + CGFloat(k) * .pi / 14
            rays.move(to: CGPoint(x: hp.x + cos(a) * h * 0.18, y: hp.y + sin(a) * h * 0.18))
            rays.addLine(to: CGPoint(x: hp.x + cos(a) * h * 0.62, y: hp.y + sin(a) * h * 0.62))
        }
        fan.addSublayer(strokeLayer(rays, size, gold.withAlphaComponent(0.7), 0.8))
        switch state {
        case .working: animate(fan, "transform.scale", [0.85, 1.05, 0.85], period: 3)
        case .waiting: step(fan, "opacity", [1.0, 0.2], period: 0.5)
        case .idle: fan.opacity = 0.4
        case .ready: break
        }
        out.append(fan)
        // The moon: a disc with night cut out of it.
        let mr = h * 0.12, mc = CGPoint(x: w * 0.86, y: h * 0.26)
        let moon = fillLayer(CGPath(ellipseIn: CGRect(x: mc.x - mr, y: mc.y - mr, width: 2 * mr, height: 2 * mr), transform: nil), size, cream)
        if state == .waiting { step(moon, "fillColor", [cream.cgColor, hex("#E2574C").cgColor], period: 0.7) }
        out.append(moon)
        out.append(fillLayer(CGPath(ellipseIn: CGRect(x: mc.x - mr * 0.55, y: mc.y - mr * 1.15, width: 2 * mr, height: 2 * mr), transform: nil),
                             size, night))
        // Mesas and the ground.
        let mesas = CGMutablePath()
        mesas.addLines(between: [CGPoint(x: w * 0.48, y: horizon), CGPoint(x: w * 0.52, y: h * 0.5), CGPoint(x: w * 0.6, y: h * 0.5),
                                 CGPoint(x: w * 0.62, y: h * 0.6), CGPoint(x: w * 0.67, y: h * 0.6), CGPoint(x: w * 0.69, y: horizon)])
        mesas.addLines(between: [CGPoint(x: w * 0.8, y: horizon), CGPoint(x: w * 0.83, y: h * 0.47), CGPoint(x: w * 0.93, y: h * 0.47),
                                 CGPoint(x: w * 0.96, y: horizon)])
        out.append(fillLayer(mesas, size, hex("#B4532A")))
        let ground = CGMutablePath()
        ground.addRect(CGRect(x: 0, y: horizon, width: w, height: h - horizon))
        out.append(fillLayer(ground, size, hex("#D9752E")))
        let furrow = CGMutablePath()
        furrow.move(to: CGPoint(x: 0, y: h * 0.86))
        furrow.addCurve(to: CGPoint(x: w, y: h * 0.84), control1: CGPoint(x: w * 0.3, y: h * 0.8), control2: CGPoint(x: w * 0.6, y: h * 0.92))
        furrow.addLine(to: CGPoint(x: w, y: h))
        furrow.addLine(to: CGPoint(x: 0, y: h))
        furrow.closeSubpath()
        out.append(fillLayer(furrow, size, hex("#8E3B1E")))
        // Saguaros.
        let cacti = CGMutablePath()
        for (x, s) in [(w * 0.57, h * 0.5), (w * 0.9, h * 0.36)] {
            let base = h * 0.95
            cacti.move(to: CGPoint(x: x, y: base)); cacti.addLine(to: CGPoint(x: x, y: base - s))
            cacti.move(to: CGPoint(x: x, y: base - s * 0.45)); cacti.addLine(to: CGPoint(x: x + s * 0.2, y: base - s * 0.45))
            cacti.addLine(to: CGPoint(x: x + s * 0.2, y: base - s * 0.72))
            cacti.move(to: CGPoint(x: x, y: base - s * 0.6)); cacti.addLine(to: CGPoint(x: x - s * 0.17, y: base - s * 0.6))
            cacti.addLine(to: CGPoint(x: x - s * 0.17, y: base - s * 0.82))
        }
        let saguaro = strokeLayer(cacti, size, hex("#7E9B78"), max(2.5, h * 0.055))
        saguaro.lineCap = .round
        saguaro.lineJoin = .round
        out.append(saguaro)
        if state == .ready {
            let streak = CGMutablePath()
            streak.move(to: .zero)
            streak.addLine(to: CGPoint(x: -h * 0.16, y: h * 0.06))
            let star = strokeLayer(streak, size, cream, 1)
            animate(star, "position", [NSValue(point: NSPoint(x: w * 0.3 + w / 2, y: h * 0.08 + h / 2)),
                                       NSValue(point: NSPoint(x: w * 0.05 + w / 2, y: h * 0.2 + h / 2))], times: [0, 0.15], period: 4)
            animate(star, "opacity", [1, 0, 0], times: [0, 0.15, 1], period: 4)
            out.append(star)
        }
        // The card's frame.
        let outer = CGMutablePath(), inner = CGMutablePath()
        outer.addRoundedRect(in: CGRect(origin: .zero, size: size).insetBy(dx: 3.5, dy: 3.5), cornerWidth: 3, cornerHeight: 3)
        let box = CGRect(origin: .zero, size: size).insetBy(dx: 7.5, dy: 7.5)
        inner.addRect(box)
        out.append(strokeLayer(outer, size, cream, 2))
        out.append(strokeLayer(inner, size, gold, 0.7))
        let corners = CGMutablePath()
        for p in [CGPoint(x: box.minX, y: box.minY), CGPoint(x: box.maxX, y: box.minY), CGPoint(x: box.minX, y: box.maxY),
                  CGPoint(x: box.maxX, y: box.maxY)] {
            corners.addPath(concaveStar(p, 3.5))
        }
        out.append(fillLayer(corners, size, gold))
        return out
    }

    // MARK: Pointillism

    /// A riverside afternoon painted in dots: each patch is a mix of pure colors that blend in the
    /// eye (sky blue with pink and white, water with sun glints), a sailboat, the sun.
    func seurat(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var rng = Scribble(UInt64(w) + 97)
        let d = max(2.6, h / 26)
        let horizon = h * 0.56
        let sun = CGPoint(x: w * 0.8, y: h * 0.26), sr = h * 0.13
        let bx = w * 0.56
        let sail = CGMutablePath()
        sail.addLines(between: [CGPoint(x: bx, y: h * 0.3), CGPoint(x: bx, y: h * 0.7), CGPoint(x: bx + h * 0.24, y: h * 0.7)])
        sail.closeSubpath()
        let hull = CGMutablePath()
        hull.addLines(between: [CGPoint(x: bx - h * 0.08, y: h * 0.71), CGPoint(x: bx + h * 0.3, y: h * 0.71), CGPoint(x: bx + h * 0.24, y: h * 0.78),
                                CGPoint(x: bx - h * 0.03, y: h * 0.78)])
        hull.closeSubpath()
        let palettes: [String: [String]] = [
            "sky": ["#8DB8E8", "#8DB8E8", "#A9C8F5", "#A9C8F5", "#F4C7D9"],
            "warm": ["#F9E39A", "#F4C7D9", "#FFFFFF", "#FFC98A"],
            "sun": ["#FFC93C", "#FF9F43", "#FFB347"],
            "shore": ["#2F6B3A", "#3E7D3E", "#6FAE4A", "#2E5E8C"],
            "water": ["#2E4E8C", "#3E7CB1", "#3E7CB1", "#6FA3D9", "#9B5DE5"],
            "glint": ["#FFD23F", "#FFF0A0", "#FF9F43", "#6FA3D9"],
            "sail": ["#E4572E", "#C8372D", "#F2A541"],
            "hull": ["#B5402B", "#7A2A1E", "#E4572E"],
        ]
        var dots: [String: [String: CGMutablePath]] = [:]
        var row = 0
        var y = d / 2
        while y < h + d {
            var x = row % 2 == 0 ? d / 2 : d
            while x < w + d {
                let p = CGPoint(x: x + CGFloat(rng.next() - 0.5) * d * 0.5, y: y + CGFloat(rng.next() - 0.5) * d * 0.5)
                let part: String
                if sail.contains(p) { part = "sail" }
                else if hull.contains(p) { part = "hull" }
                else if hypot(p.x - sun.x, p.y - sun.y) < sr { part = "sun" }
                else if p.y < horizon - h * 0.07 { part = hypot(p.x - sun.x, p.y - sun.y) < sr * 2.2 ? "warm" : "sky" }
                else if p.y < horizon { part = "shore" }
                else if abs(p.x - sun.x) < sr * (0.7 + (p.y - horizon) / h), rng.next() < 0.6 { part = "glint" }
                else { part = "water" }
                // Leave the sky behind the text lighter.
                let skip = part == "sky" && (p.x < w * 0.5 ? rng.next() < 0.8 : rng.next() < 0.3)
                if !skip {
                    let colors = palettes[part]!
                    let color = colors[Int(rng.next() * Double(colors.count)) % colors.count]
                    let r = d * (0.4 + 0.08 * CGFloat(rng.next()))
                    let path = dots[part, default: [:]][color] ?? CGMutablePath()
                    path.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
                    dots[part, default: [:]][color] = path
                }
                x += d
            }
            y += d * 0.87
            row += 1
        }
        func group(_ parts: [String]) -> CALayer {
            let g = CALayer()
            g.bounds = CGRect(origin: .zero, size: size)
            g.position = CGPoint(x: w / 2, y: h / 2)
            for part in parts {
                for (color, path) in (dots[part] ?? [:]).sorted(by: { $0.key < $1.key }) {
                    g.addSublayer(fillLayer(path, size, hex(color)))
                }
            }
            return g
        }
        let sky = group(["sky", "warm", "shore"])
        let sunDots = group(["sun"])
        sunDots.anchorPoint = CGPoint(x: sun.x / w, y: sun.y / h)
        sunDots.position = sun
        let water = group(["water"])
        let glints = group(["glint"])
        let boat = group(["sail", "hull"])
        switch state {
        case .working:
            animate(water, "transform.translation.x", [-Double(d) / 2, Double(d) / 2, -Double(d) / 2], period: 3)
            animate(boat, "transform.translation.x", [0, -Double(w) * 0.06, 0], period: 8)
        case .waiting:
            animate(sunDots, "transform.scale", [1, 1.15, 1], period: 0.7)
            animate(boat, "transform.rotation.z", [-0.02, 0.02, -0.02], period: 0.8)
        case .ready:
            animate(boat, "transform.translation.x", [0, -Double(w) * 0.12, 0], period: 14)
        case .idle:
            break
        }
        if state != .idle {
            for (i, layer) in (glints.sublayers ?? []).enumerated() {
                animate(layer, "opacity", [1, 0.15, 1], period: 1.2 + 0.3 * Double(i), offset: Double(i) / 4)
            }
        }
        return [sky, sunDots, water, glints, boat]
    }

    // MARK: Ensō

    /// A brushed ensō that paints itself while it works, a gold kintsugi seam with light running
    /// along it, and a red seal.
    func enso(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 101)
        let ink = hex("#2B2723")
        // Paper fibers.
        let fibers = CGMutablePath()
        for _ in 0..<max(10, Int(w / 16)) {
            let p = CGPoint(x: CGFloat(rng.next()) * w, y: CGFloat(rng.next()) * h)
            fibers.move(to: p)
            fibers.addQuadCurve(to: CGPoint(x: p.x + 6 + CGFloat(rng.next()) * 10, y: p.y + CGFloat(rng.next() - 0.5) * 4),
                                control: CGPoint(x: p.x + 4, y: p.y + CGFloat(rng.next() - 0.5) * 6))
        }
        out.append(strokeLayer(fibers, size, hex("#D6CBB8"), 0.5))
        // The ensō: a brush stroke that starts heavy and trails off, with an open gap.
        let c = CGPoint(x: w * 0.76, y: h * 0.5), radius = h * 0.33, brush = max(3, h * 0.08)
        let a0 = -CGFloat.pi * 0.38, sweep = 2 * CGFloat.pi * 0.88
        var outer: [CGPoint] = [], inner: [CGPoint] = [], center: [CGPoint] = []
        let n = 90
        for i in 0...n {
            let t = CGFloat(i) / CGFloat(n)
            let a = a0 + sweep * t
            let width = brush * (1 - 0.75 * pow(t, 1.6)) * (0.88 + 0.12 * sin(t * 11))
            let r = radius * (1 + 0.035 * sin(t * 5 + 1))
            outer.append(CGPoint(x: c.x + cos(a) * (r + width / 2), y: c.y + sin(a) * (r + width / 2)))
            inner.append(CGPoint(x: c.x + cos(a) * (r - width / 2), y: c.y + sin(a) * (r - width / 2)))
            center.append(CGPoint(x: c.x + cos(a) * r, y: c.y + sin(a) * r))
        }
        let stroke = CGMutablePath()
        stroke.addLines(between: outer + inner.reversed())
        stroke.closeSubpath()
        let enso = CALayer()
        enso.frame = CGRect(origin: .zero, size: size)
        enso.addSublayer(fillLayer(stroke, size, ink))
        // Dry-brush streaks where the ink runs thin.
        let dry = CGMutablePath()
        for (k, offset) in [-0.18, 0.12, 0.3].enumerated() {
            let from = 50 + k * 8
            dry.addLines(between: (from...n).map { i in
                let p = center[i], q = outer[i]
                return CGPoint(x: p.x + (q.x - p.x) * CGFloat(offset) * 2, y: p.y + (q.y - p.y) * CGFloat(offset) * 2)
            })
        }
        enso.addSublayer(strokeLayer(dry, size, hex("#EDE6DA"), 0.6))
        if state == .working || state == .waiting {
            let reveal = CAShapeLayer()
            reveal.frame = enso.bounds
            let spine = CGMutablePath()
            spine.addLines(between: center)
            reveal.path = spine
            reveal.strokeColor = NSColor.black.cgColor
            reveal.fillColor = nil
            reveal.lineWidth = brush * 2
            reveal.lineCap = .round
            animate(reveal, "strokeEnd", [0, 1, 1], times: [0, 0.6, 1], period: state == .working ? 4 : 1.4, linear: true)
            enso.mask = reveal
        }
        out.append(enso)
        // Kintsugi: a gold seam mending a crack, light running along it.
        let crack = CGMutablePath()
        crack.addLines(between: [CGPoint(x: w * 0.5, y: h + 1), CGPoint(x: w * 0.53, y: h * 0.82), CGPoint(x: w * 0.51, y: h * 0.7),
                                 CGPoint(x: w * 0.56, y: h * 0.55), CGPoint(x: w * 0.55, y: h * 0.42)])
        crack.move(to: CGPoint(x: w * 0.53, y: h * 0.82))
        crack.addLines(between: [CGPoint(x: w * 0.53, y: h * 0.82), CGPoint(x: w * 0.58, y: h * 0.77), CGPoint(x: w * 0.6, y: h * 0.81)])
        out.append(strokeLayer(crack, size, hex("#C9A227"), 1.4))
        if state != .idle {
            let shine = strokeLayer(crack, size, hex("#F6E7A6"), 1.4)
            let period: Double = state == .waiting ? 1 : state == .working ? 3 : 5
            animate(shine, "strokeStart", [0, 0.88], period: period, linear: true)
            animate(shine, "strokeEnd", [0.12, 1], period: period, linear: true)
            out.append(shine)
        }
        // The seal: a red square with an abstract mark.
        let s = h * 0.13
        let seal = CALayer()
        seal.frame = CGRect(x: c.x + radius * 0.72, y: c.y + radius * 0.55, width: s, height: s)
        seal.backgroundColor = hex("#B83A2B").cgColor
        let mark = CGMutablePath()
        mark.move(to: CGPoint(x: s * 0.3, y: s * 0.2)); mark.addLine(to: CGPoint(x: s * 0.3, y: s * 0.8))
        mark.move(to: CGPoint(x: s * 0.7, y: s * 0.2)); mark.addLine(to: CGPoint(x: s * 0.7, y: s * 0.55))
        mark.move(to: CGPoint(x: s * 0.2, y: s * 0.5)); mark.addLine(to: CGPoint(x: s * 0.8, y: s * 0.5))
        seal.addSublayer(strokeLayer(mark, CGSize(width: s, height: s), hex("#EDE6DA"), max(0.8, s * 0.09)))
        switch state {
        case .ready: animate(seal, "transform.scale", [1.35, 1, 1], times: [0, 0.08, 1], period: 4)
        case .idle: seal.opacity = 0.35
        default: break
        }
        out.append(seal)
        return out
    }

    // MARK: Scrimshaw

    /// An engraved sperm whale surfacing, hatched in ink, under a red-ink sun, a ship far off.
    func whale(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        let ink = hex("#1C1A17"), red = hex("#A3291E"), ivory = hex("#F3EAD3")
        let horizon = h * 0.6
        // The red sun, hatched.
        let sc = CGPoint(x: w * 0.4, y: horizon), sr = h * 0.2
        let sun = CGMutablePath()
        sun.addArc(center: sc, radius: sr, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
        var y = horizon - 1.5
        while y > horizon - sr {
            let half = sqrt(max(0, sr * sr - (horizon - y) * (horizon - y)))
            sun.move(to: CGPoint(x: sc.x - half, y: y))
            sun.addLine(to: CGPoint(x: sc.x + half, y: y))
            y -= 2.2
        }
        out.append(strokeLayer(sun, size, red, 0.7))
        // A ship on the horizon.
        let ship = CGMutablePath()
        let sx = w * 0.18, unit = h * 0.05
        ship.addLines(between: [CGPoint(x: sx - unit * 2, y: horizon - unit * 0.4), CGPoint(x: sx + unit * 2, y: horizon - unit * 0.4),
                                CGPoint(x: sx + unit * 1.5, y: horizon), CGPoint(x: sx - unit * 1.6, y: horizon)])
        ship.closeSubpath()
        for (k, mast) in [-1.0, 0.1, 1.1].enumerated() {
            let mx = sx + CGFloat(mast) * unit, tall = unit * (k == 1 ? 3 : 2.4)
            ship.move(to: CGPoint(x: mx, y: horizon - unit * 0.4)); ship.addLine(to: CGPoint(x: mx, y: horizon - unit * 0.4 - tall))
            for s in 0..<2 {
                let sy = horizon - unit * 0.6 - tall + CGFloat(s) * tall * 0.45
                ship.addRect(CGRect(x: mx - unit * 0.6, y: sy + tall * 0.08, width: unit * 1.2, height: tall * 0.32))
            }
        }
        out.append(strokeLayer(ship, size, ink, 0.6))
        // The whale, facing left.
        let length = min(w * 0.5, h * 2.2)
        let x0 = w * 0.46, y0 = horizon + length * 0.04
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: x0 + u * length, y: y0 + v * length) }
        let body = CGMutablePath()
        body.move(to: p(0, -0.1))
        body.addQuadCurve(to: p(0.05, -0.16), control: p(0, -0.16))
        body.addLine(to: p(0.42, -0.15))
        body.addQuadCurve(to: p(0.85, -0.03), control: p(0.66, -0.15))
        body.addLine(to: p(0.92, -0.01))
        body.addQuadCurve(to: p(1, -0.1), control: p(0.95, -0.08))
        body.addQuadCurve(to: p(0.95, 0), control: p(1.01, -0.02))
        body.addQuadCurve(to: p(1, 0.08), control: p(1.01, 0.02))
        body.addQuadCurve(to: p(0.9, 0.02), control: p(0.95, 0.07))
        body.addQuadCurve(to: p(0.3, 0.09), control: p(0.6, 0.09))
        body.addLine(to: p(0.12, 0.07))
        body.addLine(to: p(0.04, 0.03))
        body.addQuadCurve(to: p(0, -0.1), control: p(0, 0))
        body.closeSubpath()
        let whale = CALayer()
        whale.bounds = CGRect(origin: .zero, size: size)
        whale.anchorPoint = CGPoint(x: (x0 + length * 0.5) / w, y: y0 / h)
        whale.position = CGPoint(x: x0 + length * 0.5, y: y0)
        whale.addSublayer(fillLayer(body, size, ivory))
        let hatch = CGMutablePath()
        var k = -h
        while k < w {
            hatch.move(to: CGPoint(x: k, y: h)); hatch.addLine(to: CGPoint(x: k + h, y: 0))
            k += 2.4
        }
        let shading = strokeLayer(hatch, size, ink, 0.5)
        let clip = CAShapeLayer()
        clip.path = body
        shading.mask = clip
        whale.addSublayer(shading)
        // A highlight along the back, then the outline and details.
        whale.addSublayer(fillLayer(almond(p(0.4, -0.11), length: length * 0.6, width: length * 0.035, angle: .pi / 2 + 0.06), size, ivory))
        whale.addSublayer(strokeLayer(body, size, ink, 1))
        let details = CGMutablePath()
        details.addEllipse(in: CGRect(origin: p(0.14, -0.02), size: CGSize(width: length * 0.02, height: length * 0.014)))
        details.move(to: p(0.04, 0.03)); details.addQuadCurve(to: p(0.22, 0.05), control: p(0.12, 0.05))
        for u in [0.3, 0.34, 0.38] as [CGFloat] {
            details.move(to: p(u, -0.12)); details.addQuadCurve(to: p(u, 0.06), control: p(u + 0.02, -0.03))
        }
        whale.addSublayer(strokeLayer(details, size, ink, 0.7))
        // The spout.
        let blow = p(0.04, -0.17)
        let spout = CALayer()
        spout.bounds = CGRect(origin: .zero, size: size)
        spout.anchorPoint = CGPoint(x: blow.x / w, y: blow.y / h)
        spout.position = blow
        let spray = CGMutablePath()
        for a in [-0.5, -0.25, 0, 0.25, 0.5] as [CGFloat] {
            spray.move(to: blow)
            spray.addQuadCurve(to: CGPoint(x: blow.x + sin(a) * h * 0.2, y: blow.y - h * 0.16 + abs(a) * h * 0.06),
                               control: CGPoint(x: blow.x + sin(a) * h * 0.04, y: blow.y - h * 0.16))
        }
        spout.addSublayer(strokeLayer(spray, size, ink, 0.7))
        switch state {
        case .working: animate(spout, "transform.scale.y", [0, 1, 1, 0], times: [0, 0.2, 0.6, 1], period: 2.4)
        case .waiting:
            animate(spout, "transform.scale.y", [0, 1, 0], period: 0.8)
            animate(whale, "transform.rotation.z", [-0.03, 0.03, -0.03], period: 0.6)
        case .ready: break
        case .idle: spout.opacity = 0
        }
        whale.addSublayer(spout)
        if state != .waiting { animate(whale, "transform.translation.y", [0, -1.2, 0], period: 3) }
        out.append(whale)
        // The sea, engraved: an ivory band over the whale's belly, wave lines rolling.
        let top = y0 + length * 0.03
        let sea = CGMutablePath()
        sea.move(to: CGPoint(x: 0, y: horizon))
        sea.addLine(to: CGPoint(x: x0 - length * 0.04, y: horizon))
        sea.addQuadCurve(to: CGPoint(x: x0 + length * 0.1, y: top), control: CGPoint(x: x0, y: top))
        sea.addLine(to: CGPoint(x: w, y: top))
        sea.addLine(to: CGPoint(x: w, y: h))
        sea.addLine(to: CGPoint(x: 0, y: h))
        sea.closeSubpath()
        out.append(fillLayer(sea, size, ivory))
        let wave = h * 0.16
        let waves = CGMutablePath()
        var row: CGFloat = 0
        var wy = horizon + 2
        while wy < h + 2 {
            if wy > top - 2 || true {
                var x = -wave - (row.truncatingRemainder(dividingBy: 2)) * wave / 2
                waves.move(to: CGPoint(x: x, y: wy))
                while x < w + wave {
                    waves.addQuadCurve(to: CGPoint(x: x + wave, y: wy), control: CGPoint(x: x + wave / 2, y: wy - 2.2))
                    x += wave
                }
            }
            wy += max(3, h * 0.06)
            row += 1
        }
        let waveLayer = strokeLayer(waves, size, ink, 0.6)
        let seaMask = CAShapeLayer()
        seaMask.path = sea
        let seaLines = CALayer()
        seaLines.frame = CGRect(origin: .zero, size: size)
        seaLines.mask = seaMask
        if state == .working || state == .waiting {
            animate(waveLayer, "transform.translation.x", [0, -Double(wave)], period: state == .working ? 3 : 1, linear: true)
        }
        seaLines.addSublayer(waveLayer)
        out.append(seaLines)
        out.append(strokeLayer(CGPath(rect: CGRect(x: -1, y: horizon, width: x0 - length * 0.04 + 1, height: 0), transform: nil), size, ink, 0.8))
        return out
    }

    // MARK: Harbor

    /// Navy line art on sailcloth, like an old engraving: a lighthouse sweeping its beam, rocks,
    /// rows of wave arcs, signal flags fluttering, a rope border.
    func harbor(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        let navy = hex("#0E2A47"), cream = hex("#F7F3E8"), red = hex("#C8262E"), white = hex("#FFFFFF"), yellow = hex("#F2C230"),
            blue = hex("#1F4E9A")
        let towerX = w * 0.86, baseY = h * 0.8, tall = h * 0.5
        let lamp = CGPoint(x: towerX, y: baseY - tall - h * 0.05)
        // The beam: engraved rays fanning left.
        if state != .idle {
            let beam = CALayer()
            beam.bounds = CGRect(origin: .zero, size: size)
            beam.anchorPoint = CGPoint(x: lamp.x / w, y: lamp.y / h)
            beam.position = lamp
            let rays = CGMutablePath()
            for k in -3...3 {
                rays.move(to: CGPoint(x: lamp.x - h * 0.08, y: lamp.y + CGFloat(k) * h * 0.006))
                rays.addLine(to: CGPoint(x: lamp.x - w * 0.5, y: lamp.y + CGFloat(k) * h * 0.035))
            }
            beam.addSublayer(strokeLayer(rays, size, navy.withAlphaComponent(0.55), 0.5))
            switch state {
            case .working: animate(beam, "transform.scale.x", [1, 0, -1, 0, 1], period: 4, linear: true)
            case .waiting: animate(beam, "transform.scale.x", [1, 0, -1, 0, 1], period: 1.2, linear: true)
            default: break
            }
            out.append(beam)
        }
        // Rocks under the tower, outlined and hatched.
        let rocks = CGMutablePath()
        rocks.addLines(between: [CGPoint(x: towerX - h * 0.26, y: h * 0.9), CGPoint(x: towerX - h * 0.18, y: baseY - h * 0.02),
                                 CGPoint(x: towerX - h * 0.04, y: baseY - h * 0.04), CGPoint(x: towerX + h * 0.1, y: baseY - h * 0.03),
                                 CGPoint(x: towerX + h * 0.22, y: baseY + h * 0.03), CGPoint(x: towerX + h * 0.3, y: h * 0.9)])
        rocks.closeSubpath()
        out.append(fillLayer(rocks, size, cream))
        let rockHatch = CGMutablePath()
        var k = towerX - h * 0.3
        while k < towerX + h * 0.32 {
            rockHatch.move(to: CGPoint(x: k, y: h * 0.9)); rockHatch.addLine(to: CGPoint(x: k + h * 0.1, y: baseY - h * 0.05))
            k += 2.2
        }
        let rockShade = strokeLayer(rockHatch, size, navy, 0.5)
        let rockMask = CAShapeLayer()
        rockMask.path = rocks
        rockShade.mask = rockMask
        out.append(rockShade)
        out.append(strokeLayer(rocks, size, navy, 0.9))
        // The sea: rows of wave arcs, engraved.
        let waves = CALayer()
        waves.frame = CGRect(origin: .zero, size: size)
        let r = h * 0.05
        let arcs = CGMutablePath()
        for row in 0..<4 {
            let y = h * 0.86 + CGFloat(row) * r * 1.1
            var x = -4 * r + CGFloat(row % 2) * r
            while x < w + 4 * r {
                arcs.move(to: CGPoint(x: x, y: y))
                arcs.addArc(center: CGPoint(x: x + r, y: y), radius: r, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
                x += 2 * r
            }
        }
        let field = CGMutablePath()
        field.addRect(CGRect(x: 0, y: h * 0.86 - r, width: w, height: h * 0.14 + r))
        out.append(fillLayer(field, size, cream))
        let arcLayer = strokeLayer(arcs, size, navy, 0.8)
        if state == .working || state == .waiting {
            animate(arcLayer, "transform.translation.x", [0, Double(2 * r)], period: state == .working ? 3 : 1, linear: true)
        }
        waves.addSublayer(arcLayer)
        out.append(waves)
        // The tower: cream, outlined, banded with hatching.
        let bw = h * 0.08, tw = h * 0.05
        let tower = CGMutablePath()
        tower.addLines(between: [CGPoint(x: towerX - bw, y: baseY), CGPoint(x: towerX - tw, y: baseY - tall), CGPoint(x: towerX + tw, y: baseY - tall),
                                 CGPoint(x: towerX + bw, y: baseY)])
        tower.closeSubpath()
        out.append(fillLayer(tower, size, cream))
        let bands = CGMutablePath()
        for b in stride(from: 0, to: 4, by: 2) {
            var y = baseY - tall * CGFloat(b + 1) / 4
            while y < baseY - tall * CGFloat(b) / 4 {
                bands.move(to: CGPoint(x: towerX - bw, y: y)); bands.addLine(to: CGPoint(x: towerX + bw, y: y))
                y += 1.6
            }
        }
        // Shade the right side, the way an engraver would.
        var sx = towerX + tw * 0.2
        while sx < towerX + bw {
            bands.move(to: CGPoint(x: sx, y: baseY)); bands.addLine(to: CGPoint(x: sx, y: baseY - tall))
            sx += 1.8
        }
        let banding = strokeLayer(bands, size, navy, 0.5)
        let towerMask = CAShapeLayer()
        towerMask.path = tower
        banding.mask = towerMask
        out.append(banding)
        out.append(strokeLayer(tower, size, navy, 1))
        // Lamp room: an outlined cage with the light inside, a gallery rail, a domed cap.
        let room = CGRect(x: lamp.x - tw * 1.1, y: lamp.y - h * 0.05, width: tw * 2.2, height: h * 0.1)
        let light = fillLayer(CGPath(rect: room.insetBy(dx: 1, dy: 1), transform: nil), size, state == .idle ? cream : yellow)
        if state == .waiting { step(light, "fillColor", [yellow.cgColor, red.cgColor], period: 0.6) }
        out.append(light)
        let cage = CGMutablePath()
        cage.addRect(room)
        for i in 1..<3 {
            let x = room.minX + room.width * CGFloat(i) / 3
            cage.move(to: CGPoint(x: x, y: room.minY)); cage.addLine(to: CGPoint(x: x, y: room.maxY))
        }
        cage.move(to: CGPoint(x: room.minX - h * 0.03, y: room.maxY)); cage.addLine(to: CGPoint(x: room.maxX + h * 0.03, y: room.maxY))
        cage.addArc(center: CGPoint(x: lamp.x, y: room.minY), radius: room.width / 2, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
        cage.move(to: CGPoint(x: lamp.x, y: room.minY - room.width / 2)); cage.addLine(to: CGPoint(x: lamp.x, y: room.minY - room.width / 2 - h * 0.04))
        out.append(strokeLayer(cage, size, navy, 0.9))
        // Signal flags strung across the top right.
        let x0 = w * 0.4, x1 = towerX - h * 0.1, sag = h * 0.06, top = h * 0.07
        let line = CGMutablePath()
        line.move(to: CGPoint(x: x0, y: top))
        line.addQuadCurve(to: CGPoint(x: x1, y: top), control: CGPoint(x: (x0 + x1) / 2, y: top + sag * 2))
        out.append(strokeLayer(line, size, navy, 0.7))
        let fs = h * 0.12
        let count = max(4, Int((x1 - x0) / (fs * 1.35)))
        for i in 0..<count {
            let t = (CGFloat(i) + 0.5) / CGFloat(count)
            let x = x0 + (x1 - x0) * t, y = top + sag * 2 * 2 * t * (1 - t)
            let flag = CALayer()
            flag.bounds = CGRect(x: 0, y: 0, width: fs, height: fs)
            flag.anchorPoint = CGPoint(x: 0.5, y: 0)
            flag.position = CGPoint(x: x, y: y)
            let all = CGRect(x: 0, y: 0, width: fs, height: fs)
            func fill(_ path: CGPath, _ color: NSColor) { flag.addSublayer(fillLayer(path, all.size, color)) }
            switch i % 6 {
            case 0: fill(CGPath(rect: all, transform: nil), yellow)
            case 1:
                fill(CGPath(rect: all, transform: nil), blue)
                fill(CGPath(rect: all.insetBy(dx: fs / 3, dy: fs / 3), transform: nil), white)
            case 2:
                fill(CGPath(rect: all, transform: nil), yellow)
                let half = CGMutablePath()
                half.addLines(between: [.zero, CGPoint(x: fs, y: fs), CGPoint(x: 0, y: fs)])
                half.closeSubpath()
                fill(half, red)
            case 3:
                fill(CGPath(rect: all, transform: nil), white)
                fill(CGPath(rect: CGRect(x: fs * 0.4, y: 0, width: fs * 0.2, height: fs), transform: nil), blue)
                fill(CGPath(rect: CGRect(x: 0, y: fs * 0.4, width: fs, height: fs * 0.2), transform: nil), blue)
            case 4:
                for s in 0..<3 { fill(CGPath(rect: CGRect(x: CGFloat(s) * fs / 3, y: 0, width: fs / 3, height: fs), transform: nil), [red, white, blue][s]) }
            default:
                fill(CGPath(rect: all, transform: nil), red)
                fill(CGPath(rect: all.insetBy(dx: fs * 0.3, dy: fs * 0.3), transform: nil), yellow)
            }
            flag.addSublayer(strokeLayer(CGPath(rect: all, transform: nil), all.size, navy, 0.5))
            switch state {
            case .idle: break
            case .waiting: animate(flag, "transform.rotation.z", [-0.25, 0.25, -0.25], period: 0.4, offset: Double(i) / 6)
            default: animate(flag, "transform.rotation.z", [-0.1, 0.12, -0.1], period: 1.8, offset: Double(i) / 6)
            }
            out.append(flag)
        }
        // The rope border: a tan line with twists.
        let rope = CGMutablePath()
        rope.addRoundedRect(in: CGRect(origin: .zero, size: size).insetBy(dx: 3, dy: 3), cornerWidth: 6, cornerHeight: 6)
        out.append(strokeLayer(rope, size, hex("#C9A66B"), 3))
        let twist = strokeLayer(rope, size, hex("#8A6A3A"), 3)
        twist.lineDashPattern = [1.4, 2.4]
        twist.lineCap = .butt
        out.append(twist)
        return out
    }

    // MARK: Boho

    /// A 70s arch window: a sun rising over layered hills inside, a ring of dots, pampas grass.
    func boho(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        let terra = hex("#C2603D"), blush = hex("#E8B4A0"), sage = hex("#8E9E78"), mustard = hex("#D9A441"), deep = hex("#9E4A2E")
        let aw = min(w * 0.26, h * 0.7), ax = w * 0.94 - aw, top = h * 0.12
        let arch = CGMutablePath()
        arch.move(to: CGPoint(x: ax, y: h + 1))
        arch.addLine(to: CGPoint(x: ax, y: top + aw / 2))
        arch.addArc(center: CGPoint(x: ax + aw / 2, y: top + aw / 2), radius: aw / 2, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
        arch.addLine(to: CGPoint(x: ax + aw, y: h + 1))
        arch.closeSubpath()
        // A second arch line around the first.
        let halo = CGMutablePath()
        halo.move(to: CGPoint(x: ax - 4, y: h + 1))
        halo.addLine(to: CGPoint(x: ax - 4, y: top + aw / 2))
        halo.addArc(center: CGPoint(x: ax + aw / 2, y: top + aw / 2), radius: aw / 2 + 4, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
        halo.addLine(to: CGPoint(x: ax + aw + 4, y: h + 1))
        out.append(strokeLayer(halo, size, terra, 1.2))
        let window = CALayer()
        window.frame = CGRect(origin: .zero, size: size)
        let windowMask = CAShapeLayer()
        windowMask.path = arch
        window.mask = windowMask
        window.addSublayer(fillLayer(arch, size, blush))
        let sc = CGPoint(x: ax + aw / 2, y: h * 0.55), sr = aw * 0.2
        let sun = CALayer()
        sun.bounds = CGRect(x: -sr * 2, y: -sr * 2, width: sr * 4, height: sr * 4)
        sun.position = sc
        sun.addSublayer(fillLayer(CGPath(ellipseIn: CGRect(x: -sr, y: -sr, width: 2 * sr, height: 2 * sr), transform: nil), sun.bounds.size, mustard)
            .moved(to: sun.bounds))
        let ring = CGMutablePath()
        for k in 0..<12 {
            let a = CGFloat(k) * .pi / 6
            ring.addEllipse(in: CGRect(x: cos(a) * sr * 1.55 - 1.2, y: sin(a) * sr * 1.55 - 1.2, width: 2.4, height: 2.4))
        }
        let dots = fillLayer(ring, sun.bounds.size, mustard).moved(to: sun.bounds)
        sun.addSublayer(dots)
        switch state {
        case .idle: sun.position = CGPoint(x: sc.x, y: h * 0.82)
        case .working: animate(dots, "transform.rotation.z", [0, Double.pi / 3], period: 6, linear: true)
        case .waiting: animate(sun, "transform.scale", [1, 1.2, 1], period: 0.7)
        case .ready: sun.position = CGPoint(x: sc.x, y: h * 0.42)
        }
        window.addSublayer(sun)
        for (i, color) in [terra, sage, deep].enumerated() {
            let base = h * (0.68 + 0.1 * CGFloat(i))
            let hill = CGMutablePath()
            hill.move(to: CGPoint(x: ax, y: h + 1))
            hill.addLine(to: CGPoint(x: ax, y: base + (i % 2 == 0 ? 0 : -h * 0.05)))
            hill.addQuadCurve(to: CGPoint(x: ax + aw, y: base + (i % 2 == 0 ? -h * 0.06 : 0)), control: CGPoint(x: ax + aw * 0.5, y: base - h * 0.12))
            hill.addLine(to: CGPoint(x: ax + aw, y: h + 1))
            hill.closeSubpath()
            window.addSublayer(fillLayer(hill, size, color))
        }
        out.append(window)
        // Pampas grass to the left of the arch.
        let sway: (Double, Double)? = switch state {
        case .idle: nil
        case .working: (0.08, 2.4)
        case .waiting: (0.16, 0.8)
        case .ready: (0.05, 3.4)
        }
        for (i, lean) in [-0.35, -0.15, 0.05].enumerated() {
            let tall = h * (0.8 - 0.1 * CGFloat(i))
            let stem = CALayer()
            stem.bounds = CGRect(x: -tall, y: -tall, width: 2 * tall, height: tall)
            stem.anchorPoint = CGPoint(x: 0.5, y: 1)
            stem.position = CGPoint(x: ax - aw * 0.1 - CGFloat(i) * aw * 0.22, y: h + 1)
            let end = CGPoint(x: sin(CGFloat(lean)) * tall, y: -cos(CGFloat(lean)) * tall)
            let line = CGMutablePath()
            line.move(to: .zero)
            line.addQuadCurve(to: end, control: CGPoint(x: end.x * 0.2, y: end.y * 0.6))
            stem.addSublayer(strokeLayer(line, stem.bounds.size, hex("#7A4A32"), 0.9).moved(to: stem.bounds))
            let plume = almond(CGPoint(x: end.x * 0.92, y: end.y * 0.82), length: tall * 0.5, width: tall * 0.16, angle: CGFloat(lean))
            stem.addSublayer(fillLayer(plume, stem.bounds.size, hex("#D8B98E")).moved(to: stem.bounds))
            if let sway { animate(stem, "transform.rotation.z", [-sway.0, sway.0, -sway.0], period: sway.1, offset: Double(i) / 3) }
            out.append(stem)
        }
        return out
    }

    // MARK: Folk reindeer

    /// One bold reindeer in the Scandinavian folk style: paper body with red dots and a gold
    /// zigzag, gold antlers, a red nose. Trots while it works, jumps when it needs you, grazes idle.
    func folkDeer(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 113)
        let paper = Ink.paper, red = Ink.red, gold = Ink.mustard
        let mr = h * 0.09
        out.append(fillLayer(CGPath(ellipseIn: CGRect(x: w * 0.52 - mr, y: h * 0.2 - mr, width: 2 * mr, height: 2 * mr), transform: nil),
                             size, paper))
        out.append(contentsOf: snowfall(size, rate: state == .waiting ? 1.6 : state == .idle ? 0.3 : 0.7, wind: state == .working ? 10 : 2,
                                        rng: &rng))
        let gy = h * 0.9
        // Trees passing behind, on a strip two widths wide so it can loop.
        let scenery = CALayer()
        scenery.frame = CGRect(x: 0, y: 0, width: w * 2, height: h)
        let trees = CGMutablePath()
        var x: CGFloat = 0
        var spots: [CGFloat] = []
        while x < w { spots.append(x); x += h * (0.22 + 0.2 * CGFloat(rng.next())) }
        for base in [0, w] {
            for (i, sx) in spots.enumerated() {
                let tall = h * (0.18 + 0.06 * CGFloat(i % 3))
                trees.addLines(between: [CGPoint(x: base + sx, y: gy - tall), CGPoint(x: base + sx + tall * 0.3, y: gy), CGPoint(x: base + sx - tall * 0.3, y: gy)])
                trees.closeSubpath()
            }
        }
        scenery.addSublayer(fillLayer(trees, CGSize(width: w * 2, height: h), Ink.teal))
        if state == .working { animate(scenery, "transform.translation.x", [0, -Double(w)], period: 7, linear: true) }
        out.append(scenery)
        out.append(fillLayer(CGPath(rect: CGRect(x: 0, y: gy - 1, width: w, height: h - gy + 2), transform: nil), size, paper))

        let s = h * 0.7, bx = w * 0.76
        let deer = CALayer()
        deer.bounds = CGRect(origin: .zero, size: size)
        deer.position = CGPoint(x: w / 2, y: h / 2)
        // Legs, each turning at the hip.
        let hipY = gy - s * 0.4
        for (i, dx) in [-0.2, -0.1, 0.12, 0.22].enumerated() {
            let hip = CGPoint(x: bx + CGFloat(dx) * s, y: hipY)
            let leg = CALayer()
            leg.bounds = CGRect(origin: .zero, size: size)
            leg.anchorPoint = CGPoint(x: hip.x / w, y: hip.y / h)
            leg.position = hip
            let line = CGMutablePath()
            line.move(to: hip)
            line.addLine(to: CGPoint(x: hip.x, y: gy - 1))
            let stroke = strokeLayer(line, size, paper, s * 0.065)
            stroke.lineCap = .round
            leg.addSublayer(stroke)
            switch state {
            case .working: animate(leg, "transform.rotation.z", [-0.35, 0.35, -0.35], period: 0.5, offset: i % 2 == 0 ? 0 : 0.5)
            case .waiting: animate(leg, "transform.rotation.z", [0, i < 2 ? 0.6 : -0.6, 0], period: 0.7)
            default: break
            }
            deer.addSublayer(leg)
        }
        let bodyCenter = CGPoint(x: bx, y: gy - s * 0.5)
        deer.addSublayer(fillLayer(CGPath(ellipseIn: CGRect(x: bodyCenter.x - s * 0.32, y: bodyCenter.y - s * 0.13, width: s * 0.66, height: s * 0.3),
                                          transform: nil), size, paper))
        deer.addSublayer(fillLayer(almond(CGPoint(x: bx + s * 0.33, y: gy - s * 0.6), length: s * 0.12, width: s * 0.05, angle: 0.9), size, paper))
        // Folk decoration on the flank.
        let dots = CGMutablePath()
        for k in 0..<5 {
            let dx = (CGFloat(k) - 2) * s * 0.1
            dots.addEllipse(in: CGRect(x: bx + dx - s * 0.025, y: bodyCenter.y - s * 0.05, width: s * 0.05, height: s * 0.05))
        }
        deer.addSublayer(fillLayer(dots, size, red))
        let zig = CGMutablePath()
        zig.addLines(between: (0...10).map { k in
            CGPoint(x: bx - s * 0.22 + CGFloat(k) * s * 0.044, y: bodyCenter.y + s * (k % 2 == 0 ? 0.04 : 0.075))
        })
        deer.addSublayer(strokeLayer(zig, size, gold, max(0.8, s * 0.018)))
        // Neck and head, bending at the shoulder.
        let shoulder = CGPoint(x: bx - s * 0.22, y: gy - s * 0.55)
        let head = CALayer()
        head.bounds = CGRect(origin: .zero, size: size)
        head.anchorPoint = CGPoint(x: shoulder.x / w, y: shoulder.y / h)
        head.position = shoulder
        let neck = CGMutablePath()
        neck.move(to: shoulder)
        neck.addLine(to: CGPoint(x: bx - s * 0.33, y: gy - s * 0.78))
        let neckLayer = strokeLayer(neck, size, paper, s * 0.12)
        neckLayer.lineCap = .round
        head.addSublayer(neckLayer)
        let antlers = CGMutablePath()
        for (k, ox) in [0.0, 0.07].enumerated() {
            let root = CGPoint(x: bx - s * (0.33 - CGFloat(ox)), y: gy - s * 0.86)
            let tip = CGPoint(x: root.x + s * 0.16, y: root.y - s * 0.3)
            antlers.move(to: root)
            antlers.addQuadCurve(to: tip, control: CGPoint(x: root.x - s * 0.04, y: root.y - s * 0.22))
            for j in 1...3 {
                let t = CGFloat(j) / 4
                let p = CGPoint(x: root.x + (tip.x - root.x) * t * t - s * 0.02 * (1 - t), y: root.y + (tip.y - root.y) * t)
                antlers.move(to: p)
                antlers.addLine(to: CGPoint(x: p.x - s * (k == 0 ? 0.08 : 0.06), y: p.y - s * 0.08))
            }
        }
        let antlerLayer = strokeLayer(antlers, size, gold, max(1, s * 0.03))
        antlerLayer.lineCap = .round
        head.addSublayer(antlerLayer)
        head.addSublayer(fillLayer(almond(CGPoint(x: bx - s * 0.41, y: gy - s * 0.8), length: s * 0.24, width: s * 0.08, angle: .pi / 2 - 0.25),
                                   size, paper))
        head.addSublayer(fillLayer(almond(CGPoint(x: bx - s * 0.27, y: gy - s * 0.87), length: s * 0.1, width: s * 0.035, angle: 1.1), size, paper))
        head.addSublayer(fillLayer(CGPath(ellipseIn: CGRect(x: bx - s * 0.42, y: gy - s * 0.845, width: s * 0.03, height: s * 0.03), transform: nil),
                                   size, Ink.navy))
        let nose = fillLayer(CGPath(ellipseIn: CGRect(x: bx - s * 0.56, y: gy - s * 0.8, width: s * 0.07, height: s * 0.07), transform: nil), size, red)
        switch state {
        case .waiting: step(nose, "fillColor", [red.cgColor, gold.cgColor], period: 0.4)
        case .ready: step(nose, "fillColor", [red.cgColor, red.cgColor, gold.cgColor], period: 1.6)
        default: break
        }
        head.addSublayer(nose)
        switch state {
        case .idle: head.setAffineTransform(CGAffineTransform(rotationAngle: -0.75))
        case .working: animate(head, "transform.rotation.z", [0, -0.05, 0], period: 0.5)
        default: break
        }
        deer.addSublayer(head)
        switch state {
        case .working: animate(deer, "transform.translation.y", [0, -1.5, 0], period: 0.25)
        case .waiting: animate(deer, "transform.translation.y", [0, -Double(h) * 0.12, 0], period: 0.7)
        case .ready: animate(deer, "transform.translation.y", [0, 0, -Double(h) * 0.05, 0], times: [0, 0.7, 0.85, 1], period: 2.4)
        case .idle: break
        }
        out.append(deer)
        return out
    }
}
