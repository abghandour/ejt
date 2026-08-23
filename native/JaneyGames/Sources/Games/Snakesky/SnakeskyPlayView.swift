import SwiftUI

/// The in-round screen: word header, board canvas, and big turn buttons.
struct SnakeskyPlayView: View {
    @Environment(SnakeskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Design.spacing) {
            HStack(spacing: Design.spacing) {
                Button("Quit", systemImage: "xmark", action: quit)
                    .labelStyle(.iconOnly)
                    .padding(8)
                    .glassEffect(.regular.interactive())

                Label("\(game.state?.score ?? 0)", systemImage: "star.fill")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(theme.accent)
                    .contentTransition(.numericText())
                    .animation(Design.snappy, value: game.state?.score)
                    .accessibilityLabel("Score \(game.state?.score ?? 0)")

                Spacer()

                Text("Words: \(game.state?.wordsCompleted ?? 0)")
                    .font(.subheadline)
                    .foregroundStyle(theme.info)
            }
            .padding(.horizontal, Design.padding)

            SnakeWordHeaderView()
            SnakeBoardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Design.padding)

            HStack(spacing: Design.spacing) {
                Button("Turn left", systemImage: "arrow.turn.up.left", action: turnLeft)
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .glassEffect(.regular.interactive())
                Button("Turn right", systemImage: "arrow.turn.up.right", action: turnRight)
                    .labelStyle(.iconOnly)
                    .font(.title)
                    .frame(maxWidth: .infinity, minHeight: 64)
                    .glassEffect(.regular.interactive())
            }
            .padding(.horizontal, Design.padding)
        }
        .padding(.vertical, Design.spacing)
        .frame(maxWidth: Design.maxContentWidth)
    }

    private func quit() {
        game.backToStart()
    }

    private func turnLeft() {
        game.turn(.left)
    }

    private func turnRight() {
        game.turn(.right)
    }
}

/// The current word with eaten/next/pending letter states.
struct SnakeWordHeaderView: View {
    @Environment(SnakeskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 3) {
                ForEach(Array(game.wordDisplay.enumerated()), id: \.offset) { _, display in
                    switch display {
                    case .eaten(let letter):
                        Text(String(letter))
                            .foregroundStyle(theme.successText)
                    case .next(let letter):
                        Text(String(letter))
                            .foregroundStyle(theme.accent)
                            .shadow(color: theme.accentGlow, radius: 8)
                            .scaleEffect(1.15)
                    case .pending(let letter):
                        Text(String(letter))
                            .foregroundStyle(theme.textMuted)
                    case .hidden:
                        Text("?")
                            .foregroundStyle(theme.textMuted)
                    }
                }
            }
            .font(.system(.title, design: .rounded))
            .bold()
            .kerning(3)
            .animation(Design.snappy, value: game.wordDisplay)

            Text(game.translationText)
                .font(.subheadline)
                .foregroundStyle(theme.info)
        }
        .accessibilityElement()
        .accessibilityLabel("Word: \(game.translationText)")
    }
}

/// The 15×15 board, drawn each tick with Canvas.
struct SnakeBoardView: View {
    @Environment(SnakeskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { context, size in
            guard let state = game.state else { return }
            let n = SnakeskyEngine.gridSize
            let cell = min(size.width, size.height) / Double(n)
            let originX = (size.width - cell * Double(n)) / 2
            let originY = (size.height - cell * Double(n)) / 2

            func rect(_ point: SnakeskyEngine.Point, inset: Double = 1) -> CGRect {
                CGRect(
                    x: originX + Double(point.x) * cell + inset,
                    y: originY + Double(point.y) * cell + inset,
                    width: cell - inset * 2,
                    height: cell - inset * 2
                )
            }

            // Board background + border.
            let board = CGRect(x: originX, y: originY, width: cell * Double(n), height: cell * Double(n))
            context.fill(Path(roundedRect: board, cornerRadius: 6), with: .color(theme.bgPrimary.opacity(0.9)))
            context.stroke(
                Path(roundedRect: board, cornerRadius: 6),
                with: .color(theme.accent.opacity(0.25)),
                lineWidth: 1
            )

            // Letter dots.
            let showHint = game.difficulty.showsNextLetterHint
            for dot in state.letterDots {
                let isNext = showHint && dot.index == state.letterProgress
                let dotRect = rect(dot.point)
                context.fill(
                    Path(roundedRect: dotRect, cornerRadius: 3),
                    with: .color(isNext ? theme.accent.opacity(0.15) : theme.tileBorder.opacity(0.18))
                )
                context.draw(
                    Text(String(dot.letter))
                        .font(.system(size: cell * 0.62, weight: .bold, design: .rounded))
                        .foregroundStyle(isNext ? theme.accent : theme.textSecondary),
                    in: dotRect
                )
            }

            // Body then head.
            for segment in state.snake.dropFirst() {
                context.fill(
                    Path(roundedRect: rect(segment, inset: 2), cornerRadius: 3),
                    with: .color(theme.textPrimary.opacity(0.6))
                )
            }
            if let head = state.snake.first {
                let headRect = rect(head, inset: 1)
                context.fill(Path(roundedRect: headRect, cornerRadius: 4), with: .color(theme.accent))
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Snake board")
    }
}
