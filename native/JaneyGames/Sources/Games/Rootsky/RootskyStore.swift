import Foundation
import Observation

/// Loads and caches date-keyed daily-word data for a language. Shared by
/// Rootsky and Wordsky (whose JSON is the same shape minus root fields).
/// A day is playable only when it has at least 5 valid words (first 5 used).
@Observable
final class RootskyStore {
    /// Dictionary file name: "rootsky" or "wordsky".
    private let resource: String
    private var cache: [String: [String: [RootskyWord]]] = [:]

    init(resource: String = "rootsky") {
        self.resource = resource
    }

    func words(for language: Language) async throws -> [String: [RootskyWord]] {
        if let cached = cache[language.id] { return cached }
        let loaded = try await Self.load(resource: resource, subdirectory: language.dictionarySubdirectory)
        cache[language.id] = loaded
        return loaded
    }

    @concurrent
    private nonisolated static func load(resource: String, subdirectory: String) async throws -> [String: [RootskyWord]] {
        guard let url = Bundle.main.url(forResource: resource, withExtension: "json", subdirectory: subdirectory) else {
            throw DictionaryError.missing(language: subdirectory, game: resource)
        }
        let data = try Data(contentsOf: url)
        let days = try JSONDecoder().decode([String: [RootskyWord]].self, from: data)
        return days
            .mapValues { Array($0.filter(\.isValid).prefix(5)) }
            .filter { $0.value.count == 5 }
    }
}
