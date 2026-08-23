import SwiftUI

/// Day results: star row per question, total, share/leaderboard, then review.
struct TriviaResultsView: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing * 1.5) {
            Label("Triviatsky", systemImage: GameID.triviatsky.symbol)
                .font(.headline)
                .kerning(2)
                .textCase(.uppercase)
                .foregroundStyle(theme.accent)

            Text("Game Over")
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .foregroundStyle(theme.textPrimary)

            Text(game.friendlyDate)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

            if let state = game.state {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(0..<state.questionScores.count, id: \.self) { index in
                            HStack {
                                Text(game.questionText(at: index))
                                    .font(.subheadline)
                                    .bold()
                                    .lineLimit(1)
                                    .foregroundStyle(theme.textPrimary)
                                if state.fastAnswers.indices.contains(index), state.fastAnswers[index] {
                                    Image(systemName: "bolt.fill")
                                        .font(.caption)
                                        .foregroundStyle(theme.accent)
                                        .accessibilityLabel("Speed bonus")
                                }
                                Spacer()
                                TriviaStarsView(score: state.questionScores[index])
                            }
                        }
                    }
                }
                .frame(maxHeight: 240)

                Text("Total: \(state.totalScore)/\(state.maxScore)")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(theme.accent)
            }

            HStack(spacing: Design.spacing) {
                Button(action: review) {
                    Label("Review", systemImage: "eye")
                        .bold()
                }
                .buttonStyle(.glassProminent)

                ShareLink(item: game.shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.glass)

                if model.gameCenter.isAuthenticated {
                    Button("Ranks", systemImage: "chart.bar.fill", action: showLeaderboard)
                        .buttonStyle(.glass)
                }
            }
        }
        .padding(Design.padding * 1.5)
        .presentationDetents([.medium, .large])
        .presentationBackground(.thinMaterial)
        .interactiveDismissDisabled(false)
        .onDisappear(perform: review)
    }

    private func review() {
        game.enterReview()
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(game: .triviatsky, languageID: game.language.id, difficulty: nil)
    }
}
