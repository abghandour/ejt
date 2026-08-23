import Foundation

/// Persistent per-day play state (the old `triviatsky_state_<lang>_<date>`
/// localStorage blob). Stored as JSON in a `DailyStateRecord`.
nonisolated struct TriviaDayState: Codable, Equatable, Sendable {
    var dateKey: String
    var currentQuestionIndex: Int
    /// 5 stars per question, −1 per wrong tap, floor 0; timer expiry → 0.
    var questionScores: [Int]
    /// Shuffled answer positions already tried and wrong, per question.
    var disabledOptions: [[Int]]
    var revealed: [Bool]
    /// Per question: permutation mapping shuffled position → original answer index.
    /// Persisted so a resumed game keeps its shuffle order.
    var answerOrder: [[Int]]
    var started: Bool
    var completed: Bool
    /// Questions answered perfectly in under 5 seconds (gold-bolt bonus).
    var fastAnswers: [Bool]

    init(dateKey: String, questionCount: Int) {
        self.dateKey = dateKey
        currentQuestionIndex = 0
        questionScores = Array(repeating: 5, count: questionCount)
        disabledOptions = Array(repeating: [], count: questionCount)
        revealed = Array(repeating: false, count: questionCount)
        answerOrder = Array(repeating: [], count: questionCount)
        started = false
        completed = false
        fastAnswers = Array(repeating: false, count: questionCount)
    }

    /// Backward-compatible decoding: `fastAnswers` was added after launch.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        dateKey = try container.decode(String.self, forKey: .dateKey)
        currentQuestionIndex = try container.decode(Int.self, forKey: .currentQuestionIndex)
        questionScores = try container.decode([Int].self, forKey: .questionScores)
        disabledOptions = try container.decode([[Int]].self, forKey: .disabledOptions)
        revealed = try container.decode([Bool].self, forKey: .revealed)
        answerOrder = try container.decode([[Int]].self, forKey: .answerOrder)
        started = try container.decode(Bool.self, forKey: .started)
        completed = try container.decode(Bool.self, forKey: .completed)
        fastAnswers = try container.decodeIfPresent([Bool].self, forKey: .fastAnswers)
            ?? Array(repeating: false, count: questionScores.count)
    }

    var totalScore: Int {
        questionScores.reduce(0, +)
    }

    var maxScore: Int {
        questionScores.count * 5
    }

    /// True when the stored shape matches the day's questions (guards against
    /// content updates changing a day after a partial play).
    func matches(questions: [TriviaQuestion]) -> Bool {
        questionScores.count == questions.count
            && zip(answerOrder, questions).allSatisfy { order, question in
                order.isEmpty || order.sorted() == Array(0..<question.answers.count)
            }
    }
}
