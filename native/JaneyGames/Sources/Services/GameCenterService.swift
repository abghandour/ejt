import GameKit
import Observation

/// Game Center: authentication and leaderboard submission.
/// Leaderboard IDs follow `<game>.<language>.<difficulty>` (e.g. "bogglesky.ru.medium")
/// and must be registered in App Store Connect with the same IDs.
@Observable
final class GameCenterService {
    private(set) var isAuthenticated = false
    private(set) var isAuthenticating = false
    /// The player's Game Center display name once authenticated.
    private(set) var playerName: String?
    /// The player's Game Center profile photo once loaded.
    private(set) var playerPhoto: UIImage?

    func authenticate() {
        guard !isAuthenticated, !isAuthenticating else { return }
        isAuthenticating = true
        GKLocalPlayer.local.authenticateHandler = { [weak self] viewController, _ in
            Task { @MainActor [weak self] in
                if let viewController {
                    Self.rootViewController?.present(viewController, animated: true)
                    return
                }
                let player = GKLocalPlayer.local
                self?.isAuthenticated = player.isAuthenticated
                self?.isAuthenticating = false
                if player.isAuthenticated {
                    self?.playerName = player.displayName
                    self?.loadPlayerPhoto()
                }
            }
        }
    }

    private func loadPlayerPhoto() {
        Task { [weak self] in
            let photo = try? await GKLocalPlayer.local.loadPhoto(for: .normal)
            self?.playerPhoto = photo
        }
    }

    /// The full Game Center overlay (profile, friends, all leaderboards).
    func showDashboard() {
        guard isAuthenticated else { return }
        GKAccessPoint.shared.trigger(state: .dashboard) {}
    }

    static func leaderboardID(game: GameID, languageID: String, difficulty: String?) -> String {
        var id = "\(game.rawValue).\(languageID)"
        if let difficulty {
            id += ".\(difficulty)"
        }
        return id
    }

    /// Presents the system Game Center overlay for one leaderboard.
    /// `friendsOnly` shows the winnable race against people you know.
    func showLeaderboard(game: GameID, languageID: String, difficulty: String?, friendsOnly: Bool = false) {
        guard isAuthenticated else { return }
        GKAccessPoint.shared.trigger(
            leaderboardID: Self.leaderboardID(game: game, languageID: languageID, difficulty: difficulty),
            playerScope: friendsOnly ? .friendsOnly : .global,
            timeScope: .allTime
        ) {}
    }

    /// Submits to both the all-time board and its `.weekly` recurring twin
    /// (register both IDs in App Store Connect; unknown IDs are ignored).
    func submit(score: Int, game: GameID, languageID: String, difficulty: String?) {
        guard isAuthenticated else { return }
        let id = Self.leaderboardID(game: game, languageID: languageID, difficulty: difficulty)
        Task {
            try? await GKLeaderboard.submitScore(
                score,
                context: 0,
                player: GKLocalPlayer.local,
                leaderboardIDs: [id, id + ".weekly"]
            )
        }
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}
