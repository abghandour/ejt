import Foundation

/// Outcome of a finished round, handed to stats + Game Center reporting.
nonisolated struct BoggleskyResult: Sendable {
    let languageID: String
    let difficulty: BoggleskyDifficulty
    let score: Int
    let wordsFound: Int
    let findableWords: Int
    /// Every word found this round (Word Book capture).
    let words: [FoundWord]
    /// Boards fully cleared this round (achievement).
    let clearedBoards: Int
}
