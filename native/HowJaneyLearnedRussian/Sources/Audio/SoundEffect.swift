import Foundation

/// Every sound the games make, described as layered voices in the style of
/// modern system sounds: FM bells (glassy attack that mellows), band-passed
/// noise transients (the "tap" texture), pitch glides, and detuned shimmer.
/// Rendered once at startup into cached PCM buffers; a room reverb at
/// playback adds the air.
nonisolated enum SoundEffect: Hashable, Sendable {
    /// Tile added to the path; `step` climbs a pentatonic ladder as the word grows.
    case select(step: Int)
    /// Path shrank back one tile.
    case deselect
    /// Valid word submitted.
    case correct
    /// Invalid or duplicate word.
    case wrong
    /// Time penalty applied (hint/shuffle/skip).
    case penalty
    /// Whole board solved.
    case boardClear
    /// Round finished.
    case gameEnd
    /// Final-seconds clock tick.
    case tick
    /// Tiles blasting away between words.
    case explode
    /// A fresh word arriving.
    case newWord
    /// Blade whoosh at the start of a Slashsky swipe.
    case slash

    static let maxSelectSteps = 12

    /// One synthesized voice inside a sound.
    struct Layer: Sendable {
        enum Timbre: Sendable {
            /// Two-operator FM bell — bright glassy attack mellowing as the
            /// modulation index decays. The core "modern UI" tone.
            case bell(modRatio: Double, modIndex: Double)
            /// Plain sine — soft thuds and sub weight.
            case sine
            /// Band-passed white noise — taps, ticks, whooshes, sparkle.
            case noise(q: Double)
        }

        var timbre: Timbre
        /// Start frequency (band center for noise).
        var frequency: Double
        /// Optional glide target reached by the end of the layer.
        var endFrequency: Double?
        var start: Double = 0
        var duration: Double
        var gain: Double
        var attack: Double = 0.003
    }

    /// Major-pentatonic ladder starting at C5 for the select pops.
    private static func pentatonic(_ step: Int) -> Double {
        let degrees = [0, 2, 4, 7, 9]
        let clamped = min(max(step, 0), maxSelectSteps - 1)
        let semitones = Double(degrees[clamped % 5] + 12 * (clamped / 5))
        return 523.25 * pow(2, semitones / 12)
    }

    /// A bell plus a faintly detuned twin — the shimmer that makes long
    /// tones sound expensive instead of electronic.
    private static func shimmerBell(
        _ frequency: Double,
        start: Double = 0,
        duration: Double,
        gain: Double,
        modRatio: Double = 3.5,
        modIndex: Double = 2.0
    ) -> [Layer] {
        [
            Layer(
                timbre: .bell(modRatio: modRatio, modIndex: modIndex),
                frequency: frequency, start: start, duration: duration, gain: gain
            ),
            Layer(
                timbre: .bell(modRatio: modRatio, modIndex: modIndex * 0.8),
                frequency: frequency * 1.004, start: start, duration: duration, gain: gain * 0.45
            ),
        ]
    }

    var layers: [Layer] {
        switch self {
        case .select(let step):
            let frequency = Self.pentatonic(step)
            return [
                // Fingertip tap texture.
                Layer(timbre: .noise(q: 3), frequency: 2400, endFrequency: 1600,
                      duration: 0.03, gain: 0.05, attack: 0.001),
                // Marimba-like pop.
                Layer(timbre: .bell(modRatio: 3.01, modIndex: 1.6), frequency: frequency,
                      duration: 0.13, gain: 0.15, attack: 0.002),
            ]
        case .deselect:
            return [
                Layer(timbre: .noise(q: 3), frequency: 1600, endFrequency: 1100,
                      duration: 0.025, gain: 0.035, attack: 0.001),
                Layer(timbre: .bell(modRatio: 3.01, modIndex: 1.2), frequency: Self.pentatonic(0) * 0.75,
                      duration: 0.11, gain: 0.09, attack: 0.002),
            ]
        case .correct:
            return Self.shimmerBell(659.25, duration: 0.3, gain: 0.13)
                + Self.shimmerBell(783.99, start: 0.07, duration: 0.3, gain: 0.13)
                + Self.shimmerBell(1046.5, start: 0.14, duration: 0.5, gain: 0.15)
                + [
                    // Airy sparkle riding the top note.
                    Layer(timbre: .noise(q: 6), frequency: 5200, endFrequency: 6800,
                          start: 0.14, duration: 0.12, gain: 0.03),
                ]
        case .wrong:
            return [
                // Muted double thud with a downward bend — firm, not buzzy.
                Layer(timbre: .sine, frequency: 220, endFrequency: 168,
                      duration: 0.16, gain: 0.14, attack: 0.004),
                Layer(timbre: .sine, frequency: 165, endFrequency: 126,
                      start: 0.11, duration: 0.2, gain: 0.12, attack: 0.004),
                Layer(timbre: .noise(q: 1.4), frequency: 240, endFrequency: 150,
                      duration: 0.07, gain: 0.05, attack: 0.001),
            ]
        case .penalty:
            return [
                Layer(timbre: .bell(modRatio: 2.0, modIndex: 1.0), frequency: 392, endFrequency: 360,
                      duration: 0.13, gain: 0.11),
                Layer(timbre: .bell(modRatio: 2.0, modIndex: 1.0), frequency: 311, endFrequency: 282,
                      start: 0.1, duration: 0.2, gain: 0.11),
            ]
        case .boardClear:
            let run = [523.25, 659.25, 783.99, 1046.5].enumerated().flatMap { index, frequency in
                Self.shimmerBell(frequency, start: Double(index) * 0.055, duration: 0.2, gain: 0.12)
            }
            return run
                + Self.shimmerBell(1318.5, start: 0.22, duration: 0.55, gain: 0.14)
                + [
                    Layer(timbre: .noise(q: 6), frequency: 4800, endFrequency: 7200,
                          start: 0.22, duration: 0.16, gain: 0.035),
                ]
        case .gameEnd:
            return Self.shimmerBell(523.25, duration: 0.9, gain: 0.11, modIndex: 2.4)
                + Self.shimmerBell(659.25, start: 0.012, duration: 0.9, gain: 0.10, modIndex: 2.4)
                + Self.shimmerBell(783.99, start: 0.025, duration: 0.9, gain: 0.10, modIndex: 2.4)
                + Self.shimmerBell(1046.5, start: 0.24, duration: 1.1, gain: 0.13, modIndex: 2.2)
                + [
                    Layer(timbre: .noise(q: 7), frequency: 5600, endFrequency: 7600,
                          start: 0.24, duration: 0.2, gain: 0.03),
                    // Sub warmth underneath the chord.
                    Layer(timbre: .sine, frequency: 130.8, duration: 0.7, gain: 0.05, attack: 0.01),
                ]
        case .tick:
            return [
                // Woodblock: resonant knock plus the tiniest bell.
                Layer(timbre: .noise(q: 9), frequency: 1800, duration: 0.025, gain: 0.06, attack: 0.001),
                Layer(timbre: .bell(modRatio: 4.2, modIndex: 0.8), frequency: 1244,
                      duration: 0.045, gain: 0.035, attack: 0.001),
            ]
        case .explode:
            return [
                // Falling rumble with a sub thump.
                Layer(timbre: .noise(q: 1.1), frequency: 900, endFrequency: 140,
                      duration: 0.32, gain: 0.17, attack: 0.002),
                Layer(timbre: .sine, frequency: 95, endFrequency: 42,
                      duration: 0.26, gain: 0.13, attack: 0.002),
            ]
        case .newWord:
            return Self.shimmerBell(880, duration: 0.14, gain: 0.10, modIndex: 2.2)
                + Self.shimmerBell(1318.5, start: 0.07, duration: 0.24, gain: 0.10, modIndex: 2.2)
        case .slash:
            return [
                // Air being cut: fast falling band sweep with a bright edge.
                Layer(timbre: .noise(q: 2.2), frequency: 4500, endFrequency: 850,
                      duration: 0.16, gain: 0.11, attack: 0.002),
                Layer(timbre: .noise(q: 4), frequency: 7000, endFrequency: 2200,
                      duration: 0.1, gain: 0.05, attack: 0.001),
            ]
        }
    }

    /// Total rendered length in seconds (the reverb adds its own live tail).
    var length: Double {
        (layers.map { $0.start + $0.duration }.max() ?? 0) + 0.06
    }
}
