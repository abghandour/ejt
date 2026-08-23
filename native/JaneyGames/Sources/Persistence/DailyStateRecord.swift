import Foundation
import SwiftData

/// Saved progress for one (game, language, day) — the old Supabase
/// `daily_game_state` table. `stateJSON` holds the game-specific state blob.
/// CloudKit rules: defaults everywhere, no unique constraints.
@Model
final class DailyStateRecord {
    var game: String = ""
    var languageID: String = ""
    /// YYYYMMDD, matching the dictionaries' date keys.
    var dateKey: String = ""
    var stateJSON: Data = Data()
    var completed: Bool = false
    var updatedAt: Date = Date.now

    init(game: String, languageID: String, dateKey: String, stateJSON: Data, completed: Bool) {
        self.game = game
        self.languageID = languageID
        self.dateKey = dateKey
        self.stateJSON = stateJSON
        self.completed = completed
        updatedAt = .now
    }
}
