import SwiftUI

/// Main entry point for the JTopGames app.
/// Hosts Russian language learning games with Patreon OAuth authentication.
@main
struct JTopGamesApp: App {
    @StateObject private var authManager = AuthManager()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .task {
                    await authManager.checkExistingSession()
                }
        }
        .onChange(of: scenePhase) { newPhase in
            // WKWebView retains its state by default when not deallocated.
            // We intentionally do NOT reload the WebView on foreground return
            // so the player resumes exactly where they left off. (Req 10.2)
            switch newPhase {
            case .background:
                // App moved to background — WebView state is preserved automatically.
                break
            case .active:
                // App returned to foreground — no reload needed, game resumes in place.
                break
            case .inactive:
                break
            @unknown default:
                break
            }
        }
    }
}
