import SwiftUI

/// Round results: stats, the found-word list, and play again / share / leaderboard.
struct BoggleskyEndView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing * 1.5) {
            Label("Bogglesky", systemImage: GameID.bogglesky.symbol)
                .font(.headline)
                .kerning(2)
                .textCase(.uppercase)
                .foregroundStyle(theme.accent)

            Text("Time's Up!")
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .foregroundStyle(theme.textPrimary)

            VStack(spacing: 8) {
                EndStatRow(label: "Difficulty", value: game.difficulty.label, color: theme.accent)
                EndStatRow(
                    label: "Words Found",
                    value: "\(game.wordsFound.count) / \(game.board?.findableWords.count ?? 0)",
                    color: theme.successText
                )
                EndStatRow(label: "Score", value: "\(game.score)", color: theme.accent)
            }
            .padding(.horizontal, Design.padding)

            FoundWordListView()

            HStack(spacing: Design.spacing) {
                Button(action: playAgain) {
                    Label("Again", systemImage: "arrow.counterclockwise")
                        .bold()
                }
                .buttonStyle(.glassProminent)

                ShareLink(item: shareText) {
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
        .frame(maxWidth: 420)
        .glassEffect(.regular.tint(theme.surface.opacity(0.6)), in: .rect(cornerRadius: Design.cardCornerRadius))
        .padding(Design.padding)
    }

    private var shareText: String {
        let grid = String(repeating: "🟩", count: min(game.wordsFound.count, 20))
        return "I scored \(game.score) finding \(game.wordsFound.count) \(game.language.displayName) words in Bogglesky (\(game.difficulty.label)).\n\(grid)\nThink you can beat me? 🔠"
    }

    private func playAgain() {
        game.backToStart()
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(
            game: .bogglesky,
            languageID: game.language.id,
            difficulty: game.difficulty.rawValue
        )
    }
}

struct EndStatRow: View {
    @Environment(\.theme) private var theme
    let label: String
    let value: String
    let color: Color

    var body: some View {
        LabeledContent(label) {
            Text(value)
                .bold()
                .foregroundStyle(color)
        }
        .foregroundStyle(theme.textSecondary)
    }
}

/// Scrollable list of found words, longest first (matching the web results).
struct FoundWordListView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme

    private var sortedWords: [FoundWord] {
        game.wordsFound.sorted { $0.word.count > $1.word.count }
    }

    var body: some View {
        if game.wordsFound.isEmpty {
            Text("No words found")
                .font(.subheadline)
                .foregroundStyle(theme.textMuted)
        } else {
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(sortedWords) { found in
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
            .frame(maxHeight: 200)
        }
    }
}
