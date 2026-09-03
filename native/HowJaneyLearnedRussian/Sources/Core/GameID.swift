import Foundation

/// Every game in the collection. A language's `games` array (languages.json)
/// controls which of these are offered for that language.
nonisolated enum GameID: String, CaseIterable, Identifiable, Sendable {
    case bogglesky
    case scramblisky
    case rootsky
    case triviatsky
    case snakesky
    case slashsky
    case tetrisky
    case wordsky
    case meddleysky

    var id: String { rawValue }

    /// SF Symbol used on game cards.
    var symbol: String {
        switch self {
        case .bogglesky: "square.grid.3x3.square"
        case .scramblisky: "shuffle"
        case .rootsky: "tree"
        case .triviatsky: "questionmark.bubble"
        case .snakesky: "lizard"
        case .slashsky: "scissors"
        case .tetrisky: "square.stack.3d.down.right"
        case .wordsky: "character.book.closed"
        case .meddleysky: "dice.fill"
        }
    }

    /// Every game in the collection is now implemented natively.
    var isPlayable: Bool {
        true
    }
}
