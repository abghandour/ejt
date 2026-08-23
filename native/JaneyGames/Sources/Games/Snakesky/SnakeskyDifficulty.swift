import Foundation

/// Difficulty tiers, values ported from web/mobile/snakesky.html.
nonisolated enum SnakeskyDifficulty: String, CaseIterable, Identifiable, Sendable {
    case easy, medium, hard

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }

    var symbol: String {
        switch self {
        case .easy: "leaf"
        case .medium: "shield"
        case .hard: "flame"
        }
    }

    /// Milliseconds per snake step.
    var tickMilliseconds: Int {
        switch self {
        case .easy: 330
        case .medium: 275
        case .hard: 220
        }
    }

    /// Hard mode hides which letter comes next.
    var showsNextLetterHint: Bool {
        self != .hard
    }
}
