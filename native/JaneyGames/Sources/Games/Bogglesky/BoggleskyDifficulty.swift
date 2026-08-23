import Foundation

/// Difficulty tiers, values ported from web/mobile/bogglesky.html.
nonisolated enum BoggleskyDifficulty: String, CaseIterable, Identifiable, Sendable {
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

    var gridSize: Int {
        self == .hard ? 5 : 4
    }

    var gameTime: Int {
        self == .easy ? 150 : 120
    }

    var minWordLength: Int { 3 }

    var label: String {
        "\(gridSize)×\(gridSize) \(displayName)"
    }

    /// Hard mode scores 1.5×.
    func score(forWordLength length: Int) -> Int {
        let base = switch length {
        case ...3: 1
        case 4: 2
        case 5: 4
        case 6: 6
        default: length * 2
        }
        return self == .hard ? Int((Double(base) * 1.5).rounded()) : base
    }
}
