import Foundation

nonisolated enum DictionaryError: LocalizedError {
    case missing(language: String, game: String)
    case tooSmall(validCount: Int)

    var errorDescription: String? {
        switch self {
        case .missing(let language, let game):
            "No \(game) dictionary bundled for “\(language)”."
        case .tooSmall(let validCount):
            "Dictionary too small (\(validCount) valid entries)."
        }
    }
}

/// Loads, validates, and caches bundled dictionaries.
/// Validation mirrors web/shared/engine.js: 3–8 character words matching the
/// language's regex, non-empty translations, ≥ 20 valid entries overall.
@Observable
final class DictionaryStore {
    private var cache: [String: WordDictionary] = [:]

    func dictionary(for language: Language, game: String = "dictionary") async throws -> WordDictionary {
        let key = "\(language.id)/\(game)"
        if let cached = cache[key] { return cached }
        let loaded = try await Self.load(
            game: game,
            subdirectory: language.dictionarySubdirectory,
            pattern: language.validationRegex
        )
        cache[key] = loaded
        return loaded
    }

    @concurrent
    private nonisolated static func load(
        game: String,
        subdirectory: String,
        pattern: String
    ) async throws -> WordDictionary {
        guard let url = Bundle.main.url(forResource: game, withExtension: "json", subdirectory: subdirectory) else {
            throw DictionaryError.missing(language: subdirectory, game: game)
        }
        let data = try Data(contentsOf: url)
        let entries = try JSONDecoder().decode([WordEntry].self, from: data)
        let regex = try? Regex(pattern)
        let valid = entries.filter { isValidEntry($0, regex: regex) }
        guard valid.count >= 20 else {
            throw DictionaryError.tooSmall(validCount: valid.count)
        }
        return WordDictionary(entries: valid)
    }

    nonisolated static func isValidEntry(_ entry: WordEntry, regex: Regex<AnyRegexOutput>?) -> Bool {
        guard !entry.translation.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        let word = entry.word.trimmingCharacters(in: .whitespaces).lowercased()
        guard (3...8).contains(word.count) else { return false }
        guard let regex else { return true }
        return (try? regex.wholeMatch(in: word)) != nil
    }
}
