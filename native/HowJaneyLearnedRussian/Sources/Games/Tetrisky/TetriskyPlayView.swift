import SwiftUI

/// The in-round screen: target word, board canvas, movement controls, swipes.
struct TetriskyPlayView: View {
    @Environment(TetriskyModel.self) private var game
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

            TetriskyTargetView()

            TetriskyBoardView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, Design.padding)
                .gesture(swipeGesture)

            HStack(spacing: Design.spacing) {
                Button("Move left", systemImage: "arrow.left", action: game.moveLeft)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .glassEffect(.regular.interactive())
                Button("Drop", systemImage: "arrow.down.to.line", action: game.hardDrop)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .glassEffect(.regular.tint(theme.accentGlow).interactive())
                Button("Move right", systemImage: "arrow.right", action: game.moveRight)
                    .labelStyle(.iconOnly)
                    .font(.title2)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .glassEffect(.regular.interactive())
            }
            .padding(.horizontal, Design.padding)
        }
        .padding(.vertical, Design.spacing)
        .frame(maxWidth: Design.maxContentWidth)
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 20)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                if abs(dy) > abs(dx), dy > 0 {
                    game.hardDrop()
                } else if abs(dx) > abs(dy) {
                    if dx < 0 { game.moveLeft() } else { game.moveRight() }
                }
            }
    }

    private func quit() {
        game.backToStart()
    }
}

/// Target word banner ("?" letters on hard).
struct TetriskyTargetView: View {
    @Environment(TetriskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            if let target = game.state?.targetWord {
                Text(game.difficulty.showsTarget ? target.word.lowercased() : String(repeating: "?", count: target.word.count))
                    .font(.system(.title2, design: .rounded))
                    .bold()
                    .kerning(3)
                    .foregroundStyle(theme.accent)
                    .shadow(color: theme.accentGlow, radius: 8)
                if game.difficulty.showsTarget {
                    Text(target.translation)
                        .font(.subheadline)
                        .foregroundStyle(theme.info)
                }
            }
        }
        .animation(Design.snappy, value: game.state?.targetWord)
        .accessibilityElement(children: .combine)
    }
}

/// The 8×14 board, drawn with Canvas: landed letters, ghost, falling piece.
struct TetriskyBoardView: View {
    @Environment(TetriskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { context, size in
            guard let state = game.state else { return }
            let cols = Double(TetriskyEngine.columns)
            let rows = Double(TetriskyEngine.rows)
            let cell = min(size.width / cols, size.height / rows)
            let originX = (size.width - cell * cols) / 2
            let originY = (size.height - cell * rows) / 2

            func rect(row: Int, col: Int, inset: Double = 1.5) -> CGRect {
                CGRect(
                    x: originX + Double(col) * cell + inset,
                    y: originY + Double(row) * cell + inset,
                    width: cell - inset * 2,
                    height: cell - inset * 2
                )
            }

            // A lit, beveled cube: shadowed body, four bevel faces (light from
            // the top-left), a gradient front face, and a specular top edge.
            func drawTile(row: Int, col: Int, letter: Character, fill: Color, text: Color) {
                let tileRect = rect(row: row, col: col)
                let bevel = max(2.5, cell * 0.14)
                let outer = Path(roundedRect: tileRect, cornerRadius: 3)
                let face = tileRect.insetBy(dx: bevel, dy: bevel)

                var shadowContext = context
                shadowContext.addFilter(.shadow(
                    color: .black.opacity(0.5), radius: bevel * 0.6, x: 0, y: bevel * 0.5
                ))
                shadowContext.fill(outer, with: .color(fill))

                func bevelFace(_ points: [CGPoint], shade: Color) {
                    var path = Path()
                    path.addLines(points)
                    path.closeSubpath()
                    context.fill(path, with: .color(fill))
                    context.fill(path, with: .color(shade))
                }
                let o = tileRect
                bevelFace(
                    [CGPoint(x: o.minX, y: o.minY), CGPoint(x: o.maxX, y: o.minY),
                     CGPoint(x: face.maxX, y: face.minY), CGPoint(x: face.minX, y: face.minY)],
                    shade: .white.opacity(0.32)
                )
                bevelFace(
                    [CGPoint(x: o.minX, y: o.minY), CGPoint(x: face.minX, y: face.minY),
                     CGPoint(x: face.minX, y: face.maxY), CGPoint(x: o.minX, y: o.maxY)],
                    shade: .white.opacity(0.12)
                )
                bevelFace(
                    [CGPoint(x: o.maxX, y: o.minY), CGPoint(x: o.maxX, y: o.maxY),
                     CGPoint(x: face.maxX, y: face.maxY), CGPoint(x: face.maxX, y: face.minY)],
                    shade: .black.opacity(0.25)
                )
                bevelFace(
                    [CGPoint(x: o.minX, y: o.maxY), CGPoint(x: face.minX, y: face.maxY),
                     CGPoint(x: face.maxX, y: face.maxY), CGPoint(x: o.maxX, y: o.maxY)],
                    shade: .black.opacity(0.4)
                )

                let facePath = Path(face)
                context.fill(facePath, with: .color(fill))
                context.fill(facePath, with: .linearGradient(
                    Gradient(colors: [.white.opacity(0.2), .clear, .black.opacity(0.18)]),
                    startPoint: CGPoint(x: face.midX, y: face.minY),
                    endPoint: CGPoint(x: face.midX, y: face.maxY)
                ))

                var specular = Path()
                specular.move(to: CGPoint(x: face.minX + 1, y: face.minY + 0.5))
                specular.addLine(to: CGPoint(x: face.maxX - 1, y: face.minY + 0.5))
                context.stroke(specular, with: .color(.white.opacity(0.35)), lineWidth: 1)
                context.stroke(outer, with: .color(.black.opacity(0.3)), lineWidth: 1)

                var letterContext = context
                letterContext.addFilter(.shadow(
                    color: .black.opacity(0.4), radius: 1, x: 0, y: 1
                ))
                letterContext.draw(
                    Text(String(letter))
                        .font(.system(size: cell * 0.52, weight: .bold, design: .rounded))
                        .foregroundStyle(text),
                    at: CGPoint(x: face.midX, y: face.midY),
                    anchor: .center
                )
            }

            let board = CGRect(x: originX, y: originY, width: cell * cols, height: cell * rows)
            context.fill(Path(roundedRect: board, cornerRadius: 6), with: .color(theme.bgPrimary.opacity(0.9)))
            context.stroke(
                Path(roundedRect: board, cornerRadius: 6),
                with: .color(theme.accent.opacity(0.25)),
                lineWidth: 1
            )

            for r in 0..<TetriskyEngine.rows {
                for c in 0..<TetriskyEngine.columns {
                    if let letter = state.board[r][c] {
                        drawTile(row: r, col: c, letter: letter, fill: theme.tileTop, text: theme.textPrimary)
                    }
                }
            }

            if let falling = state.falling {
                if let ghost = TetriskyEngine.ghostRow(state), ghost != falling.row {
                    let ghostRect = rect(row: ghost, col: falling.col)
                    context.stroke(
                        Path(roundedRect: ghostRect, cornerRadius: 4),
                        with: .color(theme.accent.opacity(0.35)),
                        style: StrokeStyle(lineWidth: 1.5, dash: [4, 3])
                    )
                }
                drawTile(row: falling.row, col: falling.col, letter: falling.letter, fill: theme.accent, text: theme.bgPrimary)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("Tetrisky board")
    }
}
