import Foundation

/// One answer as displayed at a shuffled position, with its visual state.
nonisolated struct TriviaAnswer: Identifiable, Hashable, Sendable {
    enum State: Hashable {
        /// Tappable.
        case normal
        /// Tried and wrong (red, disabled).
        case wrong
        /// Revealed as the correct answer (green).
        case correct
        /// Not tappable because the question is resolved.
        case disabled
    }

    let position: Int
    let text: String
    let translation: String?
    let state: State

    var id: Int { position }
}
