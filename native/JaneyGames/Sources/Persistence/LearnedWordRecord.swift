import Foundation
import SwiftData

/// One vocabulary word the player has encountered across the games — the
/// Word Book. CloudKit rules: defaults everywhere, no unique constraints.
@Model
final class LearnedWordRecord {
    var word: String = ""
    var translation: String = ""
    var languageID: String = ""
    /// The game that first taught it.
    var sourceGame: String = ""
    var timesSeen: Int = 0
    var firstSeen: Date = Date.now
    var lastSeen: Date = Date.now

    init(word: String, translation: String, languageID: String, sourceGame: String) {
        self.word = word
        self.translation = translation
        self.languageID = languageID
        self.sourceGame = sourceGame
        timesSeen = 1
        firstSeen = .now
        lastSeen = .now
    }
}
