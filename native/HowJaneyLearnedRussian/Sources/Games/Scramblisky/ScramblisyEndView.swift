import SwiftUI

/// Round results: stats, solved-word list, and play again / share / leaderboard.
struct ScramblisyEndView: View {
    @Environment(ScramblisyModel.self) private var game
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing * 1.5) {
            Label("Scramblisky", systemImage: GameID.scramblisky.symbol)
                .font(.headline)
                .kerning(2)
                .textCase(.uppercase)
                .foregroundStyle(theme.accent)

            Text("Time's Up!")
                .heading(.largeTitle)
                .foregroundStyle(theme.textPrimary)

            VStack(spacing: 8) {
                EndStatRow(label: "Difficulty", value: game.difficulty.displayName, color: theme.accent)
                EndStatRow(label: "Words Solved", value: "\(game.wordsCompleted)", color: theme.successText)
                EndStatRow(label: "Words Skipped", value: "\(game.wordsSkipped)", color: theme.textSecondary)
                EndStatRow(label: "Wrong Attempts", value: "\(game.wrongAttempts)", color: theme.danger)
                EndStatRow(label: "Score", value: "\(game.score)", color: theme.accent)
            }
            .padding(.horizontal, Design.padding)

            SolvedWordListView()

            HStack(spacing: Design.spacing) {
                Button(action: playAgain) {
                    Label("Again", systemImage: "arrow.counterclockwise")
                        .bold()
                        .lineLimit(1)
                        .fixedSize()
                }
                .buttonStyle(.glassProminent)

                ShareLink(item: shareText) {
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
        .frame(maxWidth: 420)
        .glassEffect(.regular.tint(theme.surface.opacity(0.6)), in: .rect(cornerRadius: Design.cardCornerRadius))
        .padding(Design.padding)
    }

    private var shareText: String {
        "I unscrambled \(game.wordsCompleted) \(game.language.displayName) words for \(game.score) points in Scramblisky (\(game.difficulty.displayName)). Think you can beat me? 🔤"
    }

    private func playAgain() {
        game.backToStart()
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(
            game: .scramblisky,
            languageID: game.language.id,
            difficulty: game.difficulty.rawValue
        )
    }
}

/// Scrollable list of solved words with translations and points.
struct SolvedWordListView: View {
    @Environment(ScramblisyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        if game.completedWords.isEmpty {
            Text("No words solved")
                .font(.subheadline)
                .foregroundStyle(theme.textMuted)
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(Array(game.completedWords.enumerated()), id: \.offset) { _, found in
                        HStack {
                            Text(found.word)
                                .bold()
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            Text("\(found.translation) (+\(found.points))")
                                .foregroundStyle(theme.info)
                        }
                        .font(.subheadline)
                    }
                }
                .padding(.horizontal, Design.padding)
            }
            .frame(maxHeight: 180)
        }
    }
}
