import SwiftUI

/// Legacy full-card presentation kept for previews and deep links. It shares
/// the field-notebook treatment used by the dispatch hub.
struct GameCardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let game: GameInfo

    var body: some View {
        VStack(spacing: Design.spacing * 1.5) {
            Spacer()

            GameIconView(game: game.id, size: 64)
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accentGlow, radius: 16)
                .accessibilityHidden(true)

            Text(game.name.uppercased())
                .heading(.title, kerning: 3)
                .foregroundStyle(theme.textPrimary)

            Text(game.desc)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding)

            GameCardStatsView(game: game)

            Spacer()

            if game.isPlayable {
                Button(action: play) {
                    Label("Play", systemImage: "play.fill")
                        .font(.title3)
                        .bold()
                        .padding(.horizontal, Design.padding * 2)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(theme.accent)
            } else {
                Label("Coming soon", systemImage: "hourglass")
                    .font(.headline)
                    .foregroundStyle(theme.textMuted)
                    .padding(.vertical, Design.padding)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .expeditionPanel()
    }

    private func play() {
        model.activeGame = game.id
    }
}

/// Best score / streak line sourced from local stats.
struct GameCardStatsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let game: GameInfo

    var body: some View {
        if let stats = model.stats.stats(game: game.id, languageID: model.language.id), stats.gamesPlayed > 0 {
            HStack(spacing: Design.spacing * 1.5) {
                Label("\(stats.bestScore)", systemImage: "star.fill")
                    .accessibilityLabel("Best score \(stats.bestScore)")
                if stats.currentStreak > 1 {
                    Label("\(stats.currentStreak)", systemImage: "flame.fill")
                        .accessibilityLabel("\(stats.currentStreak) day streak")
                }
            }
            .font(.subheadline)
            .bold()
            .foregroundStyle(theme.accent)
        }
    }
}
