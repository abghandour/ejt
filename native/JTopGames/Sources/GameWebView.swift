import SwiftUI
import WebKit

/// Observable object that tracks WebView loading state and errors.
/// Shared between the SwiftUI overlay and the UIViewRepresentable coordinator.
class GameWebViewState: ObservableObject {
    @Published var isLoading: Bool = true
    @Published var error: String? = nil
}

/// SwiftUI wrapper that composes the WKWebView with loading/error overlays.
struct GameWebView: View {
    let game: GameDefinition
    let patreonDisplayName: String?

    @StateObject private var state = GameWebViewState()

    var body: some View {
        ZStack {
            WebViewRepresentable(game: game, patreonDisplayName: patreonDisplayName, state: state)

            if state.isLoading && state.error == nil {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color(hex: "c8a830")))
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(hex: "0e0e1a").opacity(0.8))
            }

            if let error = state.error {
                GameErrorView(message: error) {
                    state.error = nil
                    state.isLoading = true
                }
            }
        }
    }
}

/// Error view displayed when game file resolution or navigation fails.
private struct GameErrorView: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundColor(Color(hex: "c8a830"))

            Text("Game Unavailable")
                .font(.custom("RobotoCondensed-Bold", size: 20))
                .foregroundColor(Color(hex: "f5e6c8"))

            Text(message)
                .font(.custom("RobotoCondensed-Regular", size: 14))
                .foregroundColor(Color(hex: "f5e6c8").opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Button(action: onRetry) {
                Text("RETRY")
                    .font(.custom("RobotoCondensed-Bold", size: 14))
                    .foregroundColor(Color(hex: "c8a830"))
                    .padding(.horizontal, 24)
                    .padding(.vertical, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color(hex: "c8a830"), lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0e0e1a"))
    }
}

/// UIViewRepresentable that wraps WKWebView and loads game HTML from the bundle.
private struct WebViewRepresentable: UIViewRepresentable {
    let game: GameDefinition
    let patreonDisplayName: String?
    let state: GameWebViewState

    func makeCoordinator() -> Coordinator {
        Coordinator(state: state)
    }

    func makeUIView(context: Context) -> WKWebView {
        // Resolve the Games directory in the bundle
        let gamesDir = Bundle.main.url(forResource: "Games", withExtension: nil)
            ?? Bundle.main.bundleURL.appendingPathComponent("Games")

        let schemeHandler = LocalFileSchemeHandler(gamesDirectory: gamesDir)
        context.coordinator.schemeHandler = schemeHandler

        let configuration = WKWebViewConfiguration()
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true
        configuration.websiteDataStore = WKWebsiteDataStore.default()

        // Register custom scheme so fetch() works with local files
        configuration.setURLSchemeHandler(schemeHandler, forURLScheme: LocalFileSchemeHandler.scheme)

        // Register JSBridge message handler and inject patreonUser script
        let contentController = configuration.userContentController
        JSBridge.register(on: contentController, bridge: context.coordinator.jsBridge)
        contentController.addUserScript(JSBridge.userScript(patreonDisplayName: patreonDisplayName))

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.isOpaque = false
        webView.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 26/255, alpha: 1)
        webView.scrollView.backgroundColor = UIColor(red: 14/255, green: 14/255, blue: 26/255, alpha: 1)

        loadGame(game, into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Reload if the game changed
        if context.coordinator.currentGameID != game.id {
            loadGame(game, into: webView)
        }
    }

    private func loadGame(_ game: GameDefinition, into webView: WKWebView) {
        // Load via custom game:// scheme so fetch() works for JSON files
        let urlString = "\(LocalFileSchemeHandler.scheme)://local/\(game.htmlFileName)"
        guard let url = URL(string: urlString) else {
            DispatchQueue.main.async {
                state.error = "Could not build URL for \(game.displayName)."
                state.isLoading = false
            }
            return
        }

        DispatchQueue.main.async {
            state.error = nil
            state.isLoading = true
        }

        webView.load(URLRequest(url: url))

        // Track which game is currently loaded
        (webView.navigationDelegate as? Coordinator)?.currentGameID = game.id
    }

    /// Coordinator acts as WKNavigationDelegate to track loading state and errors.
    class Coordinator: NSObject, WKNavigationDelegate {
        let state: GameWebViewState
        let jsBridge = JSBridge()
        var currentGameID: String?
        var schemeHandler: LocalFileSchemeHandler?

        init(state: GameWebViewState) {
            self.state = state
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.state.isLoading = true
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.state.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.state.error = "Failed to load game: \(error.localizedDescription)"
                self.state.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            DispatchQueue.main.async {
                self.state.error = "Failed to load game: \(error.localizedDescription)"
                self.state.isLoading = false
            }
        }
    }
}
