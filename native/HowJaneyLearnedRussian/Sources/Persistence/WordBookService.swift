import Foundation
import SwiftData

/// Collects every word the player meets into a browsable, synced Word Book.
@Observable
final class WordBookService {
    private let context: ModelContext
    private(set) var revision = 0

    init(container: ModelContainer) {
        context = container.mainContext
    }

    /// Records encountered words, deduping by (word, language) and bumping
    /// the seen counter on repeats.
    func record(words: [(word: String, translation: String)], languageID: String, game: GameID) {
        guard !words.isEmpty else { return }
        // One fetch for the whole round instead of one per word.
        let normalizedWords = Array(Set(words.map { $0.word.lowercased() }))
        let descriptor = FetchDescriptor<LearnedWordRecord>(
            predicate: #Predicate { $0.languageID == languageID && normalizedWords.contains($0.word) }
        )
        var existingByWord: [String: LearnedWordRecord] = [:]
        for record in (try? context.fetch(descriptor)) ?? [] where existingByWord[record.word] == nil {
            existingByWord[record.word] = record
        }
        for entry in words {
            let normalized = entry.word.lowercased()
            if let existing = existingByWord[normalized] {
                existing.timesSeen += 1
                existing.lastSeen = .now
                if existing.translation.isEmpty {
                    existing.translation = entry.translation
                }
            } else {
                let new = LearnedWordRecord(
                    word: normalized,
                    translation: entry.translation,
                    languageID: languageID,
                    sourceGame: game.rawValue
                )
                context.insert(new)
                existingByWord[normalized] = new
            }
        }
        try? context.save()
        revision += 1
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

    /// The least-reinforced word is a lightweight, local spaced-review cue.
    /// It deliberately needs no schema change or remote scheduling service.
    func reviewCandidate(languageID: String) -> LearnedWordRecord? {
        var descriptor = FetchDescriptor<LearnedWordRecord>(
            predicate: #Predicate { $0.languageID == languageID },
            sortBy: [SortDescriptor(\.timesSeen), SortDescriptor(\.lastSeen)]
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Distinct journal entries touched today. A repeated word still counts as
    /// a useful review in the book, but only once toward the daily collection.
    func wordsCollectedToday(languageID: String) -> Int {
        let startOfToday = Calendar.current.startOfDay(for: .now)
        let descriptor = FetchDescriptor<LearnedWordRecord>(
            predicate: #Predicate { $0.languageID == languageID && $0.lastSeen >= startOfToday }
        )
        return (try? context.fetchCount(descriptor)) ?? 0
    }

    func markReviewed(_ record: LearnedWordRecord) {
        record.timesSeen += 1
        record.lastSeen = .now
        try? context.save()
        revision += 1
    }

}
