import Foundation

/// A single dictionary entry: a target-language word and its English translation.
nonisolated struct WordEntry: Hashable, Sendable, Decodable {
    let word: String
    let translation: String
}
