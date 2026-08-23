import Foundation
import Observation

/// Loads and caches the synonym dictionary (slashsky.json) for a language.
@Observable
final class SlashskyStore {
    private var cache: [String: SlashskyEngine.Dictionary] = [:]

    func dictionary(for language: Language) async throws -> SlashskyEngine.Dictionary {
        if let cached = cache[language.id] { return cached }
        let loaded = try await Self.load(subdirectory: language.dictionarySubdirectory)
        cache[language.id] = loaded
        return loaded
    }

    @concurrent
    private nonisolated static func load(subdirectory: String) async throws -> SlashskyEngine.Dictionary {
        guard let url = Bundle.main.url(forResource: "slashsky", withExtension: "json", subdirectory: subdirectory) else {
            throw DictionaryError.missing(language: subdirectory, game: "slashsky")
        }
        let data = try Data(contentsOf: url)
        let raw = try JSONDecoder().decode(SlashskyEngine.Dictionary.self, from: data)
        let words = raw.words.filter(\.isValid)
        guard !words.isEmpty else {
            throw DictionaryError.tooSmall(validCount: 0)
        }
        guard !raw.distractors.isEmpty else {
            throw DictionaryError.tooSmall(validCount: raw.distractors.count)
        }
        return SlashskyEngine.Dictionary(words: words, distractors: raw.distractors)
    }
}
