import Foundation
import SwiftData

/// Collects every word the player meets into a browsable, synced Word Book.
@Observable
final class WordBookService {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = container.mainContext
    }

    /// Records encountered words, deduping by (word, language) and bumping
    /// the seen counter on repeats.
    func record(words: [(word: String, translation: String)], languageID: String, game: GameID) {
        for entry in words {
            let normalized = entry.word.lowercased()
            if let existing = find(word: normalized, languageID: languageID) {
                existing.timesSeen += 1
                existing.lastSeen = .now
                if existing.translation.isEmpty {
                    existing.translation = entry.translation
                }
            } else {
                context.insert(
                    LearnedWordRecord(
                        word: normalized,
                        translation: entry.translation,
                        languageID: languageID,
                        sourceGame: game.rawValue
                    )
                )
            }
        }
        try? context.save()
    }

    func allWords(languageID: String) -> [LearnedWordRecord] {
        let descriptor = FetchDescriptor<LearnedWordRecord>(
            predicate: #Predicate { $0.languageID == languageID },
            sortBy: [SortDescriptor(\.lastSeen, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func wordCount(languageID: String) -> Int {
        let descriptor = FetchDescriptor<LearnedWordRecord>(
            predicate: #Predicate { $0.languageID == languageID }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    private func find(word: String, languageID: String) -> LearnedWordRecord? {
        let descriptor = FetchDescriptor<LearnedWordRecord>(
            predicate: #Predicate { $0.word == word && $0.languageID == languageID }
        )
        return try? context.fetch(descriptor).first
    }
}
