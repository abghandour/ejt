import SwiftUI

/// The game hub: themed background, title, and a swipeable card carousel —
/// the native take on web/mobile/index.html.
struct HomeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var selectedGame: GameID?

    var body: some View {
        ZStack {
            ThemedBackground()
            VStack(spacing: Design.spacing) {
                HomeHeaderView()
                GameCarouselView(selectedGame: $selectedGame)
            }
        }
        .onAppear(perform: selectInitialGame)
        .onChange(of: model.language.id) {
            selectInitialGame()
        }
    }

    private func selectInitialGame() {
        if selectedGame == nil || !model.games.contains(where: { $0.id == selectedGame }) {
            selectedGame = model.games.first?.id
        }
    }
}

/// Title row plus glass controls for language/settings.
struct HomeHeaderView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                StreakFlameView()
                Spacer()
                GlassEffectContainer {
                    HStack(spacing: Design.spacing) {
                        Button(action: showProfile) {
                            ProfileAvatarView(size: 36)
                        }
                        .glassEffect(.regular.interactive(), in: .circle)
                        .accessibilityLabel("Profile: \(model.displayName)")

                        Button("Word Book", systemImage: "character.book.closed.fill", action: showWordBook)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .padding(10)
                            .glassEffect(.regular.interactive())

                        Menu {
                            ForEach(model.languages) { language in
                                Button(action: { model.selectLanguage(language) }) {
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
                                .padding(10)
                        }
                        .glassEffect(.regular.interactive())
                        .accessibilityLabel("Language: \(model.language.displayName)")

                        Button("Settings", systemImage: "gearshape.fill", action: showSettings)
                            .labelStyle(.iconOnly)
                            .font(.title3)
                            .padding(10)
                            .glassEffect(.regular.interactive())
                    }
                }
            }
            .padding(.horizontal, Design.padding)

            Text("HOW JANEY LEARNED")
                .font(.system(.caption, design: .rounded))
                .bold()
                .kerning(4)
                .foregroundStyle(theme.textSecondary)
            Text(model.language.displayName.uppercased())
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .kerning(2)
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accentGlow, radius: 12)
                .contentTransition(.numericText())
                .animation(Design.snappy, value: model.language.id)
        }
    }

    private func showSettings() {
        model.isShowingSettings = true
    }

    private func showProfile() {
        model.isShowingProfile = true
    }

    private func showWordBook() {
        model.isShowingWordBook = true
    }
}

/// Swipeable page carousel of game cards.
struct GameCarouselView: View {
    @Environment(AppModel.self) private var model
    @Binding var selectedGame: GameID?

    var body: some View {
        TabView(selection: $selectedGame) {
            ForEach(model.games) { game in
                GameCardView(game: game)
                    .tag(Optional(game.id))
                    .padding(.horizontal, Design.padding * 2)
                    .padding(.vertical, Design.padding)
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .always))
    }
}
