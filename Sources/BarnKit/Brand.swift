import AppKit
import SwiftUI

/// barn's look: electric blue, grain, a little whimsy. Lowercase everywhere.
enum Brand {
    static let name = "barn"

    static let ink = NSColor(srgbRed: 0.09, green: 0.07, blue: 0.55, alpha: 1)      // #17128C
    static let electric = NSColor(srgbRed: 0.20, green: 0.30, blue: 1.00, alpha: 1) // #334DFF
    static let sky = NSColor(srgbRed: 0.55, green: 0.70, blue: 1.00, alpha: 1)      // #8CB3FF
    static let coral = NSColor(srgbRed: 1.00, green: 0.36, blue: 0.38, alpha: 1)    // #FF5C61
    static let butter = NSColor(srgbRed: 1.00, green: 0.84, blue: 0.30, alpha: 1)   // #FFD64D
    static let mint = NSColor(srgbRed: 0.24, green: 0.86, blue: 0.60, alpha: 1)     // #3DDB99
    static let cream = NSColor(srgbRed: 1.00, green: 0.97, blue: 0.92, alpha: 1)    // #FFF7EB

    static var blue: Color { Color(nsColor: electric) }

    /// Tileable film grain, generated once.
    static let grain: NSImage = {
        let size = 192
        var rng = SystemRandomNumberGenerator()
        var pixels = [UInt8](repeating: 0, count: size * size * 4)
        for i in 0..<(size * size) {
            let v = UInt8.random(in: 0...255, using: &rng)
            pixels[i * 4] = v
            pixels[i * 4 + 1] = v
            pixels[i * 4 + 2] = v
            pixels[i * 4 + 3] = 255
        }
        let cs = CGColorSpaceCreateDeviceRGB()
        let ctx = CGContext(data: &pixels, width: size, height: size, bitsPerComponent: 8, bytesPerRow: size * 4,
                            space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        return NSImage(cgImage: ctx.makeImage()!, size: NSSize(width: size / 2, height: size / 2))
    }()
}

/// Film grain over whatever is underneath.
struct Grain: View {
    var opacity: Double = 0.16

    var body: some View {
        Image(nsImage: Brand.grain)
            .resizable(resizingMode: .tile)
            .blendMode(.overlay)
            .opacity(opacity)
            .allowsHitTesting(false)
    }
}

/// The signature backdrop: a soft blue mesh with a coral/butter glow, plus grain.
struct BrandBackdrop: View {
    var body: some View {
        ZStack {
            if #available(macOS 15, *) {
                MeshGradient(width: 3, height: 3, points: [
                    [0, 0], [0.55, 0], [1, 0],
                    [0, 0.5], [0.42, 0.58], [1, 0.42],
                    [0, 1], [0.6, 1], [1, 1],
                ], colors: [
                    Color(nsColor: Brand.ink), Color(nsColor: Brand.electric), Color(nsColor: Brand.sky),
                    Color(nsColor: Brand.electric), Color(nsColor: Brand.electric), Color(nsColor: Brand.coral).opacity(0.9),
                    Color(nsColor: Brand.ink), Color(nsColor: Brand.electric), Color(nsColor: Brand.butter),
                ])
            } else {
                LinearGradient(colors: [Color(nsColor: Brand.ink), Color(nsColor: Brand.electric), Color(nsColor: Brand.coral)],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            }
            Grain(opacity: 0.22)
        }
    }
}

/// Lowercase rounded wordmark.
struct Wordmark: View {
    var size: CGFloat = 28

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: size * 0.08) {
            Text(Brand.name)
                .font(.system(size: size, weight: .heavy, design: .rounded))
                .tracking(-size * 0.03)
            Circle()
                .fill(Color(nsColor: Brand.butter))
                .frame(width: size * 0.22, height: size * 0.22)
        }
    }
}

extension Brand {
    /// Template menu-bar glyph (shown when no agents are running).
    static func menuBarGlyph() -> NSImage {
        let size = NSSize(width: 18, height: 16)
        let image = NSImage(size: size, flipped: true) { _ in
            let path = NSBezierPath()
            path.lineJoinStyle = .round
            path.lineWidth = 1.6
            path.move(to: NSPoint(x: 2.5, y: 7))
            path.line(to: NSPoint(x: 9, y: 1.8))
            path.line(to: NSPoint(x: 15.5, y: 7))
            path.line(to: NSPoint(x: 15.5, y: 14.2))
            path.line(to: NSPoint(x: 2.5, y: 14.2))
            path.close()
            NSColor.black.setStroke()
            path.stroke()
            NSColor.black.setFill()
            for (x, y) in [(6.2, 8.4), (9.8, 8.4), (6.2, 11.4), (9.8, 11.4)] {
                NSBezierPath(roundedRect: NSRect(x: x, y: y, width: 2.2, height: 2.2), xRadius: 0.6, yRadius: 0.6).fill()
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
