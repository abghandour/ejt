import Foundation

/// Soviet-flavored progression ladder. XP is the lifetime sum of all scores
/// across every game and language — every round moves the player forward.
nonisolated struct Rank: Equatable, Sendable {
    let index: Int
    let name: String
    let nativeName: String
    let threshold: Int

    static let ladder: [Rank] = [
        Rank(index: 0, name: "Cadet", nativeName: "Кадет", threshold: 0),
        Rank(index: 1, name: "Private", nativeName: "Рядовой", threshold: 250),
        Rank(index: 2, name: "Corporal", nativeName: "Ефрейтор", threshold: 750),
        Rank(index: 3, name: "Sergeant", nativeName: "Сержант", threshold: 1_500),
        Rank(index: 4, name: "Lieutenant", nativeName: "Лейтенант", threshold: 3_000),
        Rank(index: 5, name: "Captain", nativeName: "Капитан", threshold: 6_000),
        Rank(index: 6, name: "Major", nativeName: "Майор", threshold: 10_000),
        Rank(index: 7, name: "Colonel", nativeName: "Полковник", threshold: 18_000),
        Rank(index: 8, name: "Commissar", nativeName: "Комиссар", threshold: 30_000),
        Rank(index: 9, name: "General", nativeName: "Генерал", threshold: 50_000),
        Rank(index: 10, name: "Marshal", nativeName: "Маршал", threshold: 85_000),
    ]

    static func rank(forXP xp: Int) -> Rank {
        ladder.last { xp >= $0.threshold } ?? ladder[0]
    }

    var next: Rank? {
        Self.ladder.indices.contains(index + 1) ? Self.ladder[index + 1] : nil
    }

    /// 0…1 progress from this rank toward the next (1 at the top rank).
    static func progress(forXP xp: Int) -> Double {
        let current = rank(forXP: xp)
        guard let next = current.next else { return 1 }
        let span = Double(next.threshold - current.threshold)
        guard span > 0 else { return 1 }
        return min(1, max(0, Double(xp - current.threshold) / span))
    }

    /// Star pips shown on the insignia (1–5, wrapping to filled medals).
    var stars: Int {
        index % 5 + 1
    }
}
