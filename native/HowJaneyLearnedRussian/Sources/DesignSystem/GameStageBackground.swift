import SwiftUI

/// Gives each game a recognizable playfield before its mechanics appear.
/// The marks are decorative, intentionally low-contrast, and never intercept
/// input or compete with the game board.
struct GameStageBackground: View {
    let game: GameID
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drifting = false

    var body: some View {
        ZStack {
            ThemedBackground()
            GameStageMotif(game: game)
                .rotationEffect(.degrees(drifting ? 1.5 : -1.5))
                .offset(y: drifting ? -4 : 4)
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.2).repeatForever(autoreverses: true)) {
                drifting = true
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct GameStageMotif: View {
    let game: GameID
    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { context, size in
            let ink = theme.textPrimary.opacity(theme.isDark ? 0.15 : 0.09)
            let accent = theme.accent.opacity(theme.isDark ? 0.18 : 0.13)
            let width = size.width
            let height = size.height

            switch game {
            case .bogglesky:
                for row in 0..<6 {
                    for column in 0..<5 {
                        let side = min(width, height) * 0.09
                        let x = width * 0.10 + CGFloat(column) * side * 1.28
                        let y = height * 0.17 + CGFloat(row) * side * 1.28
                        let rect = CGRect(x: x, y: y, width: side, height: side)
                        context.stroke(
                            Path(roundedRect: rect, cornerRadius: side * 0.18),
                            with: .color((row + column).isMultiple(of: 2) ? accent : ink),
                            lineWidth: 1.5
                        )
                    }
                }

            case .scramblisky:
                for index in 0..<8 {
                    let side = width * 0.16
                    let x = width * 0.06 + CGFloat(index % 3) * side * 1.6
                    let y = height * 0.20 + CGFloat(index / 3) * side * 1.05
                    let rect = CGRect(x: x, y: y, width: side, height: side * 0.7)
                    context.fill(Path(roundedRect: rect, cornerRadius: 8), with: .color(index.isMultiple(of: 2) ? accent : ink))
                }

            case .rootsky, .wordsky:
                let origin = CGPoint(x: width * 0.78, y: height * 0.83)
                for branch in 0..<8 {
                    let angle = Double(branch) * .pi / 7 + .pi
                    let endpoint = CGPoint(
                        x: origin.x + cos(angle) * width * (0.20 + Double(branch % 3) * 0.06),
                        y: origin.y + sin(angle) * height * (0.16 + Double(branch % 2) * 0.08)
                    )
                    var path = Path()
                    path.move(to: origin)
                    path.addCurve(
                        to: endpoint,
                        control1: CGPoint(x: origin.x - width * 0.07, y: origin.y - height * 0.10),
                        control2: CGPoint(x: endpoint.x + width * 0.05, y: endpoint.y + height * 0.06)
                    )
                    context.stroke(path, with: .color(branch.isMultiple(of: 2) ? accent : ink), lineWidth: 2)
                }

            case .triviatsky:
                for index in 0..<5 {
                    let rect = CGRect(
                        x: width * (0.08 + Double(index) * 0.09),
                        y: height * (0.14 + Double(index) * 0.07),
                        width: width * 0.58,
                        height: height * 0.11
                    )
                    context.stroke(
                        Path(roundedRect: rect, cornerRadius: 14),
                        with: .color(index.isMultiple(of: 2) ? accent : ink),
                        lineWidth: 1
                    )
                }

            case .snakesky:
                for index in 0..<18 {
                    let x = width * (0.04 + Double(index) * 0.06)
                    let y = height * (0.20 + 0.08 * sin(Double(index) * 0.72))
                    let rect = CGRect(x: x, y: y, width: 11, height: 11)
                    context.fill(Path(ellipseIn: rect), with: .color(index.isMultiple(of: 3) ? accent : ink))
                }

            case .slashsky:
                for index in 0..<7 {
                    let start = CGPoint(x: width * (0.08 + Double(index) * 0.13), y: height * 0.18)
                    let end = CGPoint(x: start.x + width * 0.30, y: start.y + height * 0.19)
                    var path = Path()
                    path.move(to: start)
                    path.addLine(to: end)
                    context.stroke(path, with: .color(index.isMultiple(of: 2) ? accent : ink), lineWidth: 3)
                }

            case .tetrisky:
                for row in 0..<8 {
                    for column in 0..<6 where (row + column).isMultiple(of: 3) {
                        let side = min(width, height) * 0.075
                        let rect = CGRect(
                            x: width * 0.08 + CGFloat(column) * side * 1.1,
                            y: height * 0.15 + CGFloat(row) * side * 1.1,
                            width: side,
                            height: side
                        )
                        context.fill(Path(rect), with: .color((row + column).isMultiple(of: 2) ? accent : ink))
                    }
                }

            case .meddleysky:
                let center = CGPoint(x: width * 0.73, y: height * 0.26)
                for index in 0..<7 {
                    let radius = CGFloat(index + 1) * min(width, height) * 0.045
                    context.stroke(
                        Path(ellipseIn: CGRect(
                            x: center.x - radius,
                            y: center.y - radius,
                            width: radius * 2,
                            height: radius * 2
                        )),
                        with: .color(index.isMultiple(of: 2) ? accent : ink),
                        lineWidth: 1.5
                    )
                }
            }
        }
        .ignoresSafeArea()
    }
}
