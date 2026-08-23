import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var model = model
        HomeView()
            .fullScreenCover(item: $model.activeGame) { game in
                switch game {
                case .bogglesky:
                    BoggleskyView()
                case .triviatsky:
                    TriviatskyView()
                case .scramblisky:
                    ScramblisyView()
                case .rootsky:
                    RootskyView()
                case .wordsky:
                    RootskyView(gameID: .wordsky)
                case .snakesky:
                    SnakeskyView()
                case .tetrisky:
                    TetriskyView()
                case .slashsky:
                    SlashskyView()
                }
            }
            .sheet(isPresented: $model.isShowingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $model.isShowingProfile) {
                ProfileView()
            }
            .sheet(isPresented: $model.isShowingWordBook) {
                WordBookView()
            }
            .sheet(isPresented: $model.isShowingPaywall) {
                PaywallView()
            }
            .environment(\.theme, model.theme)
            .tint(model.theme.accent)
            .preferredColorScheme(model.theme.isDark ? .dark : .light)
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    model.refreshStreakReminder()
                }
            }
            .task {
                model.gameCenter.authenticate()
                model.refreshStreakReminder()
                let arguments = ProcessInfo.processInfo.arguments
                if let flag = arguments.firstIndex(of: "-language"), arguments.indices.contains(flag + 1) {
                    model.settings.languageID = arguments[flag + 1]
                }
                for game in GameID.allCases where arguments.contains("-open-\(game.rawValue)") {
                    model.activeGame = game
                }
                if arguments.contains("-open-profile") {
                    model.isShowingProfile = true
                }
            }
    }
}
