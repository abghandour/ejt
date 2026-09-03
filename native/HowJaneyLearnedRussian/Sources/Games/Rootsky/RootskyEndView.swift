import SwiftUI

/// Day results: per-word star rows with times, total out of 25, then review.
struct RootskyEndView: View {
    @Environment(RootskyModel.self) private var game
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing * 1.5) {
            Label(game.title.capitalized, systemImage: game.game.symbol)
                .font(.headline)
                .kerning(2)
                .textCase(.uppercase)
                .foregroundStyle(theme.accent)

            Text("Game Over")
                .heading(.largeTitle)
                .foregroundStyle(theme.textPrimary)
                .overlay(alignment: .trailing) {
                    if game.state?.totalScore == game.maxScore {
                        PerfectStampView()
                            .offset(x: 70, y: -8)
                    }
                }

            Text(game.friendlyDate)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

            if let root = game.words.first?.rootWord {
                RootFamilyTreeView(
                    rootWord: root,
                    words: game.words.map(\.wordOfTheDay),
                    theme: theme
                )
            }

            if let state = game.state {
                VStack(spacing: 8) {
                    ForEach(Array(game.words.enumerated()), id: \.offset) { index, word in
                        HStack(spacing: 8) {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(word.wordOfTheDay)
                                    .font(.subheadline)
                                    .bold()
                                    .foregroundStyle(theme.textPrimary)
                                Text(word.translation)
                                    .font(.caption)
                                    .foregroundStyle(theme.info)
                            }
                            Spacer()
                            TriviaStarsView(score: state.wordScores[index])
                            if state.wordTimes[index] > 0 {
                                Text("\(state.wordTimes[index])s")
                                    .font(.caption)
                                    .monospacedDigit()
                                    .foregroundStyle(theme.textMuted)
                                    .frame(minWidth: 30, alignment: .trailing)
                            }
                        }
                    }
                }

                Text("Total: \(state.totalScore)/\(game.maxScore)")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(theme.accent)

                Label(game.elapsedText, systemImage: "stopwatch")
                    .font(.subheadline)
                    .foregroundStyle(theme.info)
            }

            HStack(spacing: Design.spacing) {
                Button(action: review) {
                    Label("Review", systemImage: "eye")
                        .bold()
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.glassProminent)

                ShareLink(item: game.shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glass)

                if model.gameCenter.isAuthenticated {
                    Button("Ranks", systemImage: "chart.bar.fill", action: showLeaderboard)
                        .lineLimit(1)
                        .fixedSize()
                        .buttonStyle(.glass)
                }
            }
        }
        .padding(Design.padding * 1.5)
        .presentationDetents([.medium, .large])
        .presentationBackground(.thinMaterial)
        .onDisappear(perform: review)
    }

    private func review() {
        game.enterReview()
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(game: game.game, languageID: game.language.id, difficulty: nil)
    }
}

/// Rotated gold seal for a flawless 25/25 day.
struct PerfectStampView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        Text("ОТЛИЧНО ★")
            .font(.system(size: 13, weight: .heavy, design: .rounded))
            .kerning(1)
            .foregroundStyle(theme.accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(theme.accent, lineWidth: 2)
            )
            .rotationEffect(.degrees(-12))
            .shadow(color: theme.accentGlow, radius: 6)
            .accessibilityLabel("Perfect day")
    }
}
