import SwiftUI

/// Five chips for the day's words: resolved ones show word, translation, stars,
/// and time; future ones a "?". Tappable in review mode.
struct RootskyTrackerView: View {
    @Environment(RootskyModel.self) private var game

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<game.wordCount, id: \.self) { index in
                RootskyTrackerChip(index: index)
            }
        }
        .padding(.horizontal, Design.padding)
        .animation(Design.snappy, value: game.displayedIndex)
        .animation(Design.snappy, value: game.isCompleted)
    }
}

struct RootskyTrackerChip: View {
    @Environment(RootskyModel.self) private var game
    @Environment(\.theme) private var theme
    let index: Int

    private var isReview: Bool {
        if case .review = game.phase { return true }
        return false
    }

    private var isPlayed: Bool {
        guard let state = game.state else { return false }
        return state.completed || isReview || index < state.currentWordIndex
            || (index == state.currentWordIndex && game.wordRevealed)
    }

    private var isActive: Bool {
        index == game.displayedIndex
    }

    var body: some View {
        Button(action: show) {
            VStack(spacing: 1) {
                if isPlayed, game.words.indices.contains(index), let state = game.state {
                    Text(game.words[index].wordOfTheDay)
                        .font(.caption2)
                        .bold()
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .foregroundStyle(theme.textPrimary)
                    TriviaStarsView(score: state.wordScores[index], starSize: 6)
                    if state.wordTimes.indices.contains(index), state.wordTimes[index] > 0 {
                        Text("\(state.wordTimes[index])s")
                            .font(.system(size: 8))
                            .foregroundStyle(theme.textMuted)
                    }
                } else {
                    Text("?")
                        .font(.headline)
                        .foregroundStyle(theme.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, minHeight: 46)
            .padding(.horizontal, 2)
            .background(
                isPlayed ? AnyShapeStyle(theme.correctGradient) : AnyShapeStyle(theme.tileGradient),
                in: .rect(cornerRadius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(isActive ? theme.accent : (isPlayed ? theme.correctBorder : theme.tileBorder), lineWidth: 2)
            )
            .shadow(color: isActive ? theme.accentGlow : .clear, radius: 6)
        }
        .buttonStyle(.plain)
        .disabled(!isReview)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        if isPlayed, game.words.indices.contains(index), let state = game.state {
            "Word \(index + 1): \(game.words[index].wordOfTheDay), \(state.wordScores[index]) of 5 stars"
        } else {
            "Word \(index + 1), not played yet"
        }
    }

    private func show() {
        game.showWord(index)
    }
}
