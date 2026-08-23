import SwiftUI

/// Numbered chips for each question; answered ones show their stars.
/// Tappable in review mode to browse answers.
struct TriviaTrackerView: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        if let state = game.state {
            HStack(spacing: 8) {
                ForEach(0..<state.questionScores.count, id: \.self) { index in
                    TriviaTrackerChip(
                        index: index,
                        score: state.questionScores[index],
                        isAnswered: state.revealed[index],
                        isActive: index == state.currentQuestionIndex,
                        isNavigable: state.completed
                    )
                }
            }
            .padding(.horizontal, Design.padding)
            .frame(maxWidth: Design.maxContentWidth)
            .animation(Design.snappy, value: state.revealed)
            .animation(Design.snappy, value: state.currentQuestionIndex)
        }
    }
}

struct TriviaTrackerChip: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(\.theme) private var theme
    let index: Int
    let score: Int
    let isAnswered: Bool
    let isActive: Bool
    let isNavigable: Bool

    private var isFast: Bool {
        guard let state = game.state, isAnswered else { return false }
        return state.fastAnswers.indices.contains(index) && state.fastAnswers[index]
    }

    var body: some View {
        Button(action: show) {
            VStack(spacing: 1) {
                HStack(spacing: 2) {
                    Text("\(index + 1)")
                        .font(.caption)
                        .bold()
                        .foregroundStyle(isAnswered ? theme.successText : theme.textSecondary)
                    if isFast {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.accent)
                            .accessibilityLabel("Speed bonus")
                    }
                }
                if isAnswered {
                    TriviaStarsView(score: score, starSize: 6)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                isAnswered ? AnyShapeStyle(theme.correctGradient) : AnyShapeStyle(theme.tileGradient),
                in: .rect(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isActive ? theme.accent : (isAnswered ? theme.correctBorder : theme.tileBorder), lineWidth: 2)
            )
            .shadow(color: isActive ? theme.accentGlow : .clear, radius: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isNavigable)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        isAnswered ? "Question \(index + 1), \(score) of 5 stars" : "Question \(index + 1), unanswered"
    }

    private func show() {
        game.showQuestion(index)
    }
}

/// A 5-star score row.
struct TriviaStarsView: View {
    @Environment(\.theme) private var theme
    let score: Int
    var starSize: Double = 12

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: i < score ? "star.fill" : "star")
                    .font(.system(size: starSize))
                    .foregroundStyle(i < score ? theme.accent : theme.textMuted)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("\(score) of 5 stars")
    }
}
