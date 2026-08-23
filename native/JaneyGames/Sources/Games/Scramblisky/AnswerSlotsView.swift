import SwiftUI

/// Dashed answer slots that fill as tiles are tapped; tap a filled slot to
/// return its letter. Flashes green/red on submit.
struct AnswerSlotsView: View {
    @Environment(ScramblisyModel.self) private var game
    @State private var availableWidth = 0.0

    private static let maxSlotSize = 48.0
    private static let spacing = 6.0

    var body: some View {
        HStack(spacing: Self.spacing) {
            if let word = game.currentWord {
                let count = word.word.count
                ForEach(0..<count, id: \.self) { position in
                    AnswerSlotView(
                        position: position,
                        letter: letter(at: position),
                        slotSize: slotSize(count: count)
                    )
                }
            }
        }
        .id(game.wordGeneration)
        .frame(maxWidth: .infinity, minHeight: 56)
        .onGeometryChange(for: Double.self, of: { $0.size.width }) { width in
            availableWidth = width
        }
    }

    private func letter(at position: Int) -> String? {
        guard game.selectedIndices.indices.contains(position) else { return nil }
        return String(game.scrambledLetters[game.selectedIndices[position]])
    }

    private func slotSize(count: Int) -> Double {
        guard availableWidth > 0, count > 0 else { return Self.maxSlotSize }
        let fit = (availableWidth - Self.spacing * Double(count - 1) - Design.padding * 2) / Double(count)
        return min(Self.maxSlotSize, max(28, fit))
    }
}

struct AnswerSlotView: View {
    @Environment(ScramblisyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    let position: Int
    let letter: String?
    let slotSize: Double

    private var flash: ScramblisyModel.SlotFlash? {
        letter != nil ? game.slotFlash : nil
    }

    var body: some View {
        Button(action: remove) {
            Text(letter ?? "")
                .font(.system(size: slotSize * 0.55, weight: .bold, design: .rounded))
                .foregroundStyle(textColor)
                .frame(width: slotSize, height: slotSize)
                .background(background, in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(
                            borderColor,
                            style: StrokeStyle(lineWidth: 2, dash: letter == nil ? [5, 4] : [])
                        )
                )
        }
        .buttonStyle(.plain)
        .disabled(letter == nil || game.isTransitioning)
        .scaleEffect(appeared ? (flash == .correct ? 1.12 : 1) : 0.01)
        .opacity(appeared ? 1 : 0)
        .phaseAnimator(
            flash == .wrong && !reduceMotion ? [0.0, -5, 5, -3, 3, 0] : [0.0],
            trigger: flash == .wrong
        ) { view, offset in
            view.offset(x: offset)
        } animation: { _ in
            .linear(duration: 0.06)
        }
        .animation(Design.snappy, value: letter)
        .animation(Design.snappy, value: flash)
        .onChange(of: game.wordGeneration, initial: true) {
            animateIn()
        }
        .accessibilityLabel(letter.map { "Slot \(position + 1), \($0). Tap to remove." } ?? "Empty slot \(position + 1)")
    }

    private var background: AnyShapeStyle {
        switch flash {
        case .correct: AnyShapeStyle(theme.correctGradient)
        case .wrong: AnyShapeStyle(theme.wrongGradient)
        case nil:
            letter != nil
                ? AnyShapeStyle(theme.tileSelectedGradient)
                : AnyShapeStyle(theme.accent.opacity(0.06))
        }
    }

    private var borderColor: Color {
        switch flash {
        case .correct: theme.correctBorder
        case .wrong: theme.wrongBorder
        case nil: letter != nil ? theme.accent : theme.tileBorder
        }
    }

    private var textColor: Color {
        switch flash {
        case .correct: theme.successText
        case .wrong: theme.dangerText
        case nil: theme.accent
        }
    }

    private func animateIn() {
        appeared = false
        let delay = reduceMotion ? 0 : Double(position) * 0.05
        withAnimation(Design.tilePop.delay(delay)) {
            appeared = true
        }
    }

    private func remove() {
        game.removeSlot(at: position)
    }
}
