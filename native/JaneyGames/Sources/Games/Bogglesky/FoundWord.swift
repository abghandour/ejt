import Foundation

/// A word the player traced successfully during a round.
nonisolated struct FoundWord: Identifiable, Hashable, Sendable {
    let word: String
    let translation: String
    let points: Int

    var id: String { word }
}
