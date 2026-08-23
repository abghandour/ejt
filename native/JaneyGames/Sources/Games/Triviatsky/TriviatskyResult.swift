import Foundation

/// Outcome of a completed trivia day, handed to stats + Game Center reporting.
nonisolated struct TriviatskyResult: Sendable {
    let languageID: String
    let dateKey: String
    let score: Int
    let maxScore: Int
    let questionCount: Int
}
