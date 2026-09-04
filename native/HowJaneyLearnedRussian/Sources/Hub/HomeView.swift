import SwiftUI

// THESIS: Janey's home is a field notebook, not an app dashboard.
// OWN-WORLD: paper panels, route marks, and a daily dispatch turn progress into a journey.
// STORY: arrive → check today’s work → choose a station → collect words and rank up.
// FIRST VIEWPORT: the next expedition and visible mission progress are immediately actionable.
// FORM: one featured route, a stamped mission passport, then a horizontal arcade shelf.
// FINISH: quiet paper grain, bold editorial type, and small route-specific iconography.
struct HomeView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var didAppear = false

    var body: some View {
        ZStack {
            ThemedBackground()

            ScrollView {
                VStack(spacing: 22) {
                    HomeHeaderView()
                    DailyDispatchView()
                }
                .frame(maxWidth: Design.maxContentWidth)
                .padding(.horizontal, Design.padding)
                .padding(.top, 8)
                .padding(.bottom, 72)
                .opacity(didAppear ? 1 : 0)
                .offset(y: didAppear ? 0 : 16)
            }
            .scrollIndicators(.hidden)
            .onAppear {
                guard !didAppear else { return }
                if reduceMotion {
                    didAppear = true
                } else {
                    withAnimation(Design.celebration) {
                        didAppear = true
                    }
                }
            }

            if theme.decoration == .korni {
                KorniStickersView()
            }
        }
    }
}

/// The dispatch masthead makes rank, language, and navigation feel like one
/// compact piece of expedition equipment rather than a row of generic chrome.
struct HomeHeaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("JANEY'S FIELD NOTES")
                    .heading(.caption, kerning: 2.2)
                    .foregroundStyle(theme.textSecondary)
                Spacer(minLength: 4)
                HomeToolsView()
            }

            Text(model.language.displayName.uppercased())
                .heading(.largeTitle, kerning: 1.2)
                .foregroundStyle(theme.textPrimary)
                .contentTransition(.numericText())
                .animation(Design.snappy, value: model.language.id)

            HStack(spacing: 10) {
                Image(systemName: "rosette")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text("\(model.rank.name) · \(model.rank.nativeName)")
                        .font(.system(.subheadline, design: .rounded).weight(.bold))
                        .foregroundStyle(theme.textPrimary)
                    if let next = model.rank.next {
                        ProgressView(value: Rank.progress(forXP: model.totalXP))
                            .tint(theme.accent)
                            .accessibilityLabel("\(Int(Rank.progress(forXP: model.totalXP) * 100)) percent toward \(next.name)")
                    }
                }

                Spacer(minLength: 8)

                Text("\(model.totalXP) XP")
                    .font(.system(.subheadline, design: .rounded).weight(.black))
                    .foregroundStyle(theme.accent)
                    .monospacedDigit()
            }
            .expeditionPanel()
            .accessibilityElement(children: .combine)
        }
    }
}

private struct HomeToolsView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: 6) {
            Button {
                model.isShowingProfile = true
            } label: {
                ProfileAvatarView(size: 34)
            }
            .accessibilityLabel("Profile: \(model.displayName)")
            .buttonStyle(.plain)
            .frame(width: 44, height: 44)
            .background(Circle().fill(theme.surface.opacity(0.92)))

            Button {
                model.isShowingWordBook = true
            } label: {
                Image(systemName: "character.book.closed.fill")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(theme.textPrimary)
                    .background(Circle().fill(theme.surface.opacity(0.92)))
            }
            .accessibilityLabel("Open Word Book")
            .buttonStyle(.plain)

            if FeatureFlags.multiLanguage {
                Menu {
                    ForEach(model.languages) { language in
                        Button {
                            model.selectLanguage(language)
                        } label: {
                            if model.isLanguageLocked(language) {
                                Label("\(language.flag) \(language.displayName)", systemImage: "lock")
                            } else if language.id == model.language.id {
                                Label("\(language.flag) \(language.displayName)", systemImage: "checkmark")
                            } else {
                                Text("\(language.flag) \(language.displayName)")
                            }
                        }
                    }
                } label: {
                    Text(model.language.flag)
                        .font(.title3)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(theme.surface.opacity(0.92)))
                }
                .accessibilityLabel("Language: \(model.language.displayName)")
            }

            Button {
                model.isShowingSettings = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.subheadline.weight(.bold))
                    .frame(width: 44, height: 44)
                    .foregroundStyle(theme.textPrimary)
                    .background(Circle().fill(theme.surface.opacity(0.92)))
            }
            .accessibilityLabel("Settings")
            .buttonStyle(.plain)
        }
    }
}

struct DailyDispatchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var wordOfDay: RootskyWord?

    private var featuredGame: GameInfo? {
        model.games.first { $0.id == .meddleysky } ?? model.games.first
    }

    private var routeGames: [GameInfo] {
        model.games.filter { $0.id != featuredGame?.id }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("TODAY'S DISPATCH")
                        .heading(.headline, kerning: 1.3)
                        .foregroundStyle(theme.textPrimary)
                    Text(Date.now.formatted(.dateTime.weekday(.wide)))
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                StreakFlameView()
            }

            if let featuredGame {
                MeddleyDispatchView(game: featuredGame)
            }

            DailyMissionPassportView(missions: model.dailyMissions)

            if let wordOfDay {
                DailyWordDispatchView(word: wordOfDay)
            }

            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CHOOSE A ROUTE")
                        .heading(.headline, kerning: 1.2)
                        .foregroundStyle(theme.textPrimary)
                    Text("Every station teaches a different kind of memory.")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }
                Spacer()
                Image(systemName: "arrow.right")
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
            }

            ScrollView(.horizontal) {
                LazyHStack(spacing: 12) {
                    ForEach(routeGames) { game in
                        ExpeditionGameTileView(game: game)
                            .frame(width: 210)
                    }
                }
                .padding(.vertical, 3)
            }
            .scrollIndicators(.hidden)
        }
        .task(id: model.language.id) {
            await loadWordOfDay()
        }
    }

    private func loadWordOfDay() async {
        wordOfDay = nil
        let language = model.language
        guard model.games.contains(where: { $0.id == .rootsky }) else { return }
        let key = TriviaLogic.dateKey(for: .now)
        let days = try? await model.rootskyStore.words(for: language)
        guard model.language.id == language.id else { return }
        wordOfDay = days?[key]?.first
    }
}

struct MeddleyDispatchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let game: GameInfo

    var body: some View {
        Button {
            model.activeGame = game.id
        } label: {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: Design.cardCornerRadius, style: .continuous)
                    .fill(theme.accent)

                Image(systemName: "circle.hexagongrid.fill")
                    .font(.system(size: 128, weight: .black))
                    .foregroundStyle(theme.textPrimary.opacity(0.13))
                    .rotationEffect(.degrees(-14))
                    .offset(x: 22, y: 28)
                    .accessibilityHidden(true)

                HStack(alignment: .bottom, spacing: 12) {
                    GameIconView(game: game.id, size: 42)
                        .foregroundStyle(theme.textPrimary)
                        .padding(11)
                        .background(Circle().fill(theme.surface.opacity(0.76)))

                    VStack(alignment: .leading, spacing: 5) {
                        Text("THE DAILY MIX")
                            .font(.caption.weight(.black))
                            .tracking(1.3)
                        Text(game.name)
                            .heading(.title2, kerning: 0.5)
                        Text("A quick run through several ways to remember.")
                            .font(.subheadline)
                            .lineLimit(2)
                    }
                    .foregroundStyle(theme.textPrimary)

                    Spacer(minLength: 0)
                    Image(systemName: "arrow.up.right")
                        .font(.title3.weight(.black))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.bottom, 4)
                }
                .padding(18)
            }
            .frame(minHeight: 154)
            .shadow(color: theme.accentGlow, radius: 15, y: 8)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Starts \(game.name)")
    }
}

struct DailyMissionPassportView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let missions: [DailyMission]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Label("FIELD PASSPORT", systemImage: "seal.fill")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(theme.textPrimary)
                Spacer()
                Text("\(missions.filter(\.isComplete).count)/\(missions.count) STAMPS")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textSecondary)
            }

            ForEach(missions) { mission in
                HStack(spacing: 12) {
                    Image(systemName: mission.isComplete ? "checkmark.seal.fill" : mission.symbol)
                        .font(.headline)
                        .foregroundStyle(mission.isComplete ? theme.success : theme.accent)
                        .frame(width: 28)
                        .accessibilityHidden(true)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(mission.title)
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(theme.textPrimary)
                            Spacer(minLength: 8)
                            Text(mission.progressText)
                                .font(.caption.weight(.bold))
                                .monospacedDigit()
                                .foregroundStyle(theme.textSecondary)
                        }
                        ProgressView(value: Double(min(mission.current, mission.goal)), total: Double(mission.goal))
                            .tint(mission.isComplete ? theme.success : theme.accent)
                        Text(mission.detail)
                            .font(.caption)
                            .foregroundStyle(theme.textMuted)
                            .lineLimit(1)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .expeditionPanel()
        .animation(reduceMotion ? nil : Design.bouncy, value: missions)
    }
}

struct DailyWordDispatchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let word: RootskyWord

    var body: some View {
        Button {
            model.activeGame = .rootsky
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "tree.fill")
                    .font(.title2.weight(.black))
                    .foregroundStyle(theme.success)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(theme.success.opacity(0.14)))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 3) {
                    Text(word.rootWord?.uppercased() ?? "WORD OF THE DAY")
                        .font(.caption.weight(.black))
                        .tracking(1.1)
                        .foregroundStyle(theme.textSecondary)
                    Text(word.wordOfTheDay)
                        .heading(.title2, kerning: 0.3)
                        .foregroundStyle(theme.textPrimary)
                    Text(word.rootTranslation ?? word.translation)
                        .font(.subheadline)
                        .foregroundStyle(theme.info)
                }

                Spacer(minLength: 0)

                Image(systemName: "arrow.up.right")
                    .font(.subheadline.weight(.black))
                    .foregroundStyle(theme.accent)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .expeditionPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Word of the day: \(word.wordOfTheDay), \(word.translation)")
        .accessibilityHint("Opens Rootsky")
    }
}

struct ExpeditionGameTileView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let game: GameInfo

    var body: some View {
        Button {
            model.activeGame = game.id
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top) {
                    GameIconView(game: game.id, size: 30)
                        .foregroundStyle(theme.accent)
                        .frame(width: 44, height: 44)
                        .background(RoundedRectangle(cornerRadius: 13, style: .continuous).fill(theme.accent.opacity(0.14)))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.subheadline.weight(.black))
                        .foregroundStyle(theme.textMuted)
                }

                Text(game.name)
                    .heading(.title3, kerning: 0.3)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                Text(game.desc)
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
                    .lineLimit(2)
                    .frame(maxWidth: .infinity, alignment: .leading)

                GameCardStatsView(game: game)
                    .frame(minHeight: 18, alignment: .leading)
            }
            .frame(maxWidth: .infinity, minHeight: 176, alignment: .leading)
            .expeditionPanel()
        }
        .buttonStyle(.plain)
        .accessibilityHint("Starts \(game.name)")
    }
}

/// A single Korni cutout held just above the safe area as a quiet physical
/// collage detail, rather than a competing home-screen callout.
private struct KorniStickersView: View {
    var body: some View {
        Image("korni-megaphone")
            .resizable()
            .scaledToFit()
            .frame(width: 126)
            .rotationEffect(.degrees(-2))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
            .padding(.leading, 6)
            .padding(.bottom, 19)
            .ignoresSafeArea(edges: .bottom)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}
