import Foundation

/// Outcome of a finished round, handed to stats + Game Center reporting.
nonisolated struct ScramblisyResult: Sendable {
    let languageID: String
    let difficulty: ScramblisyDifficulty
    let score: Int
    let wordsCompleted: Int
    let wordsSkipped: Int
    let wrongAttempts: Int
    /// Every word solved this round (Word Book capture).
    let words: [FoundWord]
}
