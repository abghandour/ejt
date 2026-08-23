import SwiftUI

/// One letter tile: selection glow, preview tilt, correct/wrong flash,
/// staggered grow-in on fresh boards.
struct BoggleCellView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    let letter: String
    let index: Int
    let cellSize: Double

    private var isHead: Bool { game.selectedPath.last == index }
    private var inPath: Bool { game.selectedPath.contains(index) }
    private var isPreview: Bool { game.previewIndex == index }
    private var flashKind: BoggleskyModel.FlashKind? {
        guard let flash = game.flash, flash.cells.contains(index) else { return nil }
        return flash.kind
    }

    /// Deterministic tilt direction so a tile keeps its lean while selected.
    private var tiltDegrees: Double {
        (index + game.boardGeneration).isMultiple(of: 2) ? -5 : 5
    }

    var body: some View {
        Text(letter)
            .font(.system(size: cellSize * 0.5, weight: .bold, design: .rounded))
            .foregroundStyle(textColor)
            .shadow(color: inPath ? theme.accentGlow : .clear, radius: 8)
            .frame(width: cellSize, height: cellSize)
            .background(background, in: .rect(cornerRadius: Design.tileCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Design.tileCornerRadius)
                    .strokeBorder(borderColor, lineWidth: 2)
            )
            .shadow(color: inPath ? theme.accentGlow : .black.opacity(0.25), radius: inPath ? 10 : 3, y: 2)
            .rotationEffect(.degrees(reduceMotion ? 0 : ((inPath && !isHead) || isPreview ? tiltDegrees : 0)))
            .scaleEffect(cellScale)
            .phaseAnimator(
                flashKind == .wrong && !reduceMotion ? [0.0, -5, 5, -3, 3, 0] : [0.0],
                trigger: game.flash?.id ?? 0
            ) { view, offset in
                view.offset(x: offset)
            } animation: { _ in
                .linear(duration: 0.06)
            }
            .animation(Design.tilePop, value: inPath)
            .animation(Design.snappy, value: isPreview)
            .animation(Design.snappy, value: flashKind)
            .onChange(of: game.boardGeneration, initial: true) {
                animateIn()
            }
            .accessibilityLabel(letter)
            .accessibilityAddTraits(inPath ? .isSelected : [])
    }

    private var cellScale: Double {
        if !appeared { return 0.01 }
        if flashKind == .correct { return 1.12 }
        if isHead { return 1.08 }
        if inPath || isPreview { return 1.05 }
        return 1
    }

    private var background: AnyShapeStyle {
        switch flashKind {
        case .correct: AnyShapeStyle(theme.correctGradient)
        case .wrong: AnyShapeStyle(theme.wrongGradient)
        case nil: inPath ? AnyShapeStyle(theme.tileSelectedGradient) : AnyShapeStyle(theme.tileGradient)
        }
    }

    private var borderColor: Color {
        switch flashKind {
        case .correct: theme.correctBorder
        case .wrong: theme.wrongBorder
        case nil: inPath ? theme.accent : theme.tileBorder
        }
    }

    private var textColor: Color {
        switch flashKind {
        case .correct: theme.successText
        case .wrong: theme.dangerText
        case nil: inPath ? theme.accent : theme.textPrimary
        }
    }

    private func animateIn() {
        appeared = false
        let delay = reduceMotion ? 0 : Double(index) * 0.03
        withAnimation(Design.tilePop.delay(delay)) {
            appeared = true
        }
    }
}
