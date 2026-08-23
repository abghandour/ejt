import Foundation

/// Outcome of a completed day, handed to stats + Game Center reporting.
/// Shared by Rootsky and Wordsky (`game` tells them apart).
nonisolated struct RootskyResult: Sendable {
    let game: GameID
    let languageID: String
    let dateKey: String
    /// Total stars out of 25.
    let score: Int
    let durationSeconds: Int
    /// The day's five words (Word Book capture).
    let words: [FoundWord]
}
