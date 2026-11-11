import AppKit
import QuartzCore
import SwiftUI

/// A burst of confetti over a card the moment its agent finishes (Settings → confetti). It fires
/// on the change to done, not for agents that were already done when the card appeared, and
/// never with Reduce Motion.
struct ConfettiOverlay: NSViewRepresentable {
    var state: AgentState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeNSView(context: Context) -> ConfettiView { ConfettiView(state: state) }
    func updateNSView(_ view: ConfettiView, context: Context) { view.update(state, still: reduceMotion) }
}

final class ConfettiView: NSView {
    private var last: AgentState

    init(state: AgentState) {
        last = state
        super.init(frame: .zero)
        wantsLayer = true
        layer?.masksToBounds = false
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

    override var isFlipped: Bool { true }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }

    func update(_ state: AgentState, still: Bool) {
        defer { last = state }
        guard state == .ready, last != .ready, !still, window != nil, bounds.width > 0 else { return }
        burst()
    }

    private func burst() {
        guard let root = layer else { return }
        let emitter = CAEmitterLayer()
        emitter.frame = bounds
        emitter.emitterShape = .line
        emitter.emitterPosition = CGPoint(x: bounds.midX, y: bounds.maxY - 4)
        emitter.emitterSize = CGSize(width: bounds.width * 0.6, height: 1)
        let colors = ["#FF4D6D", "#FFD23F", "#3DDC97", "#4DA6FF", "#B07CFF", "#FF9F43"]
        emitter.emitterCells = colors.enumerated().map { i, hex in
            let cell = CAEmitterCell()
            cell.contents = i % 2 == 0 ? Self.strip : Self.square
            cell.color = NSColor(hex: hex)!.cgColor
            cell.birthRate = 28
            cell.lifetime = 2.6
            cell.velocity = max(110, bounds.height * 2.2)
            cell.velocityRange = 50
            // Up (this view is flipped), fanning out, then falling and tumbling.
            cell.emissionLongitude = -.pi / 2
            cell.emissionRange = 0.7
            cell.yAcceleration = 260
            cell.spin = 4
            cell.spinRange = 8
            cell.scale = 0.5
            cell.scaleRange = 0.2
            cell.alphaSpeed = -0.3
            return cell
        }
        emitter.beginTime = CACurrentMediaTime()
        root.addSublayer(emitter)
        // One short pop, then let it fall and clear away.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { emitter.birthRate = 0 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.2) { emitter.removeFromSuperlayer() }
    }

    private static func image(width: Int, height: Int) -> CGImage? {
        guard let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                  space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        ctx.setFillColor(CGColor(gray: 1, alpha: 1))
        ctx.fill(CGRect(x: 0, y: 0, width: width, height: height))
        return ctx.makeImage()
    }

    private static let strip = image(width: 8, height: 18)
    private static let square = image(width: 12, height: 12)
}
