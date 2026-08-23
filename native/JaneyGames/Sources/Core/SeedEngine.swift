import Foundation

/// Deterministic mulberry32 PRNG, bit-exact with `SeedEngine` in web/shared/engine.js
/// so daily/seeded content matches the web version for the same seed.
nonisolated struct SeedEngine: Sendable {
    private var state: Int32

    init(seed: Int) {
        state = Int32(truncatingIfNeeded: seed)
    }

    /// Returns a uniform value in [0, 1).
    mutating func next() -> Double {
        state = state &+ 0x6D2B_79F5
        let s = UInt32(bitPattern: state)
        var t = (s ^ (s >> 15)) &* (1 | s)
        t = (t &+ ((t ^ (t >> 7)) &* (61 | t))) ^ t
        return Double(t ^ (t >> 14)) / 4_294_967_296
    }

    /// Returns an integer in 0..<max.
    mutating func nextInt(_ max: Int) -> Int {
        Int(next() * Double(max))
    }

    /// Seeded Fisher-Yates shuffle, identical ordering to the JS engine.
    mutating func shuffle<T>(_ array: [T]) -> [T] {
        var a = array
        guard a.count > 1 else { return a }
        for i in stride(from: a.count - 1, through: 1, by: -1) {
            let j = nextInt(i + 1)
            a.swapAt(i, j)
        }
        return a
    }
}
