import Foundation

/// A game as offered for a specific language: identity plus localized display metadata.
nonisolated struct GameInfo: Identifiable, Hashable, Sendable {
    let game: GameID
    let name: String
    let desc: String

    var id: GameID { game }
    var symbol: String { game.symbol }
    var isPlayable: Bool { game.isPlayable }

    /// The games a language offers, in the order languages.json lists them.
    static func games(for language: Language) -> [GameInfo] {
        language.games.compactMap { rawID in
            guard let game = GameID(rawValue: rawID) else { return nil }
            let names = language.gameNames[rawID]
            return GameInfo(
                game: game,
                name: names?.name ?? rawID.capitalized,
                desc: names?.desc ?? ""
            )
        }
    }
}
