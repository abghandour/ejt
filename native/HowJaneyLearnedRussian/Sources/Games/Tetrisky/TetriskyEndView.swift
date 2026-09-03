import SwiftUI

/// Run results: stats, formed-word list, and actions.
struct TetriskyEndView: View {
    @Environment(TetriskyModel.self) private var game
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing * 1.5) {
            Label("Tetrisky", systemImage: GameID.tetrisky.symbol)
                .font(.headline)
                .kerning(2)
                .textCase(.uppercase)
                .foregroundStyle(theme.accent)

            Text("Game Over")
                .heading(.largeTitle)
                .foregroundStyle(theme.textPrimary)

            VStack(spacing: 8) {
                EndStatRow(label: "Difficulty", value: game.difficulty.displayName, color: theme.accent)
                EndStatRow(label: "Words", value: "\(game.state?.wordsCompleted ?? 0)", color: theme.successText)
                EndStatRow(label: "Score", value: "\(game.state?.score ?? 0)", color: theme.accent)
            }
            .padding(.horizontal, Design.padding)

            if let words = game.state?.completedWords, !words.isEmpty {
                ScrollView {
                    VStack(spacing: 4) {
                        ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                            Text(word)
                                .font(.subheadline)
                                .bold()
                                .foregroundStyle(theme.textPrimary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, Design.padding)
                }
                .frame(maxHeight: 150)
            } else {
                Text("No words formed")
                    .font(.subheadline)
                    .foregroundStyle(theme.textMuted)
            }

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
        let words = game.state?.wordsCompleted ?? 0
        let grid = words > 0 ? String(repeating: "🟩", count: min(words, 20)) : "🟥"
        return "🧱 Tetrisky (\(game.difficulty.displayName)) — \(words) words, \(game.state?.score ?? 0) points.\n\(grid)\nThink you can beat me?"
    }

    private func playAgain() {
        game.backToStart()
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(
            game: .tetrisky,
            languageID: game.language.id,
            difficulty: game.difficulty.rawValue
        )
    }
}
