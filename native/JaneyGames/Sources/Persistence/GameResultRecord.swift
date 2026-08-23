import Foundation
import SwiftData

/// One finished round (the old Supabase `session_scores` row).
/// CloudKit rules: every property has a default, no unique constraints.
@Model
final class GameResultRecord {
    var game: String = ""
    var languageID: String = ""
    var difficulty: String?
    var score: Int = 0
    var wordsCompleted: Int = 0
    var playedAt: Date = Date.now

    init(game: String, languageID: String, difficulty: String?, score: Int, wordsCompleted: Int, playedAt: Date = .now) {
        self.game = game
        self.languageID = languageID
        self.difficulty = difficulty
        self.score = score
        self.wordsCompleted = wordsCompleted
        self.playedAt = playedAt
    }
}
