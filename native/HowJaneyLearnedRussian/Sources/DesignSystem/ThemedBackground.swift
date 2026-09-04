import SwiftUI

/// Full-screen theme background: base color plus the signature sunburst,
/// slowly rotating unless Reduce Motion is on.
struct ThemedBackground: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            theme.bgPrimary
            if theme.background == .wedge {
                WedgeBackground()
            } else if reduceMotion {
                SunburstView(angle: .zero)
            } else {
                TimelineView(.animation(minimumInterval: 1 / 20)) { context in
                    let seconds = context.date.timeIntervalSinceReferenceDate
                    SunburstView(angle: .degrees((seconds * 0.6).truncatingRemainder(dividingBy: 360)))
                }
            }
        }
        .ignoresSafeArea()
    }
}

/// Flat cut-paper collage: a grey diagonal band sweeping from the top edge
/// down to the trailing side, plus a black flag in the top-leading corner.
private struct WedgeBackground: View {
    @Environment(\.theme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                Path { p in
                    p.move(to: CGPoint(x: w * 0.72, y: 0))
                    p.addLine(to: CGPoint(x: w, y: 0))
                    p.addLine(to: CGPoint(x: w, y: h * 0.68))
                    p.addLine(to: CGPoint(x: w * 0.12, y: h))
                    p.addLine(to: CGPoint(x: w * 0.02, y: h))
                    p.closeSubpath()
                }
                .fill(theme.sunburst1)

                // Keep the flag below the status bar so the clock stays legible.
                let top = proxy.safeAreaInsets.top
                Path { p in
                    p.move(to: CGPoint(x: 0, y: top))
                    p.addLine(to: CGPoint(x: w * 0.30, y: top))
                    p.addLine(to: CGPoint(x: w * 0.26, y: top + h * 0.045))
                    p.addLine(to: CGPoint(x: 0, y: top + h * 0.09))
                    p.closeSubpath()
                }
                .fill(theme.sunburst2)
            }
        }
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
