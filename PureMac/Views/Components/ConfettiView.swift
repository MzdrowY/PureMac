import SwiftUI

/// Tasteful one-shot confetti, redesigned away from the old harsh CAEmitter
/// rectangles. A `Canvas` + `TimelineView` particle system: mixed shapes
/// (streamers, discs, rings), a soft brand palette, gentle gravity with a
/// little horizontal sway, a 3D-style tumble, and a graceful fade. Fire with
/// `ConfettiView(trigger:)` — each rising edge fires one burst that quiets
/// itself. Honors Reduce Motion (renders nothing).
struct ConfettiView: View {
    /// Flip to fire a burst. Each rising edge fires once.
    let trigger: Bool

    @State private var particles: [Particle] = []
    @State private var start: Date?
    @State private var generation = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let duration: TimeInterval = 2.6

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: start == nil)) { timeline in
                Canvas { ctx, size in
                    guard let start else { return }
                    let t = timeline.date.timeIntervalSince(start)
                    guard t <= duration else { return }
                    for p in particles {
                        draw(p, at: t, in: size, ctx: &ctx)
                    }
                }
            }
            // The parent flips `trigger` (via .toggle()) as a fire pulse, so a
            // burst should play on ANY change — not just the rising edge, which
            // would skip every other cleanup.
            .onChange(of: trigger) { _ in
                fire(in: geo.size)
            }
            .allowsHitTesting(false)
        }
    }

    private func fire(in size: CGSize) {
        guard !reduceMotion, size.width > 0 else { return }
        particles = (0..<90).map { _ in Particle.random(width: size.width) }
        start = Date()
        generation += 1
        let g = generation
        // Quiet the timeline once the burst has fully faded so we don't keep
        // re-rendering an empty canvas. Guard on `generation` so a later burst
        // isn't cut short by an earlier burst's cleanup timer.
        DispatchQueue.main.asyncAfter(deadline: .now() + duration + 0.1) {
            guard generation == g else { return }
            start = nil
            particles = []
        }
    }

    private func draw(_ p: Particle, at t: Double, in size: CGSize, ctx: inout GraphicsContext) {
        // Vertical: initial downward velocity + gravity. Horizontal: drift +
        // a sine sway so pieces flutter instead of dropping like stones.
        let x = p.x0 + p.drift * t + p.swayAmp * sin(p.swayFreq * t + p.phase)
        let y = p.y0 + p.vy0 * t + 0.5 * p.gravity * t * t

        guard y < size.height + 40 else { return }

        let fade: Double
        if t > p.fadeStart {
            fade = max(0, 1 - (t - p.fadeStart) / (duration - p.fadeStart))
        } else {
            fade = 1
        }
        guard fade > 0.01 else { return }

        let angle = p.spin * t
        // Tumble: squash one axis on a cosine so pieces appear to flip in 3D.
        let tumble = abs(cos(p.tumbleSpeed * t + p.phase))
        let w = p.size.width * (0.25 + 0.75 * tumble)
        let h = p.size.height

        var sub = ctx
        sub.translateBy(x: x, y: y)
        sub.rotate(by: .radians(angle))
        sub.opacity = fade

        let rect = CGRect(x: -w / 2, y: -h / 2, width: w, height: h)
        switch p.shape {
        case .streamer:
            sub.fill(Path(roundedRect: rect, cornerRadius: min(w, h) * 0.45), with: .color(p.color))
        case .disc:
            sub.fill(Path(ellipseIn: CGRect(x: -h / 2, y: -h / 2, width: h, height: h)), with: .color(p.color))
        case .ring:
            let r = h / 2
            let ring = Path(ellipseIn: CGRect(x: -r, y: -r, width: h, height: h))
            sub.stroke(ring, with: .color(p.color), lineWidth: max(1.4, h * 0.22))
        }
    }
}

private enum ConfettiShape: CaseIterable { case streamer, disc, ring }

private struct Particle {
    var x0: CGFloat
    var y0: CGFloat
    var vy0: Double
    var gravity: Double
    var drift: Double
    var swayAmp: Double
    var swayFreq: Double
    var phase: Double
    var spin: Double
    var tumbleSpeed: Double
    var fadeStart: Double
    var color: Color
    var size: CGSize
    var shape: ConfettiShape

    /// Soft, slightly desaturated brand palette — premium, not garish.
    static let palette: [Color] = [
        Color(red: 0.27, green: 0.56, blue: 1.00),  // blue
        Color(red: 0.30, green: 0.80, blue: 0.56),  // green
        Color(red: 1.00, green: 0.66, blue: 0.30),  // amber
        Color(red: 0.62, green: 0.45, blue: 0.92),  // purple
        Color(red: 1.00, green: 0.46, blue: 0.62),  // pink
        Color(red: 0.36, green: 0.80, blue: 0.94),  // cyan
    ]

    static func random(width: CGFloat) -> Particle {
        let shape = ConfettiShape.allCases.randomElement()!
        let dim: CGSize
        switch shape {
        case .streamer: dim = CGSize(width: .random(in: 5...8), height: .random(in: 11...16))
        case .disc:     dim = CGSize(width: 9, height: .random(in: 7...10))
        case .ring:     dim = CGSize(width: 10, height: .random(in: 9...13))
        }
        return Particle(
            x0: .random(in: 0...width),
            y0: .random(in: -60 ... -10),
            vy0: .random(in: 90...170),
            gravity: .random(in: 130...210),
            drift: .random(in: -40...40),
            swayAmp: .random(in: 8...26),
            swayFreq: .random(in: 1.4...3.0),
            phase: .random(in: 0...(2 * .pi)),
            spin: .random(in: -5...5),
            tumbleSpeed: .random(in: 2.5...5.5),
            fadeStart: .random(in: 1.3...1.9),
            color: palette.randomElement()!,
            size: dim,
            shape: shape
        )
    }
}
