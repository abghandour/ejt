import SwiftUI

/// Player profile: Game Center identity (photo + name), per-game scoreboard,
/// and a shareable scorecard image.
struct ProfileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @State private var scorecard: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Design.spacing * 1.5) {
                    ProfileHeaderView()
                    RankBadgeView()
                        .frame(maxWidth: .infinity)
                        .padding(Design.padding)
                        .glassEffect(.regular.tint(theme.surface.opacity(0.5)), in: .rect(cornerRadius: Design.cornerRadius))
                    ProfileScoreboardView()
                    TriviaCategoryMasteryView()
                    ProfileActionsView(scorecard: scorecard)
                }
                .padding(Design.padding)
            }
            .background(theme.bgPrimary)
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done", action: { dismiss() })
                }
            }
            .task(renderScorecard)
            .onChange(of: model.stats.revision) {
                Task { await renderScorecard() }
            }
        }
    }

    /// Pre-renders the shareable scorecard image.
    private func renderScorecard() async {
        let renderer = ImageRenderer(
            content: ScorecardView(
                playerName: model.displayName,
                languageName: model.language.displayName,
                rankTitle: "\(model.rank.name) · \(model.rank.nativeName)",
                rows: ProfileScoreboardView.rows(model: model),
                theme: model.theme
            )
        )
        renderer.scale = 3
        if let image = renderer.uiImage {
            scorecard = Image(uiImage: image)
        }
    }
}

/// Avatar, name (editable when Game Center hasn't provided one), GC status.
struct ProfileHeaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var settings = model.settings
        VStack(spacing: Design.spacing) {
            ProfileAvatarView(size: 84)

            if model.gameCenter.playerName != nil {
                Text(model.displayName)
                    .font(.system(.title2, design: .rounded))
                    .bold()
                    .foregroundStyle(theme.textPrimary)
                Label("Game Center", systemImage: "checkmark.seal.fill")
                    .font(.caption)
                    .foregroundStyle(theme.success)
            } else {
                TextField("Your name", text: $settings.displayName)
                    .font(.system(.title2, design: .rounded))
                    .bold()
                    .multilineTextAlignment(.center)
                    .textFieldStyle(.plain)
                    .foregroundStyle(theme.textPrimary)
                    .submitLabel(.done)
                Text("Sign in to Game Center in Settings to compete on global leaderboards.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textMuted)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(Design.padding)
        .glassEffect(.regular.tint(theme.surface.opacity(0.5)), in: .rect(cornerRadius: Design.cornerRadius))
    }
}

/// Game Center photo when available, otherwise an initial on a gold circle.
struct ProfileAvatarView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let size: Double

    var body: some View {
        Group {
            if let photo = model.gameCenter.playerPhoto {
                Image(uiImage: photo)
                    .resizable()
                    .scaledToFill()
            } else {
                Text(String(model.displayName.prefix(1)).uppercased())
                    .font(.system(size: size * 0.45, weight: .bold, design: .rounded))
                    .foregroundStyle(theme.bgPrimary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(theme.accent.gradient)
            }
        }
        .frame(width: size, height: size)
        .clipShape(.circle)
        .overlay(Circle().strokeBorder(theme.accent, lineWidth: 2))
        .shadow(color: theme.accentGlow, radius: 8)
        .accessibilityLabel("Profile picture")
    }
}

/// Per-game stats rows for the active language.
struct ProfileScoreboardView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    struct Row: Identifiable {
        let game: GameID
        let name: String
        let gamesPlayed: Int
        let bestScore: Int
        let currentStreak: Int
        let bestStreak: Int

        var id: GameID { game }
    }

    static func rows(model: AppModel) -> [Row] {
        model.games.compactMap { info in
            guard info.isPlayable,
                  let stats = model.stats.stats(game: info.id, languageID: model.language.id),
                  stats.gamesPlayed > 0
            else { return nil }
            return Row(
                game: info.id,
                name: info.name,
                gamesPlayed: stats.gamesPlayed,
                bestScore: stats.bestScore,
                currentStreak: stats.currentStreak,
                bestStreak: stats.bestStreak
            )
        }
    }

    var body: some View {
        let rows = Self.rows(model: model)
        VStack(spacing: Design.spacing) {
            HStack {
                Text("\(model.language.flag) \(model.language.displayName) Scoreboard")
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Spacer()
            }
            if rows.isEmpty {
                ContentUnavailableView {
                    Label("No games played yet", systemImage: "gamecontroller")
                } description: {
                    Text("Play a round and your scores will show up here.")
                }
            } else {
                ForEach(rows) { row in
                    ProfileScoreRowView(row: row)
                }
            }
        }
        .padding(Design.padding)
        .glassEffect(.regular.tint(theme.surface.opacity(0.5)), in: .rect(cornerRadius: Design.cornerRadius))
    }
}

struct ProfileScoreRowView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let row: ProfileScoreboardView.Row

    var body: some View {
        // Menu: pick the global race or the winnable one against friends.
        Menu {
            Button("Global Leaderboard", systemImage: "globe", action: showLeaderboard)
            Button("Friends Only", systemImage: "person.2", action: showFriendsLeaderboard)
        } label: {
            HStack(spacing: Design.spacing) {
                Image(systemName: row.game.symbol)
                    .font(.title3)
                    .foregroundStyle(theme.accent)
                    .frame(width: 32)
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.name)
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(theme.textPrimary)
                    Text("^[\(row.gamesPlayed) game](inflect: true) played")
                        .font(.caption)
                        .foregroundStyle(theme.textMuted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Label("\(row.bestScore)", systemImage: "star.fill")
                        .font(.subheadline)
                        .bold()
                        .foregroundStyle(theme.accent)
                    if row.currentStreak > 1 {
                        Label("\(row.currentStreak)", systemImage: "flame.fill")
                            .font(.caption)
                            .foregroundStyle(theme.danger)
                    }
                }
                if model.gameCenter.isAuthenticated {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(theme.textMuted)
                        .accessibilityHidden(true)
                }
            }
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .disabled(!model.gameCenter.isAuthenticated)
        .accessibilityLabel("\(row.name): best score \(row.bestScore), \(row.gamesPlayed) games played")
        .accessibilityHint(model.gameCenter.isAuthenticated ? "Opens the leaderboard" : "")
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(game: row.game, languageID: model.language.id, difficulty: nil)
    }

    private func showFriendsLeaderboard() {
        model.gameCenter.showLeaderboard(
            game: row.game,
            languageID: model.language.id,
            difficulty: nil,
            friendsOnly: true
        )
    }
}

/// Trivia category mastery: 5-star answers per category across completed days.
struct TriviaCategoryMasteryView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var mastery: [(category: String, count: Int)] = []

    private static let expertThreshold = 10

    var body: some View {
        Group {
            if !mastery.isEmpty {
                VStack(spacing: Design.spacing) {
                    HStack {
                        Text("Trivia Mastery")
                            .font(.headline)
                            .foregroundStyle(theme.textPrimary)
                        Spacer()
                    }
                    ForEach(mastery, id: \.category) { entry in
                        HStack {
                            Text(entry.category)
                                .font(.subheadline)
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            if entry.count >= Self.expertThreshold {
                                Label("Expert", systemImage: "rosette")
                                    .font(.caption)
                                    .bold()
                                    .foregroundStyle(theme.accent)
                            }
                            Text("\(entry.count)")
                                .font(.subheadline)
                                .bold()
                                .monospacedDigit()
                                .foregroundStyle(theme.successText)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(Design.padding)
                .glassEffect(.regular.tint(theme.surface.opacity(0.5)), in: .rect(cornerRadius: Design.cornerRadius))
            }
        }
        .task(computeMastery)
    }

    /// Joins completed day states with the trivia data to count perfect
    /// answers per category.
    private func computeMastery() async {
        guard let allDays = try? await model.triviaStore.trivia(for: model.language) else { return }
        let states = model.dailyState.allCompletedStates(
            TriviaDayState.self,
            game: .triviatsky,
            languageID: model.language.id
        )
        var counts: [String: Int] = [:]
        for (dateKey, state) in states {
            guard let questions = allDays[dateKey] else { continue }
            for (index, question) in questions.enumerated() {
                guard let category = question.category,
                      state.questionScores.indices.contains(index),
                      state.questionScores[index] == 5
                else { continue }
                counts[category, default: 0] += 1
            }
        }
        mastery = counts
            .map { (category: $0.key, count: $0.value) }
            .sorted { $0.count > $1.count }
    }
}

/// Share scorecard + open the Game Center dashboard.
struct ProfileActionsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let scorecard: Image?

    var body: some View {
        HStack(spacing: Design.spacing) {
            if let scorecard {
                ShareLink(
                    item: scorecard,
                    preview: SharePreview("\(model.displayName)'s How Janey Learned Russian scoreboard", image: scorecard)
                ) {
                    Label("Share Scoreboard", systemImage: "square.and.arrow.up")
                        .bold()
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.glassProminent)
            }
            if model.gameCenter.isAuthenticated {
                Button("Game Center", systemImage: "person.2.fill", action: openDashboard)
                    .lineLimit(1)
                    .fixedSize()
                    .buttonStyle(.glass)
            }
        }
    }

    private func openDashboard() {
        model.gameCenter.showDashboard()
    }
}
