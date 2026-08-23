import Foundation

/// Outcome of a finished run, handed to stats + Game Center reporting.
nonisolated struct SlashskyResult: Sendable {
    let languageID: String
    let score: Int
    let wordsCompleted: Int
    let totalSynonymsSlashed: Int
    let words: [FoundWord]
}
