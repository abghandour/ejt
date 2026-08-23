import SwiftUI

/// Short-lived confetti burst rising from each tile of a found word,
/// mirroring the web particle effect (upward launch, gravity, fade).
struct ParticleBurstView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let burst: BoggleskyModel.Burst
    let geometry: BoggleGridGeometry

    private static let lifetime = 0.7

    private struct Particle {
        let origin: CGPoint
        let velocityX: Double
        let velocityY: Double
        let size: Double
        let hue: Double
        let lifetime: Double
    }

    private var particles: [Particle] {
        var rng = SeedEngine(seed: burst.id &* 7_919)
        var result: [Particle] = []
        for cell in burst.cells {
            let center = geometry.center(of: cell)
            for _ in 0..<3 {
                result.append(
                    Particle(
                        origin: center,
                        velocityX: (rng.next() - 0.5) * 240,
                        velocityY: -80 - rng.next() * 160,
                        size: 3 + rng.next() * 4,
                        hue: (30 + rng.next() * 30) / 360,
                        lifetime: Self.lifetime * (0.7 + rng.next() * 0.3)
                    )
                )
            }
        }
        return result
    }

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            let items = particles
            let start = Date.now
            TimelineView(.animation) { timeline in
                Canvas { context, _ in
                    let t = timeline.date.timeIntervalSince(start)
                    for particle in items where t < particle.lifetime {
                        let progress = t / particle.lifetime
                        let x = particle.origin.x + particle.velocityX * t
                        let y = particle.origin.y + particle.velocityY * t + 320 * t * t
                        let rect = CGRect(
                            x: x - particle.size / 2,
                            y: y - particle.size / 2,
                            width: particle.size,
                            height: particle.size
                        )
                        context.opacity = 1 - progress
                        context.fill(
                            Path(ellipseIn: rect),
                            with: .color(Color(hue: particle.hue, saturation: 0.8, brightness: 0.85))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
        }
    }
}
