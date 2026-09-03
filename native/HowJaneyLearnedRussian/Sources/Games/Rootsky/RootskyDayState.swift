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

    init(dateKey: String, wordCount: Int = RootskyModel.wordsPerDay) {
        self.dateKey = dateKey
        currentWordIndex = 0
        wordScores = Array(repeating: 5, count: wordCount)
        disabledAnswers = Array(repeating: [], count: wordCount)
        completed = false
        started = false
        elapsedSeconds = 0
        wordTimes = Array(repeating: 0, count: wordCount)
    }

    var totalScore: Int {
        wordScores.reduce(0, +)
    }

    func isShapeValid(wordCount: Int) -> Bool {
        wordScores.count == wordCount && disabledAnswers.count == wordCount && wordTimes.count == wordCount
    }
}
