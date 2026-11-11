import AppKit
import QuartzCore

// Two hand-made mascots: a pixel-art hamster that flips between two frames like an old-web GIF,
// and a goldfish bowl drawn badly in crayon, its lines "boiling" between two takes the way a
// hand-drawn cartoon does. Same 64×48 design space as Mascot.swift, y down.

extension MascotArt {
    // MARK: Pixel hamster

    /// 32×24 big pixels, 2 points each.
    private static let pixelPalette: [Character: String] = [
        "o": "#3B2414", "f": "#E0913F", "d": "#B86A26", "l": "#FFE6C4", "p": "#F59AB0",
        "k": "#1A0F08", "w": "#FFFFFF", "g": "#7E8B9C", "h": "#C3CCD8", "c": "#DFF3FF",
        "b": "#4FB3F0", "G": "#49B04F", "r": "#E8344E", "y": "#E9CE95", "Y": "#CFAE6E",
    ]

    /// Facing you, standing up.
    private static let front = [
        "...ooo........ooo...",
        "..oppo........oppo..",
        "..opoooooooooooopo..",
        ".offffffffffffffffo.",
        ".offfwkffffffwkfffo.",
        ".offfkkffffffkkfffo.",
        ".ofllllffppffllllfo.",
        ".offffffkffkffffffo.",
        "..offffffkkffffffo..",
        "...oooffffffffooo...",
        "..offllllllllllffo..",
        ".offllllllllllllffo.",
        ".offllllllllllllffo.",
        ".offllllllllllllffo.",
        "..offllllllllllffo..",
        "...oppoooooooooppo..",
    ]

    /// Curled up asleep, facing left.
    private static let loaf = [
        "....oo................",
        "...oppoooooooo........",
        "..offfffffffffffoo....",
        ".offfffffffffffffffo..",
        ".offffffffffffffffffo.",
        "offkkffffffffffffffffo",
        "offffffffffffffffffffo",
        "oppfllllllffffffffffo.",
        ".ofllllllffffffffffo..",
        "..oollloooooooooooo...",
    ]

    /// Side on, facing right; legs come separately.
    private static let side = [
        "..........oo....",
        "....ooooooppo...",
        "..ooffffffffffo.",
        ".offffffffffkffo",
        "offffffffffffffp",
        "ofllllllllffffo.",
        ".ollllllllfffo..",
        "..ooooooooooo...",
    ]

    private static let paw = [".oo.", "oppo", "oppo", "offo", "offo"]
    private static let bottle = [
        ".oooooo.", ".oGGGGo.", "oooooooo", "owccccco", "owccccco", "owbbbbbo",
        "owbbbbbo", "owbbbbbo", "owbbbbbo", "owbbbbbo", "oooooooo", "...oo...", "...gg...", "...gg...",
    ]
    private static let smallZ = ["zzzz", "..zz", "zz..", "zzzz"]
    private static let bigZ = ["zzzzz", "...zz", "..z..", "zz...", "zzzzz"]
    private static let heart = [".r.r.", "rrrrr", ".rrr.", "..r.."]
    private static let bang = ["r", "r", "r", ".", "r"]

    func pixelHamster() -> [CALayer] {
        var a = PixelGrid(), b = PixelGrid()
        a.bedding(); b.bedding()
        switch state {
        case .idle:
            // Breathing: the back rises a pixel; the z's take turns.
            a.stamp(Self.loaf, 3, 12)
            b.stamp(Array(Self.loaf[0..<3] + [Self.loaf[3]] + Self.loaf[3...]), 3, 11)
            a.stamp(Self.smallZ, 26, 9)
            b.stamp(Self.smallZ, 25, 10)
            b.stamp(Self.bigZ, 26, 3)
            return flipbook(a, b, period: 1.6)
        case .waiting:
            // Paws up on the glass, one then the other, a "!" flashing.
            for g in [0, 1] {
                var grid = g == 0 ? a : b
                grid.stamp(Self.front, 6, 6)
                grid.stamp(Self.paw, 3, g == 0 ? 9 : 14)
                grid.stamp(Self.paw, 25, g == 0 ? 14 : 9)
                if g == 0 { grid.stamp(Self.bang, 29, 1) }
                if g == 0 { a = grid } else { b = grid }
            }
            return flipbook(a, b, period: 0.5)
        case .working:
            // In the wheel: the spokes tick round and the legs scramble.
            for g in [0, 1] {
                var grid = g == 0 ? a : b
                grid.line(16, 12, 10, 23, "g")
                grid.line(16, 12, 22, 23, "g")
                grid.wheel(cx: 16, cy: 11.5, r: 11, turn: g == 0 ? 0 : .pi / 6)
                grid.stamp(Self.side, 8, 12)
                grid.stamp(g == 0 ? ["..oo.....oo.....", ".oo.......oo...."] : ["....oo.oo.......", "....oo.oo......."], 8, 20)
                for (y, len) in [(14, 3), (16, 2), (18, 3)] {
                    for x in 0..<(g == 0 ? len : len - 1) { grid.set(x + 1, y, "z") }
                }
                if g == 0 { a = grid } else { b = grid }
            }
            return flipbook(a, b, period: 0.36)
        case .ready:
            // Stretching up to the bottle, bubbles going up inside it, a heart.
            for g in [0, 1] {
                var grid = g == 0 ? a : b
                grid.stamp(Self.side, 10, g == 0 ? 12 : 11)
                grid.stamp(["...oo....oo.....", "...oo....oo....."], 10, 20)
                if g == 1 { grid.set(13, 19, "o"); grid.set(14, 19, "o"); grid.set(19, 19, "o"); grid.set(20, 19, "o") }
                grid.stamp(Self.bottle, 22, 1)
                for (x, y) in g == 0 ? [(25, 9), (27, 7)] : [(24, 7), (26, 5)] { grid.set(x, y, "w") }
                if g == 1 { grid.set(24, 16, "b") }
                grid.stamp(Self.heart, g == 0 ? 3 : 4, g == 0 ? 5 : 3)
                if g == 0 { a = grid } else { b = grid }
            }
            return flipbook(a, b, period: 0.9)
        }
    }

    /// Two frames flipping, GIF style. Holding still shows the first.
    private func flipbook(_ a: PixelGrid, _ b: PixelGrid, period: Double) -> [CALayer] {
        let first = render(a), second = render(b)
        second.opacity = 0
        animate(first, "opacity", [1, 0], times: [0, 0.5, 1], period: period, discrete: true)
        animate(second, "opacity", [0, 1], times: [0, 0.5, 1], period: period, discrete: true)
        return [first, second]
    }

    /// One shape layer per color, each a union of row runs, so pixels meet without seams.
    private func render(_ grid: PixelGrid) -> CALayer {
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
            let color = ch == "z" ? ink : Self.pixelPalette[ch].flatMap(NSColor.init(hex:)) ?? ink
            frame.addSublayer(shape(path, fill: color))
        }
        return frame
    }

    // MARK: Crayon fishbowl

    private enum Paint {
        static let black = NSColor(hex: "#000000")!, orange = NSColor(hex: "#FF7F27")!
        static let water = NSColor(hex: "#99D9EA")!, blue = NSColor(hex: "#3F48CC")!
        static let green = NSColor(hex: "#22B14C")!, yellow = NSColor(hex: "#FFC90E")!
        static let red = NSColor(hex: "#ED1C24")!, purple = NSColor(hex: "#A349A4")!
    }

    private enum FishFace { case open, shut, happy, gasp }

    func fishbowl() -> [CALayer] {
        // Two takes of the same drawing, swapped a few times a second: the lines "boil".
        let takes = [scene(seed: 7), scene(seed: 31)]
        takes[1].opacity = 0
        animate(takes[0], "opacity", [1, 0], times: [0, 0.5, 1], period: 0.36, discrete: true)
        animate(takes[1], "opacity", [0, 1], times: [0, 0.5, 1], period: 0.36, discrete: true)
        return takes
    }

    private func scene(seed: UInt64) -> CALayer {
        var rng = Scribble(seed)
        let take = CALayer()
        take.frame = CGRect(origin: .zero, size: Self.canvas)
        let add = { (layers: [CALayer]) in layers.forEach(take.addSublayer) }
        let c = CGPoint(x: 32, y: 27), r: CGFloat = 19, surface: CGFloat = 14

        add(crayon(wobblyLine([CGPoint(x: 4, y: 46.6), CGPoint(x: 60, y: 46.2)], &rng), Paint.black, width: 1.1))
        // Water, scribbled in and going over the lines a bit.
        let fill = scribble(top: surface + 0.8, bottom: c.y + r - 0.8, step: 1.5, &rng) { y in
            let dy = y - c.y
            guard abs(dy) < r else { return nil }
            let w = (r * r - dy * dy).squareRoot() - 1
            return (c.x - w, c.x + w)
        }
        add([shape(fill, fill: nil, stroke: Paint.water.withAlphaComponent(0.85), width: 1.8)])
        for (i, x) in stride(from: 21.0, through: 43.0, by: 3.1).enumerated() {
            let color = [Paint.yellow, Paint.purple, Paint.red, Paint.green][i % 4]
            add([shape(wobblyOval(CGPoint(x: x, y: 43.2 - Double(i % 2) * 0.9), 1.6, 1.3, &rng), fill: color)])
        }
        let weed = group(pivot: CGPoint(x: 24, y: 43))
        for blade in [[CGPoint(x: 24, y: 43.5), CGPoint(x: 22, y: 38), CGPoint(x: 25, y: 33), CGPoint(x: 22.5, y: 28)],
                      [CGPoint(x: 26, y: 43.5), CGPoint(x: 28.5, y: 38), CGPoint(x: 26.5, y: 33.5)]] {
            crayon(wobblyLine(blade, &rng), Paint.green, width: 1.8).forEach(weed.addSublayer)
        }
        animate(weed, "transform.rotation.z", [-0.07, 0.07, -0.07], period: 3.2)
        add([weed])

        switch state {
        case .idle:
            let fish = crayonFish(30, 38, .shut, &rng)
            animate(fish, "transform.translation.y", [0, -1, 0], period: 3.2)
            add([fish])
            add(crayonBubbles([CGPoint(x: 37, y: 35)], to: surface + 2, period: 3.4, &rng))
            add(zees(at: CGPoint(x: 46, y: 9), color: Paint.black))
        case .working:
            let lane = group(pivot: CGPoint(x: 32, y: 28))
            let fish = crayonFish(32, 28, .open, &rng)
            animate(fish, "transform.scale.x", [1, -1], times: [0, 0.5, 1], period: 4.4, discrete: true)
            animate(fish, "transform.rotation.z", [-0.05, 0.05, -0.05], period: 0.4)
            lane.addSublayer(fish)
            animate(lane, "transform.translation.x", [-7, 7, -7], period: 4.4)
            add([lane])
            add(crayonBubbles([CGPoint(x: 28, y: 30), CGPoint(x: 36, y: 31)], to: surface + 2, period: 2.2, &rng))
        case .waiting:
            let fish = crayonFish(36, 26, .gasp, &rng)
            animate(fish, "transform.rotation.z", [-0.12, 0.12, -0.12], period: 0.3)
            add([fish])
            add(crayonBubbles([CGPoint(x: 43.5, y: 26), CGPoint(x: 43, y: 26), CGPoint(x: 44, y: 26)], to: surface + 2, period: 1, &rng))
            add([emphasis(at: [(53, 9, 57, 5), (55, 14, 60, 13)])])
        case .ready:
            let fish = crayonFish(31, 20, .happy, &rng)
            fish.setAffineTransform(CGAffineTransform(rotationAngle: -0.3))
            animate(fish, "transform.translation.y", [0, -1.2, 0], period: 0.7)
            add([fish])
            for (i, x) in [26.0, 30.5, 35.0, 38.0].enumerated() {
                let flake = group(pivot: CGPoint(x: x, y: 9))
                flake.addSublayer(shape(wobblyOval(CGPoint(x: x, y: 9), 1.2, 0.8, &rng), fill: i % 2 == 0 ? Paint.red : Paint.yellow))
                animate(flake, "transform.translation.y", [0, 8], period: 2, offset: Double(i) / 4, linear: true)
                animate(flake, "opacity", [1, 1, 0], times: [0, 0.75, 1], period: 2, offset: Double(i) / 4)
                add([flake])
            }
        }

        // The bowl over everything: one wobbly loop, a rim, the waterline.
        add(crayon(wobblyOval(c, r, r, &rng, from: -0.95, to: .pi + 0.95), Paint.black, width: 1.4))
        add(crayon(wobblyOval(CGPoint(x: c.x, y: c.y - r * sin(0.95)), r * cos(0.95), 1.7, &rng), Paint.black, width: 1.1))
        let half = (r * r - (c.y - surface) * (c.y - surface)).squareRoot() - 0.5
        add(crayon(wobblyLine([CGPoint(x: c.x - half, y: surface), CGPoint(x: c.x + half, y: surface)], &rng), Paint.blue, width: 1))
        add(crayon(wobblyOval(c, r - 3.5, r - 3.5, &rng, from: 2.35, to: 2.9), .white, width: 1.6))
        return take
    }

    /// A goldfish facing right at (x, y), the way a kid draws one: big eye, scribbled in, over the lines.
    private func crayonFish(_ x: CGFloat, _ y: CGFloat, _ face: FishFace, _ rng: inout Scribble) -> CALayer {
        let fish = group(pivot: CGPoint(x: x, y: y))
        let add = { (layers: [CALayer]) in layers.forEach(fish.addSublayer) }
        let tail = scribble(top: y - 4.5, bottom: y + 4.5, step: 1.3, &rng) { yy in
            let t = 1 - abs(yy - y) / 4.5
            return (x - 10.8, x - 10.8 + 5.8 * t)
        }
        let body = scribble(top: y - 4.4, bottom: y + 4.4, step: 1.3, &rng) { yy in
            let dy = (yy - y) / 4.6
            guard abs(dy) < 1 else { return nil }
            let w = 7 * (1 - dy * dy).squareRoot()
            return (x - w, x + w)
        }
        add([shape(tail, fill: nil, stroke: Paint.orange.withAlphaComponent(0.85), width: 1.7),
             shape(body, fill: nil, stroke: Paint.orange.withAlphaComponent(0.85), width: 1.7)])
        add(crayon(wobblyLine([CGPoint(x: x - 5.8, y: y), CGPoint(x: x - 11, y: y - 4.6), CGPoint(x: x - 10, y: y + 4.6),
                               CGPoint(x: x - 5.6, y: y + 0.6)], &rng), Paint.black))
        add(crayon(wobblyLine([CGPoint(x: x - 3.5, y: y - 4.1), CGPoint(x: x - 1, y: y - 7.2), CGPoint(x: x + 2, y: y - 4.3)], &rng), Paint.black))
        add(crayon(wobblyOval(CGPoint(x: x, y: y), 7, 4.6, &rng), Paint.black))
        let eye = CGPoint(x: x + 3, y: y - 1.3)
        switch face {
        case .open, .gasp:
            add([shape(circle(eye.x, eye.y, 2.5), fill: .white)])
            add(crayon(wobblyOval(eye, 2.5, 2.5, &rng), Paint.black, width: 1))
            add([shape(circle(eye.x + 0.7, eye.y + 0.2, 1.1), fill: Paint.black)])
        case .shut:
            add(crayon(wobblyLine([CGPoint(x: eye.x - 2, y: eye.y), CGPoint(x: eye.x, y: eye.y + 1.3), CGPoint(x: eye.x + 2, y: eye.y)], &rng),
                       Paint.black, width: 1))
        case .happy:
            add(crayon(wobblyLine([CGPoint(x: eye.x - 2, y: eye.y + 1), CGPoint(x: eye.x, y: eye.y - 1.4), CGPoint(x: eye.x + 2, y: eye.y + 1)], &rng),
                       Paint.black, width: 1))
        }
        if face == .gasp {
            add(crayon(wobblyOval(CGPoint(x: x + 6.3, y: y + 1.4), 1.2, 1.3, &rng), Paint.black, width: 0.9))
        } else {
            add(crayon(wobblyLine([CGPoint(x: x + 4.4, y: y + 1.5), CGPoint(x: x + 5.6, y: y + 2.4), CGPoint(x: x + 6.6, y: y + 1.3)], &rng),
                       Paint.black, width: 0.9))
        }
        return fish
    }

    /// Little crayon circles rising from each point to the `to` line, one after another.
    private func crayonBubbles(_ points: [CGPoint], to top: CGFloat, period: Double, _ rng: inout Scribble) -> [CALayer] {
        points.enumerated().map { i, p in
            let bubble = group(pivot: p)
            crayon(wobblyOval(p, 1.1 + 0.3 * CGFloat(i % 2), 1.1 + 0.3 * CGFloat(i % 2), &rng), Paint.blue, width: 0.8)
                .forEach(bubble.addSublayer)
            let shift = Double(i) / Double(points.count)
            animate(bubble, "transform.translation.y", [0, Double(top - p.y)], period: period, offset: shift, linear: true)
            animate(bubble, "opacity", [0, 1, 1, 0], times: [0, 0.1, 0.85, 1], period: period, offset: shift)
            return bubble
        }
    }

    /// A crayon line: a solid pass and a broken, slightly offset one for the waxy texture.
    private func crayon(_ path: CGPath, _ color: NSColor, width: CGFloat = 1.3) -> [CALayer] {
        let solid = shape(path, fill: nil, stroke: color.withAlphaComponent(0.9), width: width)
        let wax = shape(path, fill: nil, stroke: color.withAlphaComponent(0.5), width: width * 0.6)
        wax.lineDashPattern = [1.4, 0.8]
        wax.setAffineTransform(CGAffineTransform(translationX: 0.35, y: 0.3))
        return [solid, wax]
    }

    /// Back-and-forth strokes filling the band `span(y)` gives at each height, overshooting its ends.
    private func scribble(top: CGFloat, bottom: CGFloat, step: CGFloat, _ rng: inout Scribble,
                          span: (CGFloat) -> (CGFloat, CGFloat)?) -> CGPath {
        let p = CGMutablePath()
        var y = top, left = true, started = false
        while y <= bottom {
            if let (a, b) = span(y) {
                let pt = CGPoint(x: (left ? a : b) + rng.jitter(1.2), y: y + rng.jitter(0.4))
                if started { p.addLine(to: pt) } else { p.move(to: pt); started = true }
                left.toggle()
            }
            y += step
        }
        return p
    }

    /// An oval traced by an unsteady hand; by default it overshoots where it started.
    private func wobblyOval(_ c: CGPoint, _ rx: CGFloat, _ ry: CGFloat, _ rng: inout Scribble,
                            from: CGFloat = 0, to: CGFloat = 2 * .pi + 0.45) -> CGPath {
        let steps = max(6, Int((to - from) / 0.35))
        let points = (0...steps).map { i -> CGPoint in
            let t = from + (to - from) * CGFloat(i) / CGFloat(steps)
            let wobble = 1 + rng.jitter(0.07)
            return CGPoint(x: c.x + rx * wobble * cos(t), y: c.y + ry * wobble * sin(t))
        }
        return smooth(points)
    }

    /// A polyline through `points`, broken into short shaky pieces.
    private func wobblyLine(_ points: [CGPoint], _ rng: inout Scribble) -> CGPath {
        var shaky: [CGPoint] = [points[0]]
        for (a, b) in zip(points, points.dropFirst()) {
            let pieces = max(1, Int((hypot(b.x - a.x, b.y - a.y) / 3).rounded()))
            for i in 1...pieces {
                let t = CGFloat(i) / CGFloat(pieces)
                let end = i == pieces
                shaky.append(CGPoint(x: a.x + (b.x - a.x) * t + (end ? 0 : rng.jitter(0.45)),
                                     y: a.y + (b.y - a.y) * t + (end ? 0 : rng.jitter(0.45))))
            }
        }
        return smooth(shaky)
    }

    /// Curves through the midpoints of `points`, from the first to the last.
    private func smooth(_ points: [CGPoint]) -> CGPath {
        let p = CGMutablePath()
        p.move(to: points[0])
        for i in 1..<max(1, points.count - 1) {
            let mid = CGPoint(x: (points[i].x + points[i + 1].x) / 2, y: (points[i].y + points[i + 1].y) / 2)
            p.addQuadCurve(to: mid, control: points[i])
        }
        p.addLine(to: points[points.count - 1])
        return p
    }
}

/// A frame of the pixel hamster: characters standing for palette colors, "." for nothing.
struct PixelGrid {
    static let cols = 32, rows = 24
    var cells = [[Character]](repeating: [Character](repeating: ".", count: cols), count: rows)

    mutating func set(_ x: Int, _ y: Int, _ ch: Character) {
        guard (0..<Self.cols).contains(x), (0..<Self.rows).contains(y) else { return }
        cells[y][x] = ch
    }

    mutating func stamp(_ sprite: [String], _ col: Int, _ row: Int) {
        for (r, line) in sprite.enumerated() {
            for (c, ch) in line.enumerated() where ch != "." { set(col + c, row + r, ch) }
        }
    }

    mutating func line(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int, _ ch: Character) {
        let steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in 0...steps {
            let t = Double(i) / Double(max(1, steps))
            set(Int((Double(x0) + Double(x1 - x0) * t).rounded()), Int((Double(y0) + Double(y1 - y0) * t).rounded()), ch)
        }
    }

    /// A rim and three spokes through the hub, turned by `turn`.
    mutating func wheel(cx: Double, cy: Double, r: Double, turn: Double) {
        for y in 0..<Self.rows {
            for x in 0..<Self.cols {
                let dx = Double(x) + 0.5 - cx, dy = Double(y) + 0.5 - cy
                let d = (dx * dx + dy * dy).squareRoot()
                if abs(d - r) < 0.7 { cells[y][x] = "g"; continue }
                guard d < r - 0.6 else { continue }
                for k in 0..<3 {
                    let a = turn + Double(k) * .pi / 3
                    if abs(dx * sin(a) - dy * cos(a)) < 0.5 { cells[y][x] = "h"; break }
                }
            }
        }
        set(Int(cx), Int(cy), "g")
    }

    /// Wood shavings along the bottom.
    mutating func bedding() {
        for x in 0..<Self.cols {
            set(x, Self.rows - 1, x % 3 == 0 ? "Y" : "y")
            if x % 5 == 1 || x % 7 == 3 { set(x, Self.rows - 2, x % 2 == 0 ? "Y" : "y") }
        }
    }
}

/// A seeded random source, so each crayon take is the same every rebuild.
struct Scribble {
    private var state: UInt64
    init(_ seed: UInt64) { state = seed }

    mutating func next() -> Double {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        z ^= z >> 31
        return Double(z >> 11) / Double(1 << 53)
    }

    /// A random amount in ±`amount`.
    mutating func jitter(_ amount: CGFloat) -> CGFloat { CGFloat(next() * 2 - 1) * amount }
}
