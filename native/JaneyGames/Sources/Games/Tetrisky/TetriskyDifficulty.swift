import Foundation

/// Difficulty tiers, values ported from web/mobile/tetrisky.html.
nonisolated enum TetriskyDifficulty: String, CaseIterable, Identifiable, Sendable {
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

    /// Milliseconds per gravity tick (speeds up as targets clear).
    var tickMilliseconds: Int {
        switch self {
        case .easy: 1200
        case .medium: 800
        case .hard: 500
        }
    }

    /// Hard mode hides the target word and translation.
    var showsTarget: Bool {
        self != .hard
    }
}
