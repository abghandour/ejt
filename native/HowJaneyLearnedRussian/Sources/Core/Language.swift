import Foundation

/// One entry from languages.json — fully data-driven so adding a language is
/// a JSON edit plus a dictionary folder, no code changes.
nonisolated struct Language: Identifiable, Hashable, Sendable {
    struct GameName: Hashable, Sendable, Decodable {
        let name: String
        let desc: String
    }

    let id: String
    let displayName: String
    let games: [String]
    let themes: [String]
    let letterPool: String
    let validationRegex: String
    let gameNames: [String: GameName]

    /// Bundle subdirectory holding this language's dictionaries.
    var dictionarySubdirectory: String { "Dictionaries/\(id)" }

    /// Flag emoji for pickers, derived data-free from the language id.
    var flag: String {
        switch id {
        case "ru": "🇷🇺"
        case "pt-br": "🇧🇷"
        case "uk": "🇺🇦"
        default: "🌐"
        }
    }
}

nonisolated extension Language {
    struct DTO: Decodable {
        let displayName: String
        let games: [String]
        let themes: [String]
        let letterPool: String
        let validationRegex: String
        let gameNames: [String: GameName]
    }

    init(id: String, dto: DTO) {
        self.init(
            id: id,
            displayName: dto.displayName,
            games: dto.games,
            themes: dto.themes,
            letterPool: dto.letterPool,
            validationRegex: dto.validationRegex,
            gameNames: dto.gameNames
        )
    }
}
