import AppKit

/// The bigger skin pattern tiles (SkinViews.swift tiles and caches them): drawn once into a
/// flipped `size`×`size` image, with the skin's pattern colors.
enum PatternArt {
    static func draw(_ pattern: Skin.Pattern, colors: [NSColor], size: CGFloat) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        func color(_ i: Int) -> CGColor { colors[i % colors.count].cgColor }
        var rng = Scribble(11)
        ctx.setLineCap(.round)
        ctx.setLineJoin(.round)

        switch pattern {
        case .memphis:
            // A squiggle, a triangle, a dot, a zigzag, a half moon, a patch of dots.
            ctx.setLineWidth(2.4)
            ctx.setStrokeColor(color(0))
            ctx.move(to: CGPoint(x: 6, y: 12))
            for i in 0..<4 {
                let x = 6 + CGFloat(i) * 6
                ctx.addQuadCurve(to: CGPoint(x: x + 6, y: 12), control: CGPoint(x: x + 3, y: i % 2 == 0 ? 6 : 18))
            }
            ctx.strokePath()
            ctx.setStrokeColor(color(1))
            ctx.setLineWidth(2)
            ctx.addLines(between: [CGPoint(x: 44, y: 22), CGPoint(x: 50, y: 10), CGPoint(x: 56, y: 22), CGPoint(x: 44, y: 22)])
            ctx.strokePath()
            ctx.setFillColor(color(2))
            ctx.fillEllipse(in: CGRect(x: 9, y: 38, width: 10, height: 10))
            ctx.setStrokeColor(color(3))
            ctx.addLines(between: (0...5).map { CGPoint(x: 32 + CGFloat($0) * 4.5, y: $0 % 2 == 0 ? 44 : 38) })
            ctx.strokePath()
            ctx.setFillColor(color(4))
            ctx.addArc(center: CGPoint(x: 30, y: 28), radius: 5, startAngle: 0, endAngle: .pi, clockwise: false)
            ctx.closePath()
            ctx.fillPath()
            ctx.setFillColor(color(0))
            for x in 0..<3 { for y in 0..<3 { ctx.fillEllipse(in: CGRect(x: 47 + CGFloat(x) * 4, y: 50 + CGFloat(y) * 4, width: 1.6, height: 1.6)) } }
            ctx.setStrokeColor(color(2))
            ctx.setLineWidth(2)
            ctx.addLines(between: [CGPoint(x: 8, y: 58), CGPoint(x: 18, y: 54)])
            ctx.strokePath()

        case .bauhaus:
            ctx.setFillColor(color(0))
            ctx.fillEllipse(in: CGRect(x: 6, y: 6, width: 22, height: 22))
            ctx.setFillColor(color(1))
            ctx.fill(CGRect(x: 40, y: 8, width: 20, height: 20))
            ctx.setFillColor(color(2))
            ctx.addArc(center: CGPoint(x: 52, y: 62), radius: 12, startAngle: .pi, endAngle: 2 * .pi, clockwise: false)
            ctx.closePath()
            ctx.fillPath()
            ctx.setFillColor(color(3))
            ctx.fill(CGRect(x: 6, y: 44, width: 26, height: 4))
            ctx.addLines(between: [CGPoint(x: 12, y: 66), CGPoint(x: 22, y: 52), CGPoint(x: 32, y: 66)])
            ctx.closePath()
            ctx.fillPath()

        case .waves:
            ctx.setStrokeColor(color(0))
            ctx.setLineWidth(1)
            for row in 0..<2 {
                let y = 5 + CGFloat(row) * 8, shift = CGFloat(row) * 4
                for x in stride(from: -8 + shift, through: size + 8, by: 8) {
                    ctx.addArc(center: CGPoint(x: x + 4, y: y), radius: 4, startAngle: .pi, endAngle: 0, clockwise: true)
                    ctx.strokePath()
                }
            }

        case .hatch:
            ctx.setStrokeColor(color(0))
            ctx.setLineWidth(0.5)
            for k in [-size, 0, size] {
                ctx.addLines(between: [CGPoint(x: k, y: size), CGPoint(x: k + size, y: 0)])
                ctx.addLines(between: [CGPoint(x: k, y: 0), CGPoint(x: k + size, y: size)])
            }
            ctx.strokePath()

        case .stipple:
            for i in 0..<90 {
                ctx.setFillColor(color(i))
                let d = 0.9 + CGFloat(rng.next()) * 1.3
                ctx.fillEllipse(in: CGRect(x: CGFloat(rng.next()) * (size - d), y: CGFloat(rng.next()) * (size - d), width: d, height: d))
            }

        case .chevrons:
            ctx.setStrokeColor(color(0))
            ctx.setLineWidth(1.6)
            ctx.addLines(between: (0...4).map { CGPoint(x: CGFloat($0) * 4, y: $0 % 2 == 0 ? 6 : 2) })
            ctx.strokePath()
            ctx.setFillColor(color(1))
            for x in [0.0, 8, 16] {
                ctx.addLines(between: [CGPoint(x: x, y: 9.5), CGPoint(x: x + 2.5, y: 12), CGPoint(x: x, y: 14.5), CGPoint(x: x - 2.5, y: 12)])
                ctx.closePath()
                ctx.fillPath()
            }

        case .hearts:
            heart(ctx, at: CGPoint(x: 10, y: 10), size: 5, color(0))
            heart(ctx, at: CGPoint(x: 27, y: 25), size: 6, color(1))
            ctx.setFillColor(color(2))
            ctx.fillEllipse(in: CGRect(x: 26, y: 7, width: 2.2, height: 2.2))
            ctx.fillEllipse(in: CGRect(x: 8, y: 27, width: 2.2, height: 2.2))

        case .gears:
            ctx.setStrokeColor(color(0))
            ctx.setLineWidth(1)
            ctx.addPath(gearPath(CGPoint(x: 15, y: 15), 10, teeth: 8, depth: 2.5))
            ctx.addEllipse(in: CGRect(x: 12, y: 12, width: 6, height: 6))
            ctx.addPath(gearPath(CGPoint(x: 35, y: 34), 7.5, teeth: 6, depth: 2))
            ctx.addEllipse(in: CGRect(x: 33, y: 32, width: 4, height: 4))
            ctx.strokePath()

        case .plaid:
            // Wide bands both ways (darker where they cross), with fine lines through them.
            ctx.setFillColor(color(0).copy(alpha: 0.45)!)
            ctx.fill(CGRect(x: 0, y: 8, width: size, height: 12))
            ctx.fill(CGRect(x: 8, y: 0, width: 12, height: size))
            ctx.setFillColor(color(1 % colors.count))
            ctx.fill(CGRect(x: 0, y: 13.5, width: size, height: 1))
            ctx.fill(CGRect(x: 13.5, y: 0, width: 1, height: size))
            ctx.setFillColor(color(0).copy(alpha: 0.3)!)
            ctx.fill(CGRect(x: 0, y: 1, width: size, height: 2))
            ctx.fill(CGRect(x: 1, y: 0, width: 2, height: size))

        default:
            break
        }
    }

    private static func heart(_ ctx: CGContext, at c: CGPoint, size s: CGFloat, _ color: CGColor) {
        ctx.setFillColor(color)
        ctx.fillEllipse(in: CGRect(x: c.x - s, y: c.y - s / 2, width: s * 1.05, height: s * 1.05))
        ctx.fillEllipse(in: CGRect(x: c.x - s * 0.05, y: c.y - s / 2, width: s * 1.05, height: s * 1.05))
        ctx.addLines(between: [CGPoint(x: c.x - s * 0.96, y: c.y + s * 0.2), CGPoint(x: c.x + s * 0.96, y: c.y + s * 0.2),
                               CGPoint(x: c.x, y: c.y + s * 1.15)])
        ctx.closePath()
        ctx.fillPath()
    }
}

/// A gear's outline: `teeth` flat-topped teeth `depth` deep around radius `r`.
func gearPath(_ c: CGPoint, _ r: CGFloat, teeth n: Int, depth: CGFloat) -> CGPath {
    let p = CGMutablePath()
    let w = CGFloat.pi / CGFloat(n)
    for i in 0..<n {
        let a = 2 * CGFloat.pi * CGFloat(i) / CGFloat(n)
        for (j, (rad, ang)) in [(r - depth, a - 0.55 * w), (r, a - 0.32 * w), (r, a + 0.32 * w), (r - depth, a + 0.55 * w)].enumerated() {
            let pt = CGPoint(x: c.x + rad * cos(ang), y: c.y + rad * sin(ang))
            if i == 0, j == 0 { p.move(to: pt) } else { p.addLine(to: pt) }
        }
    }
    p.closeSubpath()
    return p
}
