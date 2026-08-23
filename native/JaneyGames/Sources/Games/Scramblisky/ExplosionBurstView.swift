import SwiftUI

/// Radial spark burst from the center of its bounds while tiles blast away.
/// `hueDegrees` picks the spark palette (gold by default, red for danger).
struct ExplosionBurstView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: Int
    var hueDegrees: ClosedRange<Double> = 30...60
    @State private var start: Date = .now

    private static let lifetime = 0.6

    private struct Spark {
        let angle: Double
        let speed: Double
        let size: Double
        let hue: Double
    }

    private var sparks: [Spark] {
        var rng = SeedEngine(seed: trigger &* 12_289)
        return (0..<26).map { _ in
            Spark(
                angle: rng.next() * 2 * .pi,
                speed: 80 + rng.next() * 140,
                size: 3 + rng.next() * 5,
                hue: (hueDegrees.lowerBound + rng.next() * (hueDegrees.upperBound - hueDegrees.lowerBound)) / 360
            )
        }
    }

    var body: some View {
        if reduceMotion {
            EmptyView()
        } else {
            let items = sparks
            TimelineView(.animation) { timeline in
                Canvas { context, size in
                    let t = timeline.date.timeIntervalSince(start)
                    guard t < Self.lifetime else { return }
                    let center = CGPoint(x: size.width / 2, y: size.height / 2)
                    for spark in items {
                        let progress = t / Self.lifetime
                        let x = center.x + cos(spark.angle) * spark.speed * t
                        let y = center.y + sin(spark.angle) * spark.speed * t + 60 * t * t
                        context.opacity = 1 - progress
                        context.fill(
                            Path(ellipseIn: CGRect(x: x - spark.size / 2, y: y - spark.size / 2, width: spark.size, height: spark.size)),
                            with: .color(Color(hue: spark.hue, saturation: 0.8, brightness: 0.85))
                        )
                    }
                }
            }
            .allowsHitTesting(false)
            .onChange(of: trigger, initial: true) {
                start = .now
            }
        }
    }
}
