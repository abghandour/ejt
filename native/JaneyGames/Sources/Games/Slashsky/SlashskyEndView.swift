import SwiftUI

/// Run results: score, main words completed, synonyms slashed, actions.
struct SlashskyEndView: View {
    @Environment(SlashskyModel.self) private var game
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing * 1.5) {
            HStack(spacing: 6) {
                GameIconView(game: .slashsky, size: 20)
                Text("SLASHSKY")
                    .font(.headline)
                    .kerning(2)
            }
            .foregroundStyle(theme.accent)

            Text("Game Over")
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .foregroundStyle(theme.textPrimary)

            VStack(spacing: 8) {
                EndStatRow(label: "Score", value: "\(game.state?.score ?? 0)", color: theme.accent)
                EndStatRow(label: "Words Completed", value: "\(game.state?.wordsCompleted ?? 0)", color: theme.successText)
                EndStatRow(label: "Synonyms Slashed", value: "\(game.state?.totalSynonymsSlashed ?? 0)", color: theme.info)
            }
            .padding(.horizontal, Design.padding)

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
        "☭ Slashsky — \(game.state?.score ?? 0) points, \(game.state?.totalSynonymsSlashed ?? 0) synonyms slashed. Think you can beat me?"
    }

    private func playAgain() {
        game.backToStart()
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(game: .slashsky, languageID: game.language.id, difficulty: nil)
    }
}
