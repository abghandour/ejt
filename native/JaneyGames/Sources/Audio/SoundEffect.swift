import Foundation

/// Every sound the games make. Each effect is a short procedural note sequence
/// in one timbre family, rendered once at startup and cached as a PCM buffer.
nonisolated enum SoundEffect: Hashable, Sendable {
    /// Tile added to the path; `step` climbs a pentatonic ladder as the word grows.
    case select(step: Int)
    /// Path shrank back one tile.
    case deselect
    /// Valid word submitted.
    case correct
    /// Invalid or duplicate word.
    case wrong
    /// Time penalty applied (hint/shuffle).
    case penalty
    /// Whole board solved.
    case boardClear
    /// Round finished.
    case gameEnd
    /// Final-seconds clock tick.
    case tick
    /// Tiles blasting away between words (Scramblisky transition).
    case explode
    /// A fresh word arriving (Rootsky word launch).
    case newWord
    /// Blade whoosh at the start of a Slashsky swipe.
    case slash

    static let maxSelectSteps = 12

    /// One synthesized note: frequency (Hz), start offset, duration, peak gain.
    struct Note: Sendable {
        let frequency: Double
        let start: Double
        let duration: Double
        let gain: Double
        /// 0 = pure sine, 1 = bright (adds stronger upper harmonics).
        let brightness: Double

        init(_ frequency: Double, start: Double = 0, duration: Double, gain: Double, brightness: Double = 0.3) {
            self.frequency = frequency
            self.start = start
            self.duration = duration
            self.gain = gain
            self.brightness = brightness
        }
    }

    /// Major-pentatonic ladder starting at C5 for the select arpeggio.
    private static func pentatonic(_ step: Int) -> Double {
        let degrees = [0, 2, 4, 7, 9]
        let clamped = min(max(step, 0), maxSelectSteps - 1)
        let semitones = Double(degrees[clamped % 5] + 12 * (clamped / 5))
        return 523.25 * pow(2, semitones / 12)
    }

    var notes: [Note] {
        switch self {
        case .select(let step):
            [Note(Self.pentatonic(step), duration: 0.07, gain: 0.10, brightness: 0.25)]
        case .deselect:
            [Note(Self.pentatonic(0) * 0.75, duration: 0.06, gain: 0.07, brightness: 0.15)]
        case .correct:
            [
                Note(523.25, duration: 0.16, gain: 0.14),
                Note(659.25, start: 0.07, duration: 0.16, gain: 0.14),
                Note(783.99, start: 0.14, duration: 0.20, gain: 0.16),
                Note(1046.50, start: 0.22, duration: 0.28, gain: 0.10, brightness: 0.5),
            ]
        case .wrong:
            [
                Note(233.08, duration: 0.16, gain: 0.10, brightness: 0.7),
                Note(207.65, start: 0.07, duration: 0.22, gain: 0.08, brightness: 0.7),
            ]
        case .penalty:
            [
                Note(392.00, duration: 0.12, gain: 0.10, brightness: 0.5),
                Note(311.13, start: 0.10, duration: 0.20, gain: 0.10, brightness: 0.5),
            ]
        case .boardClear:
            [
                Note(523.25, duration: 0.10, gain: 0.12),
                Note(587.33, start: 0.07, duration: 0.10, gain: 0.12),
                Note(659.25, start: 0.14, duration: 0.10, gain: 0.12),
                Note(783.99, start: 0.21, duration: 0.12, gain: 0.13),
                Note(1046.50, start: 0.28, duration: 0.30, gain: 0.12, brightness: 0.5),
            ]
        case .gameEnd:
            [
                Note(523.25, duration: 0.20, gain: 0.13),
                Note(659.25, start: 0.15, duration: 0.20, gain: 0.13),
                Note(783.99, start: 0.30, duration: 0.20, gain: 0.13),
                Note(1046.50, start: 0.45, duration: 0.45, gain: 0.15, brightness: 0.4),
            ]
        case .tick:
            [Note(1200, duration: 0.03, gain: 0.05, brightness: 0.8)]
        case .explode:
            [
                Note(150, duration: 0.15, gain: 0.09, brightness: 0.9),
                Note(100, start: 0.05, duration: 0.20, gain: 0.07, brightness: 0.9),
            ]
        case .newWord:
            [
                Note(880, duration: 0.15, gain: 0.08),
                Note(1100, start: 0.10, duration: 0.20, gain: 0.06),
            ]
        case .slash:
            [
                Note(1600, duration: 0.04, gain: 0.05, brightness: 1),
                Note(1100, start: 0.02, duration: 0.05, gain: 0.04, brightness: 1),
                Note(700, start: 0.05, duration: 0.06, gain: 0.03, brightness: 0.9),
            ]
        }
    }

    /// Total rendered length in seconds.
    var length: Double {
        (notes.map { $0.start + $0.duration }.max() ?? 0) + 0.05
    }
}
