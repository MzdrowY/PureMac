import AppKit
import SwiftUI

/// One-shot confetti burst. Wraps a `CAEmitterLayer` so the particles run on
/// Core Animation rather than burning a SwiftUI render pass per frame. Use
/// `ConfettiView(trigger: someBool)` and flip `trigger` to fire. The emitter
/// produces a short burst (~1.2s of emission, ~2.5s for particles to fall)
/// then quiets itself so it doesn't keep churning if the view stays alive.
struct ConfettiView: NSViewRepresentable {
    /// Flip this to fire a new burst. Each rising edge fires once.
    let trigger: Bool

    final class Coordinator {
        var lastTrigger = false
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSView {
        let host = HostingView()
        // wantsLayer alone gives AppKit a properly-scaled CALayer with the
        // window's backing-store scale. Assigning a bare CALayer here would
        // overwrite that and render particles at 1x on Retina displays.
        host.wantsLayer = true
        return host
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        if trigger && !context.coordinator.lastTrigger {
            (nsView as? HostingView)?.fire()
        }
        context.coordinator.lastTrigger = trigger
    }

    // MARK: - Host
    /// Subclass so we can capture bounds for emitter geometry.
    final class HostingView: NSView {
        override var isFlipped: Bool { true }

        func fire() {
            guard let layer = self.layer else { return }
            let emitter = CAEmitterLayer()
            emitter.emitterPosition = CGPoint(x: bounds.midX, y: -10)
            emitter.emitterSize = CGSize(width: bounds.width, height: 1)
            emitter.emitterShape = .line
            emitter.beginTime = CACurrentMediaTime()
            emitter.birthRate = 1.0
            emitter.emitterCells = makeCells()
            layer.addSublayer(emitter)

            // Stop emission after a short burst — particles already in flight
            // continue falling and clean up via removeFromSuperlayer below.
            // The `[weak self, weak emitter]` capture lets a torn-down view
            // skip the work entirely so we don't keep allocating particles
            // against an orphaned layer.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { [weak self, weak emitter] in
                guard self?.window != nil else {
                    emitter?.removeFromSuperlayer()
                    return
                }
                emitter?.birthRate = 0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) { [weak emitter] in
                emitter?.removeFromSuperlayer()
            }
        }

        private func makeCells() -> [CAEmitterCell] {
            let colors: [NSColor] = [
                NSColor(srgbRed: 0.04, green: 0.52, blue: 1.00, alpha: 1),
                NSColor(srgbRed: 0.18, green: 0.78, blue: 0.47, alpha: 1),
                NSColor(srgbRed: 1.00, green: 0.58, blue: 0.04, alpha: 1),
                NSColor(srgbRed: 0.55, green: 0.32, blue: 0.87, alpha: 1),
                NSColor(srgbRed: 1.00, green: 0.30, blue: 0.50, alpha: 1),
                NSColor(srgbRed: 1.00, green: 0.78, blue: 0.04, alpha: 1),
            ]
            return colors.map { color in
                let cell = CAEmitterCell()
                cell.contents = Self.particleImage().cgImage(
                    forProposedRect: nil, context: nil, hints: nil
                )
                cell.color = color.cgColor
                cell.birthRate = 16
                cell.lifetime = 6.0
                cell.lifetimeRange = 1.0
                cell.velocity = 220
                cell.velocityRange = 90
                cell.yAcceleration = 240
                cell.xAcceleration = 0
                cell.emissionLongitude = .pi / 2          // straight down
                cell.emissionRange = .pi / 5
                cell.spin = 4
                cell.spinRange = 6
                cell.scale = 0.35
                cell.scaleRange = 0.20
                cell.alphaSpeed = -0.35                    // fade as they fall
                return cell
            }
        }

        /// Tiny rectangle PNG used as the particle texture. Keeping the image
        /// procedural means we don't ship an asset just for confetti.
        private static func particleImage() -> NSImage {
            let size = NSSize(width: 10, height: 14)
            let image = NSImage(size: size)
            image.lockFocus()
            NSColor.white.setFill()
            let path = NSBezierPath(roundedRect: NSRect(origin: .zero, size: size),
                                    xRadius: 1.5, yRadius: 1.5)
            path.fill()
            image.unlockFocus()
            return image
        }
    }
}
