import Foundation

/// Difficulty tiers, values ported from web/mobile/scramblisky.html.
nonisolated enum ScramblisyDifficulty: String, CaseIterable, Identifiable, Sendable {
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

    /// Word length band drawn from the dictionary.
    var wordLengthRange: ClosedRange<Int> {
        switch self {
        case .easy: 3...4
        case .medium: 5...7
        case .hard: 8...99
        }
    }

    /// Seconds lost on a wrong answer (skip is always −10s).
    var wrongPenaltySeconds: Int {
        self == .easy ? 15 : 20
    }

    /// Whether the Clear button is offered.
    var allowsClear: Bool {
        self != .hard
    }

    enum HintMode {
        /// Translation always visible.
        case always
        /// Lamp button reveals the translation per word.
        case onRequest
        /// No hint.
        case never
    }

    var hintMode: HintMode {
        switch self {
        case .easy: .always
        case .medium: .onRequest
        case .hard: .never
        }
    }

    /// Word length × 10, hard ×1.5.
    func score(forWordLength length: Int) -> Int {
        let base = length * 10
        return self == .hard ? Int((Double(base) * 1.5).rounded()) : base
    }
}
