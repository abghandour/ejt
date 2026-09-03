import Foundation

/// Pure helpers for Triviatsky: answer shuffling and date-key handling.
nonisolated enum TriviaLogic {
    /// Fisher-Yates permutation of answer positions. `order[position]` is the
    /// original answer index shown at that position — the persisted form of the
    /// web's shuffled-answers-with-tracked-correct-index.
    static func shuffledOrder(count: Int, rng: inout SeedEngine) -> [Int] {
        rng.shuffle(Array(0..<count))
    }

    /// Where the correct answer landed in a shuffled order.
    static func correctPosition(order: [Int], correctIndex: Int) -> Int {
        order.firstIndex(of: correctIndex) ?? 0
    }

    /// YYYYMMDD key for a date, matching the dictionaries.
    static func dateKey(for date: Date, calendar: Calendar = .current) -> String {
        let c = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d%02d%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0)
    }

    static func date(fromKey key: String, calendar: Calendar = .current) -> Date? {
        guard key.count == 8,
              let year = Int(key.prefix(4)),
              let month = Int(key.dropFirst(4).prefix(2)),
              let day = Int(key.suffix(2))
        else { return nil }
        return calendar.date(from: DateComponents(year: year, month: month, day: day))
    }

    /// "Sat, Mar 7, 2026"-style label for the top bar and results.
    static func friendlyDate(fromKey key: String, calendar: Calendar = .current) -> String {
        guard let date = date(fromKey: key, calendar: calendar) else { return "" }
        return date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().year())
    }

    /// Compact "9/12"-style label (numeric month/day, no padding) for the tight
    /// in-game header pill, where the long form wraps on narrow screens.
    static func shortDate(fromKey key: String, calendar: Calendar = .current) -> String {
        guard let date = date(fromKey: key, calendar: calendar) else { return "" }
        return date.formatted(.dateTime.month(.defaultDigits).day(.defaultDigits))
    }
}
