import AppKit
import QuartzCore

// A vector-display horizon (SkinBackdrop.swift has the view and helpers): glowing wireframe
// mountains, a crescent moon and pyramids on a black field, a grid racing toward you, all in one
// phosphor color like an early-80s vector arcade cabinet or a war-room screen.

extension BackdropArt {
    func vectorHorizon(_ size: CGSize, phosphor: NSColor) -> [CALayer] {
        let w = size.width, h = size.height
        let horizonY = (h * 0.56).rounded()
        var rng = Scribble(UInt64(w) + 61)
        let scene = CALayer()
        scene.frame = CGRect(origin: .zero, size: size)
        // Everything is light on black: one glow over the lot.
        scene.shadowColor = phosphor.cgColor
        scene.shadowOffset = .zero
        scene.shadowRadius = 2.5
        scene.shadowOpacity = 1

        let lines = CGMutablePath()
        // A crescent moon, outlined.
        let mr = h * 0.12, mc = CGPoint(x: w * 0.18, y: h * 0.2)
        lines.addArc(center: mc, radius: mr, startAngle: .pi * 0.35, endAngle: .pi * 1.65, clockwise: false)
        lines.addArc(center: CGPoint(x: mc.x - mr * 0.45, y: mc.y), radius: mr * 0.85, startAngle: .pi * 1.6, endAngle: .pi * 0.4,
                     clockwise: true)
        lines.closeSubpath()
        // Two ranges of wireframe mountains, the far one with a volcano.
        for (layer, height) in [(0, h * 0.26), (1, h * 0.13)] {
            var x: CGFloat = 0
            var peaks: [CGPoint] = [CGPoint(x: 0, y: horizonY)]
            while x < w {
                x += w / 9 * (0.6 + CGFloat(rng.next()) * 0.8)
                let tall = height * (0.4 + 0.6 * CGFloat(rng.next()))
                peaks.append(CGPoint(x: x, y: horizonY - tall))
                x += w / 11 * (0.5 + CGFloat(rng.next()))
                peaks.append(CGPoint(x: x, y: horizonY - (layer == 0 ? tall * 0.35 : 0)))
            }
            peaks.append(CGPoint(x: w, y: horizonY))
            lines.addLines(between: peaks)
            // Ridge lines down the faces, the way vector games shaded mountains.
            for p in peaks where p.y < horizonY - 2 {
                lines.move(to: p)
                lines.addLine(to: CGPoint(x: p.x + (CGFloat(rng.next()) - 0.5) * height * 0.6, y: horizonY))
            }
        }
        // Pyramids standing on the plain.
        for (px, s) in [(w * 0.3, h * 0.12), (w * 0.82, h * 0.08)] {
            let base = horizonY + h * 0.14
            lines.addLines(between: [CGPoint(x: px - s, y: base), CGPoint(x: px, y: base - s * 1.3), CGPoint(x: px + s, y: base),
                                     CGPoint(x: px - s, y: base)])
            lines.move(to: CGPoint(x: px, y: base - s * 1.3))
            lines.addLine(to: CGPoint(x: px + s * 0.25, y: base))
        }
        // Stars.
        let stars = CGMutablePath()
        for _ in 0..<max(6, Int(w / 20)) {
            let x = CGFloat(rng.next()) * w, y = CGFloat(rng.next()) * horizonY * 0.7
            stars.addRect(CGRect(x: x, y: y, width: 0.9, height: 0.9))
        }
        scene.addSublayer(fillLayer(stars, size, phosphor.withAlphaComponent(0.8)))
        scene.addSublayer(strokeLayer(lines, size, phosphor, 0.9))

        // The floor: rays to the vanishing point and crossbars sliding toward you.
        let rays = CGMutablePath()
        let vanish = w * 0.5
        for i in -9...9 {
            rays.move(to: CGPoint(x: vanish + CGFloat(i) * w / 60, y: horizonY))
            rays.addLine(to: CGPoint(x: vanish + CGFloat(i) * w / 4.3, y: h + 2))
        }
        scene.addSublayer(strokeLayer(rays, size, phosphor.withAlphaComponent(0.45), 0.6))
        let horizon = CGMutablePath()
        horizon.move(to: CGPoint(x: 0, y: horizonY))
        horizon.addLine(to: CGPoint(x: w, y: horizonY))
        scene.addSublayer(strokeLayer(horizon, size, phosphor, 1))
        let depth = h - horizonY
        let period: Double? = switch state {
        case .working: 0.9
        case .waiting: 0.45
        case .ready: 2.6
        case .idle: nil
        }
        for k in 0..<7 {
            let bar = strokeLayer(horizon, size, phosphor.withAlphaComponent(0.45), 0.6)
            let u = Double(k) / 7
            bar.setAffineTransform(CGAffineTransform(translationX: 0, y: depth * CGFloat(u * u)))
            if let period {
                animate(bar, "transform.translation.y", (0...16).map { let v = Double($0) / 16; return Double(depth) * v * v },
                        period: period, offset: u, linear: true)
            }
            scene.addSublayer(bar)
        }
        // Needs you: the whole screen flickers like a warning; idle, it dims.
        switch state {
        case .waiting: animate(scene, "opacity", [1, 0.55, 1, 0.8, 1], period: 0.5)
        case .idle: scene.opacity = 0.55
        default: break
        }
        return [scene]
    }
}
