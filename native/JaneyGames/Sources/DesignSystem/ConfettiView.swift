import SwiftUI

/// Full-screen confetti celebration (~3s), ported from the web canvas version:
/// falling rectangles with wobble, spin, gravity, and a fade-out tail.
/// Re-fires whenever `trigger` changes; renders nothing otherwise.
struct ConfettiView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: Int
    @State private var firedAt: Date?

    private static let duration = 3.0

    private struct Piece {
        let x: Double
        let startY: Double
        let width: Double
        let height: Double
        let hue: Double
        let velocityX: Double
        let velocityY: Double
        let spin: Double
        let wobblePhase: Double
        let wobbleSpeed: Double
    }

    var body: some View {
        Group {
            if let firedAt, !reduceMotion {
                TimelineView(.animation) { timeline in
                    Canvas { context, size in
                        let t = timeline.date.timeIntervalSince(firedAt)
                        guard t < Self.duration else { return }
                        let fade = t > Self.duration * 0.7
                            ? 1 - (t - Self.duration * 0.7) / (Self.duration * 0.3)
                            : 1.0
                        for piece in pieces(width: size.width, height: size.height) {
                            let wobble = sin(piece.wobblePhase + t * piece.wobbleSpeed) * 24
                            let x = piece.x + piece.velocityX * t + wobble
                            let y = piece.startY + piece.velocityY * t + 90 * t * t
                            guard y > -30, y < size.height + 30 else { continue }
                            var ctx = context
                            ctx.translateBy(x: x, y: y)
                            ctx.rotate(by: .radians(piece.spin * t))
                            ctx.opacity = fade
                            ctx.fill(
                                Path(CGRect(x: -piece.width / 2, y: -piece.height / 2, width: piece.width, height: piece.height)),
                                with: .color(Color(hue: piece.hue, saturation: 0.75, brightness: 0.95))
                            )
                        }
                    }
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }
        }
        .onChange(of: trigger) {
            guard trigger > 0 else { return }
            firedAt = .now
            Task {
                try? await Task.sleep(for: .seconds(Self.duration + 0.1))
                if let firedAt, Date.now.timeIntervalSince(firedAt) >= Self.duration {
                    self.firedAt = nil
                }
            }
        }
    }

    private func pieces(width: Double, height: Double) -> [Piece] {
        var rng = SeedEngine(seed: trigger &* 104_729)
        return (0..<110).map { _ in
            Piece(
                x: rng.next() * width,
                startY: -20 - rng.next() * height * 0.4,
                width: 6 + rng.next() * 8,
                height: 4 + rng.next() * 6,
                hue: rng.next(),
                velocityX: (rng.next() - 0.5) * 120,
                velocityY: 90 + rng.next() * 150,
                spin: (rng.next() - 0.5) * 8,
                wobblePhase: rng.next() * .pi * 2,
                wobbleSpeed: 2 + rng.next() * 3
            )
        }
    }
}
