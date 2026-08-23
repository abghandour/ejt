import SwiftUI

/// The 2×3 grid of translation choices.
struct RootskyAnswerGridView: View {
    @Environment(RootskyModel.self) private var game

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            // Offset identity guards against duplicate option strings in data.
            ForEach(Array(game.presentedAnswers.enumerated()), id: \.offset) { _, answer in
                RootskyAnswerButton(answer: answer)
            }
        }
        .padding(.horizontal, Design.padding)
    }
}

struct RootskyAnswerButton: View {
    @Environment(RootskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false

    let answer: String

    private var state: RootskyModel.AnswerState {
        game.answerState(for: answer)
    }

    var body: some View {
        Button(action: select) {
            Text(answer)
                .font(.system(.subheadline, design: .rounded))
                .bold()
                .foregroundStyle(textColor)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, minHeight: 52)
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(background, in: .rect(cornerRadius: Design.tileCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.tileCornerRadius)
                        .strokeBorder(borderColor, lineWidth: 2)
                )
                .opacity(state == .disabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(state != .normal)
        .scaleEffect(appeared ? (state == .correct ? 1.05 : 1) : 0.3)
        .opacity(appeared ? 1 : 0)
        .phaseAnimator(
            state == .wrong && !reduceMotion ? [0.0, -5, 5, -3, 3, 0] : [0.0],
            trigger: state == .wrong
        ) { view, offset in
            view.offset(x: offset)
        } animation: { _ in
            .linear(duration: 0.06)
        }
        .animation(Design.snappy, value: state)
        .onChange(of: game.wordGeneration, initial: true) {
            animateIn()
        }
        .accessibilityLabel(accessibilityText)
    }

    private var background: AnyShapeStyle {
        switch state {
        case .correct: AnyShapeStyle(theme.correctGradient)
        case .wrong: AnyShapeStyle(theme.wrongGradient)
        case .normal, .disabled: AnyShapeStyle(theme.tileGradient)
        }
    }

    private var borderColor: Color {
        switch state {
        case .correct: theme.correctBorder
        case .wrong: theme.wrongBorder
        case .normal, .disabled: theme.tileBorder
        }
    }

    private var textColor: Color {
        switch state {
        case .correct: theme.successText
        case .wrong: theme.dangerText
        case .normal, .disabled: theme.textPrimary
        }
    }

    private var accessibilityText: String {
        switch state {
        case .correct: "\(answer), correct answer"
        case .wrong: "\(answer), wrong"
        case .normal, .disabled: answer
        }
    }

    private func animateIn() {
        appeared = false
        let index = game.presentedAnswers.firstIndex(of: answer) ?? 0
        let delay = reduceMotion ? 0 : 0.1 + Double(index) * 0.06
        withAnimation(Design.tilePop.delay(delay)) {
            appeared = true
        }
    }

    private func select() {
        game.selectAnswer(answer)
    }
}
