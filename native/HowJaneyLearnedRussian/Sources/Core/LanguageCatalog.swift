import Foundation

/// Loads and orders the language registry bundled as languages.json.
nonisolated enum LanguageCatalog {
    /// Preferred display order for known languages; unknown ones follow alphabetically.
    private static let preferredOrder = ["ru", "pt-br", "uk"]

    static let fallbackLanguageID = "ru"

    static func load(from bundle: Bundle = .main) -> [Language] {
        guard
            let url = bundle.url(forResource: "languages", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let dtos = try? JSONDecoder().decode([String: Language.DTO].self, from: data)
        else {
            return []
        }

        return dtos
            .map { Language(id: $0.key, dto: $0.value) }
            .sorted { lhs, rhs in
                let li = preferredOrder.firstIndex(of: lhs.id) ?? .max
                let ri = preferredOrder.firstIndex(of: rhs.id) ?? .max
                if li != ri { return li < ri }
                return lhs.id < rhs.id
            }
    }
}
