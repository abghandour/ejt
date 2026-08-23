import SwiftUI

/// Run results: cause of death, stats, eaten-word list, and actions.
struct SnakeskyEndView: View {
    @Environment(SnakeskyModel.self) private var game
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing * 1.5) {
            Label("Snakesky", systemImage: GameID.snakesky.symbol)
                .font(.headline)
                .kerning(2)
                .textCase(.uppercase)
                .foregroundStyle(theme.accent)

            Text("Game Over")
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .foregroundStyle(theme.textPrimary)

            Text(deathText)
                .font(.subheadline)
                .foregroundStyle(theme.textSecondary)

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
                            HStack {
                                Text(word.word)
                                    .bold()
                                    .foregroundStyle(theme.textPrimary)
                                Spacer()
                                Text(word.translation)
                                    .foregroundStyle(theme.info)
                            }
                            .font(.subheadline)
                        }
                    }
                    .padding(.horizontal, Design.padding)
                }
                .frame(maxHeight: 160)
            }

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

    private var deathText: String {
        switch game.deathCause {
        case .wall: "The snake hit the wall."
        case .body: "The snake bit itself."
        case .wrongLetter: "Wrong letter — mind the order!"
        case nil: ""
        }
    }

    private var shareText: String {
        let words = game.state?.wordsCompleted ?? 0
        let grid = words > 0 ? String(repeating: "🟩", count: min(words, 20)) : "🟥"
        return "🐍 Snakesky (\(game.difficulty.displayName)) — \(words) words, \(game.state?.score ?? 0) points.\n\(grid)\nThink you can beat me?"
    }

    private func playAgain() {
        game.backToStart()
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(
            game: .snakesky,
            languageID: game.language.id,
            difficulty: game.difficulty.rawValue
        )
    }
}
