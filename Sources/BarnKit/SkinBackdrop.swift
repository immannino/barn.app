import AppKit
import QuartzCore
import SwiftUI

/// A skin's backdrop: an animated scene filling the whole card behind its text (deep space, a
/// synthwave horizon, brass gears, a stained-glass window). Built in Core Animation for the card's
/// size and state, rebuilt only when those change, so the window server plays it; with Reduce
/// Motion it holds still.
struct BackdropView: NSViewRepresentable {
    var kind: Skin.Backdrop
    var state: AgentState
    var accent: NSColor
    var speed: Double
    /// The card's outline, to clip to.
    var clip: (CGRect) -> CGPath
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> BackdropLayerView { BackdropLayerView() }
    func updateNSView(_ view: BackdropLayerView, context: Context) {
        view.clip = clip
        view.configure(BackdropArt(kind: kind, state: state, accent: accent, speed: speed, still: reduceMotion))
    }
}

final class BackdropLayerView: NSView {
    var clip: ((CGRect) -> CGPath)?
    private var art: BackdropArt?
    private var built: (art: BackdropArt, size: CGSize)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(_ art: BackdropArt) {
        self.art = art
        rebuild()
    }

    override func layout() {
        super.layout()
        rebuild()
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        rebuild(force: true)
    }

    private func rebuild(force: Bool = false) {
        guard let art, let root = layer, window != nil, bounds.width > 0, bounds.height > 0 else { return }
        if !force, let built, built.art == art, built.size == bounds.size { return }
        built = (art, bounds.size)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.sublayers?.forEach { $0.removeFromSuperlayer() }
        let mask = CAShapeLayer()
        mask.path = clip?(bounds) ?? CGPath(rect: bounds, transform: nil)
        root.mask = mask
        art.layers(in: bounds.size).forEach(root.addSublayer)
        CATransaction.commit()
    }
}

struct BackdropArt: Equatable {
    var kind: Skin.Backdrop
    var state: AgentState
    var accent: NSColor
    var speed: Double
    var still: Bool

    func layers(in size: CGSize) -> [CALayer] {
        switch kind {
        case .none: []
        case .galaxy: galaxy(size)
        case .synthwave: horizon(size, pastel: false)
        case .vaporwave: horizon(size, pastel: true)
        case .vectorGreen: vectorHorizon(size, phosphor: NSColor(hex: "#39FF6A")!)
        case .vectorBlue: vectorHorizon(size, phosphor: NSColor(hex: "#3FB4FF")!)
        case .steampunk: steampunk(size)
        case .gothic: gothic(size)
        case .leaves: leaves(size)
        case .harvest: harvest(size)
        case .snow: snow(size)
        case .candyCane: candyCane(size)
        case .lights: lights(size)
        case .santa: santa(size)
        case .sleigh: sleigh(size)
        case .menorah: menorah(size)
        case .atomic: atomic(size)
        case .tiles: tiles(size)
        case .colorCycle: colorCycle(size)
        case .plate: plate(size)
        case .tarot: tarot(size)
        case .seurat: seurat(size)
        case .enso: enso(size)
        case .whale: whale(size)
        case .harbor: harbor(size)
        case .boho: boho(size)
        case .reindeer: folkDeer(size)
        }
    }

    // MARK: Galaxy

    private func galaxy(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w * 7 + h))
        let (hue, sat) = hueAndSaturation(accent)
        let calm = state == .idle
        // Nebula: three soft clouds in the state's hue and its neighbors, drifting and breathing.
        for (i, shift) in [0.0, 0.1, -0.12].enumerated() {
            let c = NSColor(hue: (hue + shift + 1).truncatingRemainder(dividingBy: 1), saturation: max(0.5, sat * 0.9),
                            brightness: 1, alpha: 1).cgColor
            let cloud = CAGradientLayer()
            cloud.type = .radial
            let strength: Double = calm ? 0.16 : 0.34
            cloud.colors = [c.copy(alpha: strength)!, c.copy(alpha: strength * 0.35)!, c.copy(alpha: 0)!]
            cloud.locations = [0, 0.5, 1]
            cloud.startPoint = CGPoint(x: 0.5, y: 0.5)
            cloud.endPoint = CGPoint(x: 1, y: 1)
            cloud.bounds = CGRect(x: 0, y: 0, width: w * (0.8 + 0.25 * Double(i)), height: h * (1.1 + 0.3 * Double(i % 2)))
            let p = CGPoint(x: w * [0.72, 0.3, 0.55][i], y: h * [0.35, 0.7, 0.15][i])
            cloud.position = p
            cloud.setAffineTransform(CGAffineTransform(rotationAngle: [0.4, -0.3, 0.9][i]))
            let period = 24.0 + 8 * Double(i)
            let dx: CGFloat = w * 0.08, dy: CGFloat = h * 0.1, phase: Double = Double(i) * 2
            var orbit: [NSValue] = []
            for k in 0...24 {
                let t: Double = 2 * Double.pi * Double(k) / 24 + phase
                orbit.append(NSValue(point: NSPoint(x: p.x + dx * CGFloat(sin(t)), y: p.y + dy * CGFloat(cos(t)))))
            }
            animate(cloud, "position", orbit, period: period, linear: true)
            if state == .waiting {
                animate(cloud, "opacity", [0.55, 1, 0.55], period: 1.6)
            } else {
                animate(cloud, "transform.scale", [1, 1.12, 1], period: period * 0.6)
            }
            out.append(cloud)
        }
        // Stars in three depths, each sliding left at its own pace (seamlessly: two copies).
        let pace: Double = switch state {
        case .working: 1
        case .waiting: 0.6
        case .ready: 0.45
        case .idle: 0.15
        }
        for (depth, layer) in [(r: 0.35, alpha: 0.45, count: 0.012, period: 140.0),
                               (r: 0.55, alpha: 0.7, count: 0.006, period: 80.0),
                               (r: 0.85, alpha: 0.95, count: 0.0025, period: 45.0)].enumerated() {
            let path = CGMutablePath()
            for _ in 0..<max(4, Int(w * h * layer.count)) {
                let x = CGFloat(rng.next()) * w, y = CGFloat(rng.next()) * h
                let r = layer.r * (0.7 + 0.6 * CGFloat(rng.next()))
                for copy in [0, w] { path.addEllipse(in: CGRect(x: x + copy - r, y: y - r, width: 2 * r, height: 2 * r)) }
            }
            let stars = CAShapeLayer()
            stars.frame = CGRect(x: 0, y: 0, width: 2 * w, height: h)
            stars.path = path
            stars.fillColor = NSColor(red: 0.88, green: 0.93, blue: 1, alpha: layer.alpha).cgColor
            if depth == 2 {
                stars.shadowColor = NSColor.white.cgColor
                stars.shadowOffset = .zero
                stars.shadowRadius = 1.2
                stars.shadowOpacity = 0.8
            }
            animate(stars, "transform.translation.x", [0, -Double(w)], period: layer.period / pace, linear: true)
            out.append(stars)
        }
        // A few bright stars that glint.
        for i in 0..<4 {
            let x = CGFloat(rng.next()) * w, y = CGFloat(rng.next()) * h * 0.8
            let glint = CAShapeLayer()
            glint.frame = CGRect(x: x - 6, y: y - 6, width: 12, height: 12)
            glint.path = sparkle(CGPoint(x: 6, y: 6), 5)
            glint.fillColor = NSColor.white.cgColor
            glint.shadowColor = NSColor.white.cgColor
            glint.shadowOffset = .zero
            glint.shadowRadius = 2
            glint.shadowOpacity = 1
            glint.setAffineTransform(CGAffineTransform(scaleX: 0.5, y: 0.5))
            animate(glint, "transform.scale", [0.25, 1, 0.25, 0.25], times: [0, 0.15, 0.3, 1], period: 3.6 + Double(i), offset: Double(i) / 4)
            out.append(glint)
        }
        // Done: a shooting star now and then.
        if state == .ready {
            let streak = CAShapeLayer()
            streak.frame = CGRect(origin: .zero, size: size)
            let p = CGMutablePath()
            p.move(to: CGPoint(x: w * 0.15, y: h * 0.12))
            p.addLine(to: CGPoint(x: w * 0.75, y: h * 0.5))
            streak.path = p
            streak.strokeColor = NSColor.white.cgColor
            streak.lineWidth = 1.2
            streak.lineCap = .round
            streak.shadowColor = NSColor.white.cgColor
            streak.shadowOffset = .zero
            streak.shadowRadius = 2
            streak.shadowOpacity = 1
            streak.strokeStart = 1
            animate(streak, "strokeEnd", [0, 1, 1, 1], times: [0, 0.12, 0.2, 1], period: 6)
            animate(streak, "strokeStart", [0, 0.1, 1, 1], times: [0, 0.12, 0.2, 1], period: 6)
            out.append(streak)
        }
        return out
    }

    // MARK: Horizon

    private func horizon(_ size: CGSize, pastel: Bool) -> [CALayer] {
        let w = size.width, h = size.height
        let sunTop = NSColor(hex: pastel ? "#FFF3B0" : "#FFE14D")!, sunBottom = NSColor(hex: pastel ? "#FF8ED4" : "#FF2BD6")!
        let gridColor = NSColor(hex: pastel ? "#7FF3FF" : "#FF3FD8")!
        let floorTop = NSColor(hex: pastel ? "#6A3FB0" : "#2A0050")!, floorBottom = NSColor(hex: pastel ? "#3B1F6B" : "#0A0018")!
        let backRidge = NSColor(hex: pastel ? "#C9A0FF" : "#3B1070")!, frontRidge = NSColor(hex: pastel ? "#9E6BE8" : "#22053F")!
        let horizonY = (h * 0.56).rounded()
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w) + 3)

        for i in 0..<max(6, Int(w / 18)) {
            let star = CAShapeLayer()
            star.frame = CGRect(origin: .zero, size: size)
            let x = CGFloat(rng.next()) * w, y = CGFloat(rng.next()) * horizonY * 0.75, r = 0.4 + CGFloat(rng.next()) * 0.5
            star.path = CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r), transform: nil)
            star.fillColor = NSColor.white.cgColor
            animate(star, "opacity", [0.25, 1, 0.25], period: 2 + Double(i % 5) * 0.4, offset: Double(i) / 7)
            out.append(star)
        }

        // The sun, cut by bars that thicken toward the horizon; set when idle, pulsing when it needs you.
        let r = min(h * 0.36, w * 0.2)
        let sunCenter = CGPoint(x: w * 0.7, y: state == .idle ? horizonY + r * 0.3 : horizonY - r * 0.42)
        let sun = CALayer()
        sun.frame = CGRect(x: sunCenter.x - r, y: sunCenter.y - r, width: 2 * r, height: 2 * r)
        let disc = CAGradientLayer()
        disc.frame = sun.bounds
        disc.colors = [sunTop.cgColor, sunBottom.cgColor]
        let cut = CGMutablePath()
        cut.addEllipse(in: sun.bounds)
        for k in 0..<5 {
            let y = r * (1.05 + 0.17 * CGFloat(k)), band = r * (0.03 + 0.025 * CGFloat(k))
            let dy = max(abs(y - r), abs(y + band - r))
            let half = max(0, r * r - dy * dy).squareRoot()
            cut.addRect(CGRect(x: r - half, y: y, width: 2 * half, height: band))
        }
        let mask = CAShapeLayer()
        mask.frame = sun.bounds
        mask.path = cut
        mask.fillRule = .evenOdd
        disc.mask = mask
        sun.addSublayer(disc)
        sun.shadowColor = (state == .waiting ? accent : sunBottom).cgColor
        sun.shadowOffset = .zero
        sun.shadowRadius = r * 0.45
        sun.shadowOpacity = state == .idle ? 0.35 : 0.9
        if state == .waiting { animate(sun, "shadowOpacity", [0.3, 1, 0.3], period: 1) }
        out.append(sun)

        for (color, base, height, seed) in [(backRidge, horizonY, h * 0.2, UInt64(5)), (frontRidge, horizonY, h * 0.12, UInt64(9))] {
            var ridgeRng = Scribble(seed + UInt64(w))
            let ridge = CGMutablePath()
            ridge.move(to: CGPoint(x: -2, y: base))
            var x: CGFloat = -2
            while x < w + 2 {
                x += w / 10 * (0.6 + CGFloat(ridgeRng.next()) * 0.8)
                ridge.addLine(to: CGPoint(x: x, y: base - height * (0.3 + 0.7 * CGFloat(ridgeRng.next()))))
                x += w / 12 * (0.5 + CGFloat(ridgeRng.next()))
                ridge.addLine(to: CGPoint(x: x, y: base - height * 0.1 * CGFloat(ridgeRng.next())))
            }
            ridge.addLine(to: CGPoint(x: w + 2, y: base))
            ridge.closeSubpath()
            let layer = CAShapeLayer()
            layer.frame = CGRect(origin: .zero, size: size)
            layer.path = ridge
            layer.fillColor = color.cgColor
            layer.strokeColor = gridColor.withAlphaComponent(0.45).cgColor
            layer.lineWidth = 0.6
            layer.lineJoin = .round
            out.append(layer)
        }

        let floor = CAGradientLayer()
        floor.frame = CGRect(x: 0, y: horizonY, width: w, height: h - horizonY)
        floor.colors = [floorTop.cgColor, floorBottom.cgColor]
        out.append(floor)

        // The grid: rays to the vanishing point, and crossbars sliding toward you.
        let grid = CALayer()
        grid.frame = CGRect(origin: .zero, size: size)
        grid.shadowColor = gridColor.cgColor
        grid.shadowOffset = .zero
        grid.shadowRadius = 2
        grid.shadowOpacity = 0.9
        let vanish = w * 0.5, depth = h - horizonY
        let rays = CGMutablePath()
        let spread = w / 6
        for i in -9...9 {
            rays.move(to: CGPoint(x: vanish + CGFloat(i) * spread * 0.1, y: horizonY))
            rays.addLine(to: CGPoint(x: vanish + CGFloat(i) * spread * 1.4, y: h + 2))
        }
        grid.addSublayer(strokeLayer(rays, size, gridColor.withAlphaComponent(0.6), 0.7))
        let line = CGMutablePath()
        line.move(to: CGPoint(x: 0, y: horizonY))
        line.addLine(to: CGPoint(x: w, y: horizonY))
        grid.addSublayer(strokeLayer(line, size, gridColor, 1))
        let period: Double? = switch state {
        case .working: 0.8
        case .waiting: 2
        case .ready: 2.8
        case .idle: nil
        }
        let bars = 8
        for k in 0..<bars {
            let bar = strokeLayer(line, size, gridColor.withAlphaComponent(0.6), 0.8)
            let u = Double(k) / Double(bars)
            bar.setAffineTransform(CGAffineTransform(translationX: 0, y: depth * CGFloat(u * u)))
            if let period {
                animate(bar, "transform.translation.y", (0...16).map { let v = Double($0) / 16; return Double(depth) * v * v },
                        period: period, offset: u, linear: true)
            }
            grid.addSublayer(bar)
        }
        out.append(grid)
        // Haze where the floor meets the sky.
        let haze = CAGradientLayer()
        haze.frame = CGRect(x: 0, y: horizonY - h * 0.06, width: w, height: h * 0.14)
        haze.colors = [gridColor.withAlphaComponent(0).cgColor, gridColor.withAlphaComponent(0.28).cgColor,
                       gridColor.withAlphaComponent(0).cgColor]
        out.append(haze)
        return out
    }

    // MARK: Steampunk

    private func steampunk(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        // A seam and rivets around the plate.
        let seam = CGMutablePath()
        seam.addRect(CGRect(x: 4.5, y: 4.5, width: w - 9, height: h - 9))
        out.append(strokeLayer(seam, size, NSColor(white: 0, alpha: 0.5), 1))
        out.append(strokeLayer(seam.copy(using: [CGAffineTransform(translationX: 0.8, y: 0.8)])!, size, NSColor(white: 1, alpha: 0.06), 0.8))
        var rivets: [CGPoint] = []
        let step: CGFloat = 26
        for x in stride(from: 9, through: w - 9, by: step) { rivets += [CGPoint(x: x, y: 9), CGPoint(x: x, y: h - 9)] }
        out.append(contentsOf: rivetLayers(rivets, radius: 1.6, size: size))
        let behindGears = out.count

        // Two meshing gears at the right, lit from above: the sheen stays put while the teeth turn.
        let R = h * 0.62, r = R / 2, d0 = R * 0.11
        let big = CGPoint(x: w - R * 0.55, y: h * 0.66)
        let toward: CGFloat = 200 * .pi / 180
        let small = CGPoint(x: big.x + (R + r - d0 * 0.9) * cos(toward), y: big.y + (R + r - d0 * 0.9) * sin(toward))
        let turning = state == .working
        let period = 16.0
        out.append(contentsOf: metalGear(at: big, radius: R, teeth: 16, depth: d0, holes: 5, phase: -2.5 * .pi / 180,
                                         spin: turning ? [0, 2 * Double.pi] : nil, period: period, size: size,
                                         palette: ["#F7D88E", "#B47C2C", "#6E4614", "#E8BC68", "#94621E", "#F7D88E"]))
        out.append(contentsOf: metalGear(at: small, radius: r, teeth: 8, depth: d0, holes: 4, phase: 20 * .pi / 180,
                                         spin: turning ? [0, -2 * Double.pi] : nil, period: period / 2, size: size,
                                         palette: ["#F0B48A", "#A0552A", "#5E2A10", "#D88A5A", "#8A4220", "#F0B48A"]))
        if state == .waiting {
            // Straining against a jam: both gears judder.
            for layer in out.suffix(10) { animate(layer, "transform.rotation.z", [-0.015, 0.015, -0.015], period: 0.16) }
        }

        // A copper pipe across the top with a nozzle venting steam.
        let pipeY = h * 0.2, pipeH = max(5, h * 0.075), nozzleX = w * 0.42
        let pipe = CAGradientLayer()
        pipe.frame = CGRect(x: nozzleX, y: pipeY - pipeH / 2, width: w - nozzleX, height: pipeH)
        pipe.colors = ["#5E2A10", "#E8A070", "#C26A36", "#7A3815"].map { NSColor(hex: $0)!.cgColor }
        pipe.locations = [0, 0.3, 0.55, 1]
        pipe.shadowColor = NSColor.black.cgColor
        pipe.shadowOffset = CGSize(width: 0, height: 2)
        pipe.shadowRadius = 2
        pipe.shadowOpacity = 0.6
        out.insert(pipe, at: behindGears)
        for (i, x) in [nozzleX, nozzleX + (w - nozzleX) * 0.45].enumerated() {
            let flange = CAGradientLayer()
            flange.frame = CGRect(x: x - 2, y: pipeY - pipeH * 0.8, width: 5, height: pipeH * 1.6)
            flange.colors = ["#4A2008", "#F0B48A", "#B0602E", "#5E2A10"].map { NSColor(hex: $0)!.cgColor }
            flange.locations = [0, 0.3, 0.6, 1]
            flange.cornerRadius = 1
            out.insert(flange, at: behindGears + 1 + i)
        }
        let puffs: (count: Int, period: Double) = switch state {
        case .working: (4, 2.6)
        case .waiting: (9, 1.1)
        case .ready: (1, 5)
        case .idle: (0, 1)
        }
        for i in 0..<puffs.count {
            let puff = CAGradientLayer()
            puff.type = .radial
            puff.colors = [NSColor(white: 1, alpha: 0.55).cgColor, NSColor(white: 1, alpha: 0.2).cgColor, NSColor(white: 1, alpha: 0).cgColor]
            puff.startPoint = CGPoint(x: 0.5, y: 0.5)
            puff.endPoint = CGPoint(x: 1, y: 1)
            let s = h * 0.32
            puff.bounds = CGRect(x: 0, y: 0, width: s, height: s)
            puff.position = CGPoint(x: nozzleX - 3, y: pipeY)
            puff.opacity = 0
            let shift = Double(i) / Double(puffs.count)
            let drift = Double(i % 3 - 1) * Double(h) * 0.08
            animate(puff, "transform.translation.x", [0, -Double(w) * 0.12, -Double(w) * 0.2 + drift], period: puffs.period, offset: shift)
            animate(puff, "transform.translation.y", [0, -Double(h) * 0.05, -Double(h) * 0.3], period: puffs.period, offset: shift)
            animate(puff, "transform.scale", [0.2, 0.8, 1.6], period: puffs.period, offset: shift)
            animate(puff, "opacity", [0, 0.9, 0], period: puffs.period, offset: shift)
            out.append(puff)
        }
        return out
    }

    /// A gear made of light: a conic sheen (fixed, so it reads as metal under a lamp) cut to the
    /// gear's shape by a turning mask, with a cast shadow, a beveled rim and a domed hub.
    private func metalGear(at c: CGPoint, radius R: CGFloat, teeth: Int, depth: CGFloat, holes: Int, phase: CGFloat,
                           spin: [Double]?, period: Double, size: CGSize, palette: [String]) -> [CALayer] {
        let outline = CGMutablePath()
        outline.addPath(gearPath(.zero, R, teeth: teeth, depth: depth))
        outline.addEllipse(in: CGRect(x: -R * 0.16, y: -R * 0.16, width: R * 0.32, height: R * 0.32))
        for i in 0..<holes {
            let a = CGFloat(i) * 2 * .pi / CGFloat(holes)
            let hr = R * (holes > 4 ? 0.15 : 0.13)
            outline.addEllipse(in: CGRect(x: R * 0.5 * cos(a) - hr, y: R * 0.5 * sin(a) - hr, width: 2 * hr, height: 2 * hr))
        }
        let box = CGRect(x: c.x - R, y: c.y - R, width: 2 * R, height: 2 * R)
        func turning(_ path: CGPath) -> CAShapeLayer {
            let l = CAShapeLayer()
            l.bounds = CGRect(x: -R, y: -R, width: 2 * R, height: 2 * R)
            l.position = CGPoint(x: R, y: R)
            l.path = path
            l.fillRule = .evenOdd
            l.setAffineTransform(CGAffineTransform(rotationAngle: phase))
            if let spin { animate(l, "transform.rotation.z", spin.map { $0 + Double(phase) }, period: period, linear: true) }
            return l
        }
        let shadow = turning(outline)
        shadow.fillColor = NSColor(white: 0, alpha: 0.55).cgColor
        let shadowHost = CALayer()
        shadowHost.frame = box.offsetBy(dx: R * 0.04, dy: R * 0.07)
        shadowHost.addSublayer(shadow)

        let sheen = CAGradientLayer()
        sheen.frame = box
        sheen.type = .conic
        sheen.startPoint = CGPoint(x: 0.5, y: 0.5)
        sheen.endPoint = CGPoint(x: 0.5, y: 0)
        sheen.colors = palette.map { NSColor(hex: $0)!.cgColor }
        let cut = turning(outline)
        cut.fillColor = NSColor.black.cgColor
        sheen.mask = cut

        let rimHost = CALayer()
        rimHost.frame = box
        let lit = turning(outline)
        lit.fillColor = nil
        lit.strokeColor = NSColor(white: 1, alpha: 0.35).cgColor
        lit.lineWidth = 0.8
        let edge = turning(outline)
        edge.fillColor = nil
        edge.strokeColor = NSColor(white: 0, alpha: 0.55).cgColor
        edge.lineWidth = 0.6
        rimHost.addSublayer(edge)
        rimHost.addSublayer(lit)
        // A groove and a domed hub; round, so they needn't turn.
        let groove = CAShapeLayer()
        groove.frame = box
        groove.path = CGPath(ellipseIn: CGRect(x: R * 0.28, y: R * 0.28, width: R * 1.44, height: R * 1.44), transform: nil)
        groove.fillColor = nil
        groove.strokeColor = NSColor(white: 0, alpha: 0.3).cgColor
        groove.lineWidth = max(0.6, R * 0.025)
        let hub = CAGradientLayer()
        hub.type = .radial
        hub.colors = [NSColor(hex: palette[0])!.cgColor, NSColor(hex: palette[2])!.cgColor]
        hub.startPoint = CGPoint(x: 0.35, y: 0.3)
        hub.endPoint = CGPoint(x: 1.1, y: 1.1)
        let hubR = R * 0.13
        hub.frame = CGRect(x: c.x - hubR, y: c.y - hubR, width: 2 * hubR, height: 2 * hubR)
        hub.cornerRadius = hubR
        hub.borderColor = NSColor(white: 0, alpha: 0.5).cgColor
        hub.borderWidth = 0.6
        return [shadowHost, sheen, rimHost, groove, hub]
    }

    private func rivetLayers(_ points: [CGPoint], radius r: CGFloat, size: CGSize) -> [CALayer] {
        let heads = CGMutablePath(), glints = CGMutablePath(), shadows = CGMutablePath()
        for p in points {
            shadows.addEllipse(in: CGRect(x: p.x - r + 0.5, y: p.y - r + 0.7, width: 2 * r, height: 2 * r))
            heads.addEllipse(in: CGRect(x: p.x - r, y: p.y - r, width: 2 * r, height: 2 * r))
            glints.addEllipse(in: CGRect(x: p.x - r * 0.55, y: p.y - r * 0.6, width: r * 0.7, height: r * 0.6))
        }
        return [fillLayer(shadows, size, NSColor(white: 0, alpha: 0.6)),
                fillLayer(heads, size, NSColor(hex: "#7A5A34")!),
                fillLayer(glints, size, NSColor(hex: "#E8CC94")!.withAlphaComponent(0.85))]
    }

    // MARK: Gothic

    private func gothic(_ size: CGSize) -> [CALayer] {
        let w = size.width, h = size.height
        var out: [CALayer] = []
        var rng = Scribble(UInt64(w * 3 + h))
        // Stone courses.
        let mortar = CGMutablePath()
        let course = max(9, h / 7)
        var row = 0
        for y in stride(from: course, to: h, by: course) {
            mortar.move(to: CGPoint(x: 0, y: y)); mortar.addLine(to: CGPoint(x: w, y: y))
            let blockW = course * 2.4
            for x in stride(from: (row % 2 == 0 ? 0 : blockW / 2), to: w, by: blockW) {
                mortar.move(to: CGPoint(x: x, y: y - course)); mortar.addLine(to: CGPoint(x: x, y: y))
            }
            row += 1
        }
        out.append(strokeLayer(mortar, size, NSColor(white: 0, alpha: 0.55), 0.8))
        out.append(strokeLayer(mortar.copy(using: [CGAffineTransform(translationX: 0, y: 0.8)])!, size, NSColor(white: 1, alpha: 0.035), 0.6))

        // The window: a pointed lancet on the right.
        let bright: Double = switch state {
        case .idle: 0.3
        case .working: 0.75
        case .waiting: 0.9
        case .ready: 1
        }
        let ww = min(w * 0.3, h * 0.48), wx = w - ww - w * 0.07, top = h * 0.1, bottom = h * 0.93
        let spring = top + ww * 0.87
        let window = lancet(x: wx, width: ww, top: top, spring: spring, bottom: bottom)

        // Light spilling out of it onto the stone, and a beam reaching down-left.
        let spill = CAGradientLayer()
        spill.type = .radial
        spill.colors = [accent.withAlphaComponent(0.35 * bright).cgColor, accent.withAlphaComponent(0).cgColor]
        spill.startPoint = CGPoint(x: 0.5, y: 0.5)
        spill.endPoint = CGPoint(x: 1, y: 1)
        spill.frame = CGRect(x: wx - ww * 1.2, y: top - h * 0.3, width: ww * 3.4, height: h * 1.4)
        out.append(spill)
        if state != .idle {
            let beam = CAShapeLayer()
            beam.frame = CGRect(origin: .zero, size: size)
            let b = CGMutablePath()
            b.move(to: CGPoint(x: wx + ww * 0.1, y: spring))
            b.addLine(to: CGPoint(x: wx + ww * 0.9, y: top + ww * 0.5))
            b.addLine(to: CGPoint(x: wx - w * 0.25, y: h))
            b.addLine(to: CGPoint(x: wx - w * 0.55, y: h))
            b.closeSubpath()
            beam.path = b
            let glow = CAGradientLayer()
            glow.frame = beam.frame
            glow.startPoint = CGPoint(x: 1, y: 0)
            glow.endPoint = CGPoint(x: 0, y: 1)
            glow.colors = [NSColor(white: 1, alpha: 0.14 * bright).cgColor, NSColor(white: 1, alpha: 0).cgColor]
            glow.mask = beam
            animate(glow, "opacity", [0.7, 1, 0.7], period: 7)
            out.append(glow)
            // Dust turning in the light.
            for i in 0..<6 {
                let mote = CAShapeLayer()
                mote.frame = CGRect(origin: .zero, size: size)
                let t = CGFloat(rng.next())
                let p = CGPoint(x: wx - (wx * 0.4) * t + ww * 0.3, y: spring + (h - spring) * t * 0.9)
                mote.path = CGPath(ellipseIn: CGRect(x: p.x - 0.5, y: p.y - 0.5, width: 1, height: 1), transform: nil)
                mote.fillColor = NSColor(white: 1, alpha: 0.7).cgColor
                animate(mote, "transform.translation.y", [0, Double(h) * 0.08, 0], period: 9 + Double(i), offset: Double(i) / 6)
                animate(mote, "transform.translation.x", [0, -Double(w) * 0.03, 0], period: 7 + Double(i), offset: Double(i) / 5)
                animate(mote, "opacity", [0, 1, 0], period: 5 + Double(i) * 0.7, offset: Double(i) / 6)
                out.append(mote)
            }
        }

        // The glass: diamond quarries in jewel colors, the state's own among them, in lead cames.
        let jewels = [accent, NSColor(hex: "#1E3A8A")!, NSColor(hex: "#8B1020")!, NSColor(hex: "#5B2A86")!,
                      NSColor(hex: "#146B4A")!, NSColor(hex: "#C8851A")!, accent]
        let glass = CALayer()
        glass.frame = CGRect(origin: .zero, size: size)
        let cell = ww / 3.2
        let panes = jewels.map { _ in CGMutablePath() }
        let cames = CGMutablePath()
        for gy in stride(from: top - cell, through: bottom + cell, by: cell / 2) {
            let odd = Int(((gy - top) / (cell / 2)).rounded()) % 2 != 0
            for gx in stride(from: wx - cell + (odd ? cell / 2 : 0), through: wx + ww + cell, by: cell) {
                let d = CGMutablePath()
                d.addLines(between: [CGPoint(x: gx, y: gy - cell / 2), CGPoint(x: gx + cell / 2, y: gy), CGPoint(x: gx, y: gy + cell / 2),
                                     CGPoint(x: gx - cell / 2, y: gy)])
                d.closeSubpath()
                let pick = Int(rng.next() * Double(jewels.count)) % jewels.count
                panes[pick].addPath(d)
                cames.addPath(d)
            }
        }
        for (i, path) in panes.enumerated() {
            let pane = fillLayer(path, size, jewels[i].withAlphaComponent(0.9))
            if jewels[i] == accent, state == .waiting { animate(pane, "opacity", [0.45, 1, 0.45], period: 1.3) }
            glass.addSublayer(pane)
        }
        // Light through old glass isn't even: brighter in the middle.
        let sheen = CAGradientLayer()
        sheen.type = .radial
        sheen.colors = [NSColor(white: 1, alpha: 0.35).cgColor, NSColor(white: 1, alpha: 0).cgColor]
        sheen.startPoint = CGPoint(x: 0.5, y: 0.45)
        sheen.endPoint = CGPoint(x: 1, y: 1)
        sheen.frame = CGRect(x: wx, y: top, width: ww, height: bottom - top)
        glass.addSublayer(sheen)
        // A mullion, a transom and a rose in the head.
        let tracery = CGMutablePath()
        tracery.move(to: CGPoint(x: wx + ww / 2, y: spring)); tracery.addLine(to: CGPoint(x: wx + ww / 2, y: bottom))
        tracery.move(to: CGPoint(x: wx, y: spring)); tracery.addLine(to: CGPoint(x: wx + ww, y: spring))
        let rose = CGPoint(x: wx + ww / 2, y: spring - ww * 0.32), roseR = ww * 0.24
        tracery.addEllipse(in: CGRect(x: rose.x - roseR, y: rose.y - roseR, width: 2 * roseR, height: 2 * roseR))
        for k in 0..<6 {
            let a = CGFloat(k) * .pi / 3
            tracery.move(to: rose)
            tracery.addLine(to: CGPoint(x: rose.x + roseR * cos(a), y: rose.y + roseR * sin(a)))
        }
        glass.addSublayer(strokeLayer(cames, size, NSColor(hex: "#0A0708")!, 0.9))
        glass.addSublayer(strokeLayer(tracery, size, NSColor(hex: "#1A1418")!, max(1.6, ww * 0.06)))
        glass.opacity = Float(0.35 + 0.65 * bright)
        let glassMask = CAShapeLayer()
        glassMask.path = window
        glass.mask = glassMask
        out.append(glass)
        // The stone frame around it.
        out.append(strokeLayer(window, size, NSColor(hex: "#3A3036")!, max(2.2, ww * 0.09)))
        out.append(strokeLayer(window, size, NSColor(white: 1, alpha: 0.08), 0.6))

        // Candlelight from below, flickering.
        let candle = CAGradientLayer()
        candle.type = .radial
        candle.colors = [NSColor(hex: "#FFB347")!.withAlphaComponent(0.28).cgColor, NSColor(hex: "#FF8C1A")!.withAlphaComponent(0).cgColor]
        candle.startPoint = CGPoint(x: 0.5, y: 0.5)
        candle.endPoint = CGPoint(x: 1, y: 1)
        candle.frame = CGRect(x: -w * 0.3, y: h * 0.45, width: w * 0.9, height: h * 1.1)
        animate(candle, "opacity", [0.75, 1, 0.8, 0.95, 0.7, 1, 0.85, 0.75], period: 2.3)
        out.append(candle)
        return out
    }

    /// A pointed (equilateral) arch on two straight jambs.
    private func lancet(x: CGFloat, width ww: CGFloat, top: CGFloat, spring: CGFloat, bottom: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let radius = ww * 1.0
        let rise = spring - top
        p.move(to: CGPoint(x: x, y: bottom))
        p.addLine(to: CGPoint(x: x, y: spring))
        // Left side, curving up to the apex around the right springer, then down around the left.
        for i in 1...16 {
            let t = CGFloat(i) / 16
            let a = CGFloat.pi + t * (CGFloat.pi / 3)
            let y = spring + radius * sin(a) * min(1, rise / (radius * 0.866))
            p.addLine(to: CGPoint(x: x + ww + radius * cos(a), y: y))
        }
        for i in 1...16 {
            let t = CGFloat(i) / 16
            let a = 5 * CGFloat.pi / 3 + t * (CGFloat.pi / 3)
            let y = spring + radius * sin(a) * min(1, rise / (radius * 0.866))
            p.addLine(to: CGPoint(x: x + radius * cos(a), y: y))
        }
        p.addLine(to: CGPoint(x: x + ww, y: bottom))
        p.closeSubpath()
        return p
    }

    // MARK: Pieces

    func sparkle(_ c: CGPoint, _ r: CGFloat) -> CGPath {
        let p = CGMutablePath()
        let waist = r * 0.18
        p.addLines(between: [CGPoint(x: c.x, y: c.y - r), CGPoint(x: c.x + waist, y: c.y - waist), CGPoint(x: c.x + r, y: c.y),
                             CGPoint(x: c.x + waist, y: c.y + waist), CGPoint(x: c.x, y: c.y + r), CGPoint(x: c.x - waist, y: c.y + waist),
                             CGPoint(x: c.x - r, y: c.y), CGPoint(x: c.x - waist, y: c.y - waist)])
        p.closeSubpath()
        return p
    }

    func strokeLayer(_ path: CGPath, _ size: CGSize, _ color: NSColor, _ width: CGFloat) -> CAShapeLayer {
        let l = CAShapeLayer()
        l.frame = CGRect(origin: .zero, size: size)
        l.path = path
        l.fillColor = nil
        l.strokeColor = color.cgColor
        l.lineWidth = width
        l.lineCap = .round
        l.lineJoin = .round
        return l
    }

    func fillLayer(_ path: CGPath, _ size: CGSize, _ color: NSColor) -> CAShapeLayer {
        let l = CAShapeLayer()
        l.frame = CGRect(origin: .zero, size: size)
        l.path = path
        l.fillColor = color.cgColor
        return l
    }

    func hueAndSaturation(_ color: NSColor) -> (CGFloat, CGFloat) {
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        (color.usingColorSpace(.sRGB) ?? color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return (h, s)
    }

    /// Loops `values` over `period` seconds (at this look's speed), in step with the wall clock.
    func animate(_ layer: CALayer, _ keyPath: String, _ values: [Any], times: [Double]? = nil,
                         period: Double, offset: Double = 0, linear: Bool = false) {
        guard !still else { return }
        let a = CAKeyframeAnimation(keyPath: keyPath)
        a.values = values
        a.keyTimes = (times ?? values.indices.map { Double($0) / Double(max(1, values.count - 1)) }).map { NSNumber(value: $0) }
        if !linear {
            a.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: max(1, values.count - 1))
        }
        let duration = period / max(0.25, speed)
        a.duration = duration
        a.repeatCount = .infinity
        a.isRemovedOnCompletion = false
        a.timeOffset = (Date.timeIntervalSinceReferenceDate + offset * duration).truncatingRemainder(dividingBy: duration)
        layer.add(a, forKey: keyPath + "\(ObjectIdentifier(a).hashValue)")
    }
}
