import Foundation
import Observation

/// Loads and caches the date-keyed trivia data for a language.
@Observable
final class TriviaStore {
    private var cache: [String: [String: [TriviaQuestion]]] = [:]

    /// All of a language's trivia, keyed by YYYYMMDD. Invalid questions dropped.
    func trivia(for language: Language) async throws -> [String: [TriviaQuestion]] {
        if let cached = cache[language.id] { return cached }
        let loaded = try await Self.load(subdirectory: language.dictionarySubdirectory)
        cache[language.id] = loaded
        return loaded
    }

    @concurrent
    private nonisolated static func load(subdirectory: String) async throws -> [String: [TriviaQuestion]] {
        guard let url = Bundle.main.url(forResource: "triviatsky", withExtension: "json", subdirectory: subdirectory) else {
            throw DictionaryError.missing(language: subdirectory, game: "triviatsky")
        }
        let data = try Data(contentsOf: url)
        let days = try JSONDecoder().decode([String: [TriviaQuestion]].self, from: data)
        return days
            .mapValues { $0.filter(\.isValid) }
            .filter { !$0.value.isEmpty }
    }
}
