import SwiftUI

/// Two-column answer grid with staggered pop-in per question.
struct TriviaAnswerGridView: View {
    @Environment(TriviatskyModel.self) private var game

    private let columns = [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: 10) {
            ForEach(game.displayedAnswers) { answer in
                TriviaAnswerButton(answer: answer)
            }
        }
    }
}

/// One answer: correct/wrong coloring, shake on a wrong tap, pop-in entrance.
struct TriviaAnswerButton: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let answer: TriviaAnswer

    var body: some View {
        Button(action: select) {
            VStack(spacing: 2) {
                Text(answer.text)
                    .font(.system(.body, design: .rounded))
                    .bold()
                    .foregroundStyle(textColor)
                if game.showTranslations, let translation = answer.translation {
                    Text(translation)
                        .font(.caption)
                        .foregroundStyle(theme.info)
                }
            }
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 52)
            .padding(.horizontal, 10)
            .padding(.vertical, 10)
            .background(background, in: .rect(cornerRadius: Design.tileCornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: Design.tileCornerRadius)
                    .strokeBorder(borderColor, lineWidth: 2)
            )
            .opacity(answer.state == .disabled ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(answer.state != .normal)
        .scaleEffect(appeared ? 1 : 0.3)
        .opacity(appeared ? 1 : 0)
        .phaseAnimator(
            game.wrongShakePosition == answer.position && !reduceMotion ? [0.0, -6, 6, -4, 4, 0] : [0.0],
            trigger: game.wrongShakePosition
        ) { view, offset in
            view.offset(x: offset)
        } animation: { _ in
            .linear(duration: 0.06)
        }
        .animation(Design.snappy, value: answer.state)
        .onChange(of: game.questionAppearance, initial: true) {
            animateIn()
        }
        .accessibilityLabel(accessibilityText)
    }

    private var background: AnyShapeStyle {
        switch answer.state {
        case .correct: AnyShapeStyle(theme.correctGradient)
        case .wrong: AnyShapeStyle(theme.wrongGradient)
        case .normal, .disabled: AnyShapeStyle(theme.tileGradient)
        }
    }

    private var borderColor: Color {
        switch answer.state {
        case .correct: theme.correctBorder
        case .wrong: theme.wrongBorder
        case .normal, .disabled: theme.tileBorder
        }
    }

    private var textColor: Color {
        switch answer.state {
        case .correct: theme.successText
        case .wrong: theme.dangerText
        case .normal, .disabled: theme.textPrimary
        }
    }

    private var accessibilityText: String {
        switch answer.state {
        case .correct: "\(answer.text), correct answer"
        case .wrong: "\(answer.text), wrong"
        case .normal, .disabled: answer.text
        }
    }

    private func animateIn() {
        appeared = false
        let delay = reduceMotion ? 0 : 0.15 + Double(answer.position) * 0.1
        withAnimation(Design.tilePop.delay(delay)) {
            appeared = true
        }
    }

    private func select() {
        game.selectAnswer(at: answer.position)
    }
}
