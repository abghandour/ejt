import SwiftUI

/// Full-screen theme background: base color plus the signature sunburst,
/// slowly rotating unless Reduce Motion is on.
struct ThemedBackground: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            theme.bgPrimary
            if reduceMotion {
                SunburstView(angle: .zero)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                    let seconds = context.date.timeIntervalSinceReferenceDate
                    SunburstView(angle: .degrees(seconds.truncatingRemainder(dividingBy: 360) * 0.6))
                }
            }
        }
        .ignoresSafeArea()
    }
}

private struct SunburstView: View {
    @Environment(\.theme) private var theme
    let angle: Angle

    var body: some View {
        AngularGradient(
            stops: sunburstStops,
            center: .center,
            angle: angle
        )
        .opacity(theme.sunburstOpacity)
        .scaleEffect(3)
    }

    private var sunburstStops: [Gradient.Stop] {
        // 18 hard-edged wedge pairs ≈ repeating-conic-gradient(10deg/10deg).
        var stops: [Gradient.Stop] = []
        let pairCount = 18
        for i in 0..<pairCount {
            let start = Double(i) / Double(pairCount)
            let mid = (Double(i) + 0.5) / Double(pairCount)
            let end = Double(i + 1) / Double(pairCount)
            stops.append(.init(color: theme.sunburst1, location: start))
            stops.append(.init(color: theme.sunburst1, location: mid))
            stops.append(.init(color: theme.sunburst2, location: mid))
            stops.append(.init(color: theme.sunburst2, location: end))
        }
        return stops
    }
}
