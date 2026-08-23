import Foundation

/// Outcome of a finished run, handed to stats + Game Center reporting.
nonisolated struct TetriskyResult: Sendable {
    let languageID: String
    let difficulty: TetriskyDifficulty
    let score: Int
    let wordsCompleted: Int
    let durationSeconds: Int
    let words: [FoundWord]
}
