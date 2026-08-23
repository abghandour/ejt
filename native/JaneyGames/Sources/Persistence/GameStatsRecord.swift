import Foundation
import SwiftData

/// Per (game, language) aggregates — the old server-trigger-maintained
/// `user_game_stats`, now computed client-side on every recorded result.
@Model
final class GameStatsRecord {
    var game: String = ""
    var languageID: String = ""
    var gamesPlayed: Int = 0
    var bestScore: Int = 0
    var totalScore: Int = 0
    var currentStreak: Int = 0
    var bestStreak: Int = 0
    var lastPlayed: Date?

    init(game: String, languageID: String) {
        self.game = game
        self.languageID = languageID
    }
}
