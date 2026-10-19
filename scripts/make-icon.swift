// Renders barn's app icon: grainy electric-blue gradient + a white barn with four status
// windows. Usage: swift scripts/make-icon.swift <out.png>
import AppKit

let S: CGFloat = 1024
let out = CommandLine.arguments.dropFirst().first ?? "icon.png"
let cs = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                    space: cs, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!

func rgb(_ hex: UInt32, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: a)
}

// macOS icon grid: 824pt rounded square centered in 1024.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tilePath = CGPath(roundedRect: tile, cornerWidth: 186, cornerHeight: 186, transform: nil)

// Drop shadow under the tile.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 36, color: rgb(0x0A0640, 0.45))
ctx.addPath(tilePath)
ctx.setFillColor(rgb(0x334DFF))
ctx.fillPath()
ctx.restoreGState()

ctx.saveGState()
ctx.addPath(tilePath)
ctx.clip()

// Base: deep ink → electric blue.
let base = CGGradient(colorsSpace: cs, colors: [rgb(0x17128C), rgb(0x334DFF), rgb(0x5C7BFF)] as CFArray,
                      locations: [0, 0.55, 1])!
ctx.drawLinearGradient(base, start: CGPoint(x: tile.minX, y: tile.minY), end: CGPoint(x: tile.maxX, y: tile.maxY), options: [])

// Soft glows: coral bottom-right, butter low-left, sky highlight top-left.
func glow(_ c: CGPoint, _ r: CGFloat, _ color: UInt32, _ a: CGFloat) {
    let g = CGGradient(colorsSpace: cs, colors: [rgb(color, a), rgb(color, 0)] as CFArray, locations: [0, 1])!
    ctx.drawRadialGradient(g, startCenter: c, startRadius: 0, endCenter: c, endRadius: r, options: [])
}
glow(CGPoint(x: 860, y: 190), 520, 0xFF5C61, 0.85)
glow(CGPoint(x: 230, y: 160), 300, 0xFFD64D, 0.55)
glow(CGPoint(x: 260, y: 860), 420, 0x8CB3FF, 0.55)

// The barn: rounded pentagon.
let barn = CGMutablePath()
let left: CGFloat = 268, right: CGFloat = 756, bottom: CGFloat = 250, eave: CGFloat = 560, peak: CGFloat = 790
barn.move(to: CGPoint(x: left, y: bottom))
barn.addLine(to: CGPoint(x: left, y: eave))
barn.addLine(to: CGPoint(x: 512, y: peak))
barn.addLine(to: CGPoint(x: right, y: eave))
barn.addLine(to: CGPoint(x: right, y: bottom))
barn.closeSubpath()
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 30, color: rgb(0x0A0640, 0.35))
ctx.addPath(barn)
ctx.setLineJoin(.round)
ctx.setLineWidth(70)
ctx.setStrokeColor(rgb(0xFFF7EB))
ctx.setFillColor(rgb(0xFFF7EB))
ctx.drawPath(using: .fillStroke)
ctx.restoreGState()

// Four status windows.
let w: CGFloat = 112, gap: CGFloat = 34
let ox = 512 - w - gap / 2, oy: CGFloat = 278
let colors: [UInt32] = [0x334DFF, 0xFF5C61, 0x3DDB99, 0xFFD64D]
for (i, color) in colors.enumerated() {
    let col = CGFloat(i % 2), row = CGFloat(1 - i / 2)
    let r = CGRect(x: ox + col * (w + gap), y: oy + row * (w + gap), width: w, height: w)
    ctx.addPath(CGPath(roundedRect: r, cornerWidth: 30, cornerHeight: 30, transform: nil))
    ctx.setFillColor(rgb(color))
    ctx.fillPath()
}

// Film grain.
var rng = SystemRandomNumberGenerator()
for _ in 0..<160_000 {
    let x = CGFloat.random(in: tile.minX...tile.maxX, using: &rng)
    let y = CGFloat.random(in: tile.minY...tile.maxY, using: &rng)
    let light = Bool.random(using: &rng)
    ctx.setFillColor(light ? rgb(0xFFFFFF, 0.07) : rgb(0x000000, 0.08))
    ctx.fill(CGRect(x: x, y: y, width: 1.6, height: 1.6))
}
ctx.restoreGState()

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: out))
print("wrote \(out)")
