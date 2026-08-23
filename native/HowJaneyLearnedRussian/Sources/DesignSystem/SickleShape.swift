import SwiftUI

/// A Soviet sickle, drawn in a 100×100 design space: crescent blade with a
/// short handle angled down-right. Fills with the current foreground style.
struct SickleShape: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 100
        var path = Path()

        // Crescent blade opening to the right: outer edge sweeps bottom → left
        // → top; a right-shifted inner circle carves the hollow, leaving a
        // thick spine on the left and pointed tips top-right / bottom-right.
        path.addArc(
            center: CGPoint(x: 46, y: 42),
            radius: 34,
            startAngle: .degrees(55),
            endAngle: .degrees(305),
            clockwise: false
        )
        path.addArc(
            center: CGPoint(x: 54, y: 42),
            radius: 25,
            startAngle: .degrees(300),
            endAngle: .degrees(60),
            clockwise: true
        )
        path.closeSubpath()

        // Handle: rounded bar continuing from the lower blade tip, down-right.
        let handle = CGRect(x: -5.5, y: -4, width: 11, height: 36)
        let handleTransform = CGAffineTransform(translationX: 66, y: 68)
            .rotated(by: -.pi / 4)
        path.addRoundedRect(
            in: handle,
            cornerSize: CGSize(width: 5.5, height: 5.5),
            transform: handleTransform
        )

        let fit = CGAffineTransform(translationX: rect.minX, y: rect.minY)
            .scaledBy(x: scale, y: scale)
        return path.applying(fit)
    }
}

/// Game icon that renders the custom sickle for Slashsky and SF Symbols for
/// everything else.
struct GameIconView: View {
    let game: GameID
    let size: Double

    var body: some View {
        if game == .slashsky {
            SickleShape()
                .frame(width: size, height: size)
                .accessibilityLabel("Sickle")
        } else {
            Image(systemName: game.symbol)
                .font(.system(size: size * 0.9))
        }
    }
}
