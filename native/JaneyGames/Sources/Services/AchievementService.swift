import GameKit
import Observation

/// Reports Game Center achievements. IDs must be registered in App Store
/// Connect with these exact identifiers.
@Observable
final class AchievementService {
    nonisolated enum ID: String {
        /// A perfect 25/25 Rootsky day.
        case perfectRootsky = "perfect_rootsky"
        /// Cleared an entire Bogglesky board before the timer.
        case boardClear = "board_clear"
        /// Solved 10+ words in one Scramblisky run.
        case scrambleTen = "scramble_ten"
        /// 5-starred every question of a Triviatsky day.
        case perfectTrivia = "perfect_trivia"
        case streak7 = "streak_7"
        case streak30 = "streak_30"
        case streak100 = "streak_100"
    }

    @ObservationIgnored private var reported: Set<ID> = []

    func report(_ id: ID) {
        guard GKLocalPlayer.local.isAuthenticated, !reported.contains(id) else { return }
        reported.insert(id)
        let achievement = GKAchievement(identifier: id.rawValue)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }

    /// Streak milestones from any game's best streak.
    func reportStreak(_ bestStreak: Int) {
        if bestStreak >= 7 { report(.streak7) }
        if bestStreak >= 30 { report(.streak30) }
        if bestStreak >= 100 { report(.streak100) }
    }
}
