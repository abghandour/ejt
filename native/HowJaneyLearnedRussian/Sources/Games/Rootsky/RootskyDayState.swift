import Foundation

/// Persistent per-day play state (the old `rootsky_state_<date>` blob),
/// stored via `DailyStateRecord`.
nonisolated struct RootskyDayState: Codable, Equatable, Sendable {
    var dateKey: String
    var currentWordIndex: Int
    /// 5 stars per word, −1 per wrong answer, floor 0.
    var wordScores: [Int]
    /// Wrong answer strings already tried per word (answers reshuffle per view,
    /// so wrongs are tracked by text — same as the web).
    var disabledAnswers: [[String]]
    var completed: Bool
    var started: Bool
    /// Count-up stopwatch total.
    var elapsedSeconds: Int
    /// Seconds spent on each word.
    var wordTimes: [Int]

    init(dateKey: String) {
        self.dateKey = dateKey
        currentWordIndex = 0
        wordScores = Array(repeating: 5, count: 5)
        disabledAnswers = Array(repeating: [], count: 5)
        completed = false
        started = false
        elapsedSeconds = 0
        wordTimes = Array(repeating: 0, count: 5)
    }

    var totalScore: Int {
        wordScores.reduce(0, +)
    }

    var isShapeValid: Bool {
        wordScores.count == 5 && disabledAnswers.count == 5 && wordTimes.count == 5
    }
}
