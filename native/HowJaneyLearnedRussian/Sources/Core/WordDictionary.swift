import Foundation

/// A validated, loaded dictionary for one (language, game) pair.
nonisolated struct WordDictionary: Sendable {
    let entries: [WordEntry]
    /// Lowercased word → translation, the lookup games validate against.
    let wordMap: [String: String]

    init(entries: [WordEntry]) {
        self.entries = entries
        var map: [String: String] = [:]
        map.reserveCapacity(entries.count)
        for entry in entries {
            map[entry.word.lowercased()] = entry.translation
        }
        wordMap = map
    }
}
