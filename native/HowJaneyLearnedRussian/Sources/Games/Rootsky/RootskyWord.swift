import Foundation

/// One daily Rootsky word: the word of the day, its translation (the correct
/// answer), five wrong options, and the shared root. Schema of ru/rootsky.json.
nonisolated struct RootskyWord: Hashable, Sendable, Decodable {
    let wordOfTheDay: String
    let translation: String
    let wordOptions: [String]
    let rootWord: String?
    let rootTranslation: String?

    /// Validation ported from rootsky.html `validateWordEntry`.
    var isValid: Bool {
        guard !wordOfTheDay.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard !translation.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard wordOptions.count == 5 else { return false }
        return wordOptions.allSatisfy { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }
}
