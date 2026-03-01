import SwiftUI

/// Main game screen composing the NavigationBar at top and GameWebView
/// filling the remaining space. Tracks the currently selected game and
/// triggers WebView reload on game tab selection.
struct MainGameView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedGame: GameDefinition = GameRegistry.games[0]

    var body: some View {
        VStack(spacing: 0) {
            NavigationBar(selectedGame: $selectedGame)

            GameWebView(
                game: selectedGame,
                patreonDisplayName: authManager.userProfile?.displayName
            )
            .id(selectedGame.id) // Force new WebView instance on game switch
        }
        .ignoresSafeArea(.container, edges: [.bottom])
        .background(Color(hex: "0e0e1a"))
        .statusBarHidden(false)
    }
}
