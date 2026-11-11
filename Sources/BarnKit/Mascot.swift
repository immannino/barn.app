import AppKit
import QuartzCore
import SwiftUI

/// A skin's character, acting out its agent's state at the top of each card: a robot's eyes
/// (or face) that sleep, scan, widen and smile, or a hamster that sleeps, paws at the glass,
/// runs its wheel and drinks. Drawn and animated in Core Animation, like the card effects, so the
/// window server plays it and barn stays idle; rebuilt only when the state, colors or size change.
/// With Reduce Motion each pose holds still.
struct MascotView: NSViewRepresentable {
    var kind: Skin.Mascot
    var state: AgentState
    /// The robot's eye color: the state's.
    var accent: NSColor
    /// Lines like a sleeper's z's: the card's text color.
    var ink: NSColor
    var speed: Double = 1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> MascotLayerView { MascotLayerView() }
    func updateNSView(_ view: MascotLayerView, context: Context) {
        view.configure(MascotArt(kind: kind, state: state, accent: accent, ink: ink, speed: speed, still: reduceMotion))
    }
}

final class MascotLayerView: NSView {
    private var art: MascotArt?
    private var built: (art: MascotArt, size: CGSize)?

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func configure(_ art: MascotArt) {
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

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        rebuild(force: true)
    }

    private func rebuild(force: Bool = false) {
        guard let art, let root = layer, window != nil, bounds.width > 0, bounds.height > 0 else { return }
        if !force, let built, built.art == art, built.size == bounds.size { return }
        built = (art, bounds.size)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        root.sublayers?.forEach { $0.removeFromSuperlayer() }
        root.addSublayer(art.layer(in: bounds.size))
        CATransaction.commit()
    }
}

/// The drawing, in a 64×48 design space (y down) scaled to fit and centered.
struct MascotArt: Equatable {
    var kind: Skin.Mascot
    var state: AgentState
    var accent: NSColor
    var ink: NSColor
    var speed: Double
    var still: Bool

    static let canvas = CGSize(width: 64, height: 48)

    func layer(in size: CGSize) -> CALayer {
        let scale = min(size.width / Self.canvas.width, size.height / Self.canvas.height)
        let stage = CALayer()
        stage.bounds = CGRect(origin: .zero, size: Self.canvas)
        stage.position = CGPoint(x: size.width / 2, y: size.height / 2)
        stage.setAffineTransform(CGAffineTransform(scaleX: scale, y: scale))
        // Shape layers rasterize after the scale, so lines stay crisp.
        stage.rasterizationScale = 2 * scale
        let parts: [CALayer] = switch kind {
        case .none: []
        case .eyes: robot(face: false)
        case .face: robot(face: true)
        case .hamster: hamster()
        case .fishbowl: fishbowl()
        case .microwave: microwave()
        case .kettle: kettle()
        case .pixelHamster: pixelHamster()
        case .colorCycle: colorCycle()
        }
        parts.forEach(stage.addSublayer)
        return stage
    }

    // MARK: Robot

    private func robot(face: Bool) -> [CALayer] {
        var out: [CALayer] = []
        if face {
            out.append(shape(roundRect(8, 3, 48, 42, 11), fill: NSColor(hex: "#0E1218")!,
                             stroke: ink.withAlphaComponent(0.3), width: 1))
        }
        let y: CGFloat = face ? 18 : 24
        let eyes = group(pivot: CGPoint(x: 32, y: y))
        eyes.shadowColor = accent.cgColor
        eyes.shadowOffset = .zero
        eyes.shadowRadius = 3
        eyes.shadowOpacity = state == .idle ? 0.4 : 0.9
        out.append(eyes)

        switch state {
        case .idle:
            // Asleep: eyes shut to lines, breathing; z's drift up.
            for x in [23.0, 41.0] {
                eyes.addSublayer(shape(roundRect(x - 5, y + 1, 10, 2.4, 1.2), fill: accent))
            }
            animate(eyes, "opacity", [0.45, 1, 0.45], period: 3.6)
            out.append(contentsOf: zees(at: CGPoint(x: face ? 46 : 48, y: face ? 12 : 14), color: accent))
            if face {
                let snore = group(pivot: CGPoint(x: 32, y: 33))
                snore.addSublayer(shape(circle(32, 33, 1.8), fill: nil, stroke: accent, width: 1.2))
                animate(snore, "transform.scale", [0.7, 1.25, 0.7], period: 3.6)
                out.append(snore)
            }

        case .working:
            // Busy: eyes dart around and blink now and then; the mouth is an equalizer.
            for (i, x) in [23.0, 41.0].enumerated() {
                let eye = group(pivot: CGPoint(x: x, y: y))
                eye.addSublayer(shape(roundRect(x - 4.5, y - 6.5, 9, 13, 4.5), fill: accent))
                animate(eye, "transform.scale.y", [1, 1, 0.1, 1, 1], times: [0, 0.88, 0.91, 0.94, 1], period: 3.1 + Double(i) * 0.01)
                eyes.addSublayer(eye)
            }
            animate(eyes, "transform.translation.x", [0, -4, -4, 4, 4, 0], times: [0, 0.12, 0.42, 0.55, 0.85, 1], period: 4.2)
            if face {
                for i in 0..<5 {
                    let x = 24 + CGFloat(i) * 4
                    let bar = group(pivot: CGPoint(x: x, y: 34))
                    bar.addSublayer(shape(roundRect(x - 1.2, 30, 2.4, 8, 1.2), fill: accent))
                    animate(bar, "transform.scale.y", [0.25, 1, 0.25], period: 0.45 + 0.11 * Double(i))
                    bar.shadowColor = accent.cgColor
                    bar.shadowOffset = .zero
                    bar.shadowRadius = 2
                    bar.shadowOpacity = 0.8
                    out.append(bar)
                }
            }

        case .waiting:
            // Needs you: eyes wide and pulsing, an exclamation flashing (or an "O" mouth).
            for x in [22.0, 42.0] {
                let eye = group(pivot: CGPoint(x: x, y: y))
                eye.addSublayer(shape(roundRect(x - 6, y - 8, 12, 16, 6), fill: accent))
                eye.addSublayer(shape(circle(x + 2, y - 3, 1.8), fill: NSColor.white.withAlphaComponent(0.85)))
                animate(eye, "transform.scale.y", [1, 1, 0.1, 1, 0.1, 1, 1], times: [0, 0.7, 0.74, 0.78, 0.82, 0.86, 1], period: 2.4)
                eyes.addSublayer(eye)
            }
            animate(eyes, "transform.scale", [1, 1.1, 1], period: 0.9)
            if face {
                let mouth = group(pivot: CGPoint(x: 32, y: 35))
                mouth.addSublayer(shape(ellipse(32, 35, 7, 8), fill: nil, stroke: accent, width: 2))
                animate(mouth, "transform.scale", [0.85, 1.1, 0.85], period: 0.9)
                out.append(mouth)
            } else {
                let bang = group(pivot: CGPoint(x: 32, y: 6))
                bang.addSublayer(shape(roundRect(30.8, 0.5, 2.4, 7, 1.2), fill: accent))
                bang.addSublayer(shape(circle(32, 10.2, 1.3), fill: accent))
                animate(bang, "opacity", [1, 0], times: [0, 0.5, 1], period: 0.8, discrete: true)
                out.append(bang)
            }

        case .ready:
            // Done: happy ^ ^ eyes, a gentle bob, and on the face a smile and blush.
            for x in [23.0, 41.0] {
                let arc = CGMutablePath()
                arc.move(to: CGPoint(x: x - 5.5, y: y + 3))
                arc.addQuadCurve(to: CGPoint(x: x + 5.5, y: y + 3), control: CGPoint(x: x, y: y - 6))
                eyes.addSublayer(shape(arc, fill: nil, stroke: accent, width: 2.8))
            }
            animate(eyes, "transform.translation.y", [0, -1.6, 0], period: 1.8)
            if face {
                let smile = CGMutablePath()
                smile.move(to: CGPoint(x: 24, y: 31))
                smile.addQuadCurve(to: CGPoint(x: 40, y: 31), control: CGPoint(x: 32, y: 39))
                out.append(shape(smile, fill: nil, stroke: accent, width: 2.6))
                for x in [16.0, 48.0] {
                    out.append(shape(ellipse(x, 29, 6, 3), fill: NSColor(hex: "#FF7FA8")!.withAlphaComponent(0.45)))
                }
            }
        }
        return out
    }

    // MARK: Hamster

    private let fur = NSColor(hex: "#D9873A")!
    private let furDark = NSColor(hex: "#A9601F")!
    private let belly = NSColor(hex: "#FBF3E4")!
    private let pink = NSColor(hex: "#E07B6E")!
    private let eyeColor = NSColor(hex: "#1E1B18")!
    private let outline = NSColor(hex: "#6B4423")!
    private let metal = NSColor(hex: "#2F8A84")!

    private func furry(_ path: CGPath, _ color: NSColor? = nil) -> CAShapeLayer {
        shape(path, fill: color ?? fur)
    }

    private func hamster() -> [CALayer] {
        switch state {
        case .idle: sleeping()
        case .waiting: pawing()
        case .working: running()
        case .ready: drinking()
        }
    }

    /// Curled up asleep, breathing, z's drifting up.
    private func sleeping() -> [CALayer] {
        let body = group(pivot: CGPoint(x: 34, y: 45))
        body.addSublayer(furry(ellipse(34, 34, 38, 22)))
        body.addSublayer(shape(ellipse(25, 39, 14, 7), fill: belly))
        body.addSublayer(furry(circle(21, 25, 4)))
        body.addSublayer(shape(circle(21, 25, 2.1), fill: pink))
        let lid = CGMutablePath()
        lid.move(to: CGPoint(x: 16, y: 31))
        lid.addQuadCurve(to: CGPoint(x: 22, y: 31), control: CGPoint(x: 19, y: 33.6))
        body.addSublayer(shape(lid, fill: nil, stroke: eyeColor, width: 1.1))
        body.addSublayer(shape(circle(15.6, 35, 1.3), fill: pink))
        body.addSublayer(shape(ellipse(22, 44, 6, 3.4), fill: belly))
        animate(body, "transform.scale", [1, 1.035, 1], period: 3.2)
        return [body] + zees(at: CGPoint(x: 46, y: 16), color: ink)
    }

    /// Up against the glass, tapping it with both paws.
    private func pawing() -> [CALayer] {
        var out: [CALayer] = []
        out.append(furry(ellipse(32, 39, 28, 20)))
        out.append(shape(ellipse(32, 41, 17, 12), fill: belly))
        let head = group(pivot: CGPoint(x: 32, y: 30))
        for x in [22.0, 42.0] {
            head.addSublayer(furry(circle(x, 11.5, 4.5)))
            head.addSublayer(shape(circle(x, 11.5, 2.4), fill: pink))
        }
        head.addSublayer(furry(circle(32, 22, 12.5)))
        for x in [24.0, 40.0] { head.addSublayer(shape(ellipse(x, 26.5, 6.5, 4.5), fill: belly)) }
        for x in [27.5, 36.5] {
            head.addSublayer(shape(circle(x, 20.5, 2.6), fill: eyeColor))
        }
        head.addSublayer(shape(circle(32, 24.8, 1.5), fill: pink))
        let mouth = CGMutablePath()
        mouth.move(to: CGPoint(x: 29.8, y: 26.8))
        mouth.addQuadCurve(to: CGPoint(x: 32, y: 27.4), control: CGPoint(x: 30.8, y: 28.6))
        mouth.addQuadCurve(to: CGPoint(x: 34.2, y: 26.8), control: CGPoint(x: 33.2, y: 28.6))
        head.addSublayer(shape(mouth, fill: nil, stroke: eyeColor, width: 0.8))
        animate(head, "transform.rotation.z", [-0.06, 0.06, -0.06], period: 1.6)
        out.append(head)
        // Paws on the glass, tapping in turn.
        for (i, x) in [15.5, 48.5].enumerated() {
            let paw = group(pivot: CGPoint(x: x, y: 30))
            let arm = CGMutablePath()
            arm.move(to: CGPoint(x: i == 0 ? 24 : 40, y: 36))
            arm.addLine(to: CGPoint(x: x, y: 31))
            paw.addSublayer(shape(arm, fill: nil))
            paw.addSublayer(shape(arm, fill: nil, stroke: fur, width: 3.6))
            paw.addSublayer(shape(ellipse(x, 29, 7.5, 8.5), fill: belly))
            for dx in [-2.2, 0, 2.2] { paw.addSublayer(shape(circle(x + dx, 26.2, 0.9), fill: pink)) }
            animate(paw, "transform.translation.y", [0, -3.5, 0], period: 0.44, offset: Double(i) * 0.5)
            out.append(paw)
        }
        // Little "look at me" marks.
        let marks = CGMutablePath()
        marks.move(to: CGPoint(x: 52, y: 7)); marks.addLine(to: CGPoint(x: 55.5, y: 3.5))
        marks.move(to: CGPoint(x: 54, y: 11)); marks.addLine(to: CGPoint(x: 58.5, y: 10))
        marks.move(to: CGPoint(x: 12, y: 7)); marks.addLine(to: CGPoint(x: 8.5, y: 3.5))
        let emphasis = shape(marks, fill: nil, stroke: ink, width: 1.3)
        animate(emphasis, "opacity", [1, 0], times: [0, 0.5, 1], period: 0.6, discrete: true)
        out.append(emphasis)
        return out
    }

    /// Running flat out in a spinning wheel.
    private func running() -> [CALayer] {
        var out: [CALayer] = []
        let stand = CGMutablePath()
        stand.move(to: CGPoint(x: 32, y: 24)); stand.addLine(to: CGPoint(x: 22, y: 47))
        stand.move(to: CGPoint(x: 32, y: 24)); stand.addLine(to: CGPoint(x: 42, y: 47))
        stand.move(to: CGPoint(x: 17, y: 47)); stand.addLine(to: CGPoint(x: 47, y: 47))
        out.append(shape(stand, fill: nil, stroke: metal, width: 2))
        let wheel = group(pivot: CGPoint(x: 32, y: 24))
        wheel.addSublayer(shape(circle(32, 24, 21), fill: nil, stroke: metal, width: 2.4))
        wheel.addSublayer(shape(circle(32, 24, 18.5), fill: nil, stroke: metal.withAlphaComponent(0.7), width: 0.8))
        let rungs = CGMutablePath()
        for i in 0..<16 {
            let a = Double(i) / 16 * 2 * .pi
            rungs.move(to: CGPoint(x: 32 + 18.5 * cos(a), y: 24 + 18.5 * sin(a)))
            rungs.addLine(to: CGPoint(x: 32 + 21 * cos(a), y: 24 + 21 * sin(a)))
        }
        for i in 0..<6 {
            let a = Double(i) / 6 * 2 * .pi
            rungs.move(to: CGPoint(x: 32, y: 24))
            rungs.addLine(to: CGPoint(x: 32 + 18.5 * cos(a), y: 24 + 18.5 * sin(a)))
        }
        wheel.addSublayer(shape(rungs, fill: nil, stroke: metal, width: 0.8))
        wheel.addSublayer(shape(circle(32, 24, 2), fill: NSColor(hex: "#8A97A8")!))
        animate(wheel, "transform.rotation.z", [0, 2 * Double.pi], period: 1.4, linear: true)
        out.append(wheel)

        let runner = group(pivot: CGPoint(x: 31, y: 38))
        for (i, x) in [25.0, 36.0].enumerated() {
            let legs = group(pivot: CGPoint(x: x, y: 42.5))
            legs.addSublayer(shape(ellipse(x, 42.5, 4.4, 3), fill: furDark))
            animate(legs, "transform.translation.x", [-1.8, 1.8, -1.8], period: 0.24, offset: Double(i) * 0.5)
            runner.addSublayer(legs)
        }
        runner.addSublayer(furry(circle(19.5, 36, 1.6)))
        let body = CGMutablePath()
        body.addEllipse(in: CGRect(x: -10, y: -6, width: 20, height: 12),
                        transform: CGAffineTransform(translationX: 30, y: 37).rotated(by: -0.12))
        runner.addSublayer(furry(body))
        runner.addSublayer(shape(ellipse(31, 40, 10, 4.5), fill: belly))
        runner.addSublayer(furry(circle(39, 33.5, 6)))
        runner.addSublayer(furry(circle(36.8, 28.4, 2.4)))
        runner.addSublayer(shape(circle(36.8, 28.4, 1.2), fill: pink))
        runner.addSublayer(shape(circle(41.2, 32.6, 1.25), fill: eyeColor))
        runner.addSublayer(shape(circle(45, 34.6, 1), fill: pink))
        animate(runner, "transform.translation.y", [0, -1.3, 0], period: 0.24)
        out.append(runner)

        let speed = CGMutablePath()
        for (dy, len) in [(33.0, 5.0), (37.0, 7.0), (41.0, 4.0)] {
            speed.move(to: CGPoint(x: 16 - len, y: dy)); speed.addLine(to: CGPoint(x: 16, y: dy))
        }
        let lines = shape(speed, fill: nil, stroke: ink.withAlphaComponent(0.45), width: 1)
        animate(lines, "opacity", [0.2, 1, 0.2], period: 0.5)
        out.append(lines)
        return out
    }

    /// Sitting up, sipping from the water bottle, bubbles rising in it.
    private func drinking() -> [CALayer] {
        var out: [CALayer] = []
        let water = NSColor(hex: "#2F8A84")!
        out.append(shape(roundRect(45, 3, 13, 27, 4), fill: NSColor(hex: "#BFE0DA")!))
        out.append(shape(roundRect(46, 10, 11, 19, 3), fill: water))
        out.append(shape(roundRect(44.5, 0.5, 14, 4, 1.5), fill: NSColor(hex: "#C8372D")!))
        for (i, x) in [49.0, 52.0, 55.0].enumerated() {
            let bubble = group(pivot: CGPoint(x: x, y: 27))
            bubble.addSublayer(shape(circle(x, 27, 0.9 + 0.35 * Double(i)), fill: nil, stroke: .white, width: 0.6))
            animate(bubble, "transform.translation.y", [0, -16], period: 1.8, offset: Double(i) / 3, linear: true)
            animate(bubble, "opacity", [0, 1, 1, 0], times: [0, 0.15, 0.8, 1], period: 1.8, offset: Double(i) / 3)
            out.append(bubble)
        }
        out.append(shape(line(50, 29.5, 46, 35), fill: nil, stroke: metal, width: 2.4))
        out.append(shape(circle(45.5, 35.6, 1.4), fill: NSColor(hex: "#8A97A8")!))

        out.append(furry(ellipse(25, 37, 24, 18)))
        out.append(shape(ellipse(28, 40, 12, 10), fill: belly))
        for x in [20.0, 31.0] { out.append(shape(ellipse(x, 45.5, 6, 2.6), fill: belly)) }
        let head = group(pivot: CGPoint(x: 33, y: 34))
        head.addSublayer(furry(circle(31, 23.5, 3.4)))
        head.addSublayer(shape(circle(31, 23.5, 1.8), fill: pink))
        head.addSublayer(furry(circle(36, 31, 8.2)))
        let lid = CGMutablePath()
        lid.move(to: CGPoint(x: 35.5, y: 29.2))
        lid.addQuadCurve(to: CGPoint(x: 40, y: 29.2), control: CGPoint(x: 37.75, y: 26.8))
        head.addSublayer(shape(lid, fill: nil, stroke: eyeColor, width: 1.1))
        head.addSublayer(shape(circle(43.8, 33, 1.3), fill: pink))
        animate(head, "transform.rotation.z", [0, -0.07, 0], period: 1.1)
        out.append(head)
        out.append(shape(ellipse(39.5, 38.5, 4, 5), fill: belly))
        let drop = shape(circle(44.6, 38.2, 0.8), fill: water)
        animate(drop, "opacity", [0, 1, 0], period: 1.1)
        out.append(drop)
        return out
    }

    // MARK: Pieces

    /// Three z's that float up and fade, one after another.
    func zees(at origin: CGPoint, color: NSColor) -> [CALayer] {
        (0..<3).map { i in
            let size = 3 + CGFloat(i) * 1.2
            let x = origin.x + CGFloat(i) * 5, y = origin.y - CGFloat(i) * 5
            let z = CGMutablePath()
            z.move(to: CGPoint(x: x, y: y))
            z.addLine(to: CGPoint(x: x + size, y: y))
            z.addLine(to: CGPoint(x: x, y: y + size))
            z.addLine(to: CGPoint(x: x + size, y: y + size))
            let layer = group(pivot: CGPoint(x: x, y: y))
            layer.addSublayer(shape(z, fill: nil, stroke: color, width: 1.2))
            animate(layer, "opacity", [0, 1, 1, 0], times: [0, 0.2, 0.7, 1], period: 3, offset: Double(i) / 3)
            animate(layer, "transform.translation.y", [3, -3], period: 3, offset: Double(i) / 3, linear: true)
            return layer
        }
    }

    /// A layer over the whole canvas that turns and scales around `pivot`.
    func group(pivot: CGPoint) -> CALayer {
        let g = CALayer()
        g.bounds = CGRect(origin: .zero, size: Self.canvas)
        g.anchorPoint = CGPoint(x: pivot.x / Self.canvas.width, y: pivot.y / Self.canvas.height)
        g.position = pivot
        return g
    }

    func shape(_ path: CGPath, fill: NSColor?, stroke: NSColor? = nil, width: CGFloat = 1) -> CAShapeLayer {
        let l = CAShapeLayer()
        l.frame = CGRect(origin: .zero, size: Self.canvas)
        l.path = path
        l.fillColor = fill?.cgColor
        l.strokeColor = stroke?.cgColor
        l.lineWidth = width
        l.lineCap = .round
        l.lineJoin = .round
        l.contentsScale = 4
        return l
    }

    /// Loops `values` over `period` seconds (at this look's speed), starting where the wall clock
    /// is in the cycle so every card moves in step. `offset` shifts it by a fraction of a cycle.
    func animate(_ layer: CALayer, _ keyPath: String, _ values: [Double], times: [Double]? = nil,
                         period: Double, offset: Double = 0, discrete: Bool = false, linear: Bool = false) {
        guard !still else { return }
        let a = CAKeyframeAnimation(keyPath: keyPath)
        a.values = values
        a.keyTimes = (times ?? values.indices.map { Double($0) / Double(max(1, values.count - 1)) }).map { NSNumber(value: $0) }
        if discrete { a.calculationMode = .discrete }
        if !linear && !discrete {
            a.timingFunctions = Array(repeating: CAMediaTimingFunction(name: .easeInEaseOut), count: max(1, values.count - 1))
        }
        let duration = period / max(0.25, speed)
        a.duration = duration
        a.repeatCount = .infinity
        a.isRemovedOnCompletion = false
        a.timeOffset = (Date.timeIntervalSinceReferenceDate + offset * duration).truncatingRemainder(dividingBy: duration)
        layer.add(a, forKey: keyPath)
    }

    func circle(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r), transform: nil)
    }

    func ellipse(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat) -> CGPath {
        CGPath(ellipseIn: CGRect(x: x - w / 2, y: y - h / 2, width: w, height: h), transform: nil)
    }

    func roundRect(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ r: CGFloat) -> CGPath {
        CGPath(roundedRect: CGRect(x: x, y: y, width: w, height: h), cornerWidth: min(r, w / 2), cornerHeight: min(r, h / 2), transform: nil)
    }

    func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat) -> CGPath {
        let p = CGMutablePath()
        p.move(to: CGPoint(x: x1, y: y1))
        p.addLine(to: CGPoint(x: x2, y: y2))
        return p
    }
}
