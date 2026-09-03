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
            if theme.decoration == .korni {
                KorniStickersView()
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

                        if FeatureFlags.multiLanguage {
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
                        }

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
                .heading(.caption, kerning: 4)
                .foregroundStyle(theme.textSecondary)
            Text(model.language.displayName.uppercased())
                .heading(.largeTitle, kerning: 2)
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

/// Collage stickers for the Korni theme: the megaphone cutout bottom-leading
/// and a slanted black label bottom-trailing, both purely decorative.
private struct KorniStickersView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Image("korni-megaphone")
                .resizable()
                .scaledToFit()
                .frame(width: 162)
                .rotationEffect(.degrees(-6))
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 8)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: -2) {
                Text("PICK A GAME.")
                    .foregroundStyle(theme.accent)
                Text("PLAY EVERY DAY!")
                    .foregroundStyle(.white)
            }
            .font(.custom("Manrope-ExtraBold", size: 13))
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(theme.sunburst2)
            .rotationEffect(.degrees(-9))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(.trailing, 6)
            .padding(.bottom, 10)
        }
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
