import Foundation
import Observation

/// One Triviatsky session: date selection, question flow, star scoring,
/// per-question timers, resume, review mode, and calendar navigation.
/// Ported from the game controller in web/mobile/triviatsky.html.
@Observable
final class TriviatskyModel {
    enum Phase {
        case loading
        /// The selected date has no trivia.
        case noGame
        case start(canResume: Bool)
        case playing
        /// Completed day: browse questions via the tracker.
        case review
        case failed(String)
    }

    let language: Language

    private let soundEngine: SoundEngine
    private let triviaStore: TriviaStore
    private let dailyState: DailyStateService
    private let onComplete: (TriviatskyResult) -> Void

    // MARK: Day state

    private(set) var phase: Phase = .loading
    private(set) var dateKey = ""
    private(set) var questions: [TriviaQuestion] = []
    private(set) var state: TriviaDayState?
    private(set) var showNext = false
    private(set) var isPaused = false
    var isShowingResults = false
    var isShowingCalendar = false

    /// Easy mode: show English translations (persisted preference).
    var showTranslations: Bool {
        didSet { UserDefaults.standard.set(showTranslations, forKey: "triviatsky.translations") }
    }

    // MARK: Timer

    private(set) var timerRemaining: Int?
    private(set) var timerTotal = 0

    // MARK: Transient UI feedback

    private(set) var confettiTrigger = 0
    private(set) var wrongShakePosition: Int?
    private(set) var questionAppearance = 0
    private(set) var selectionTick = 0
    private(set) var successTick = 0
    private(set) var errorTick = 0

    // MARK: Private

    @ObservationIgnored private var allDays: [String: [TriviaQuestion]] = [:]
    @ObservationIgnored private var completedKeys: Set<String> = []
    @ObservationIgnored private var rng = SeedEngine(seed: Int.random(in: Int.min...Int.max))
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    /// When the current question appeared (speed-bonus timing).
    @ObservationIgnored private var questionShownAt: Date = .now

    init(
        language: Language,
        soundEngine: SoundEngine,
        triviaStore: TriviaStore,
        dailyState: DailyStateService,
        onComplete: @escaping (TriviatskyResult) -> Void
    ) {
        self.language = language
        self.soundEngine = soundEngine
        self.triviaStore = triviaStore
        self.dailyState = dailyState
        self.onComplete = onComplete
        showTranslations = UserDefaults.standard.object(forKey: "triviatsky.translations") as? Bool ?? true
    }

    var availableDateKeys: Set<String> {
        Set(allDays.keys)
    }

    var playedDateKeys: Set<String> {
        completedKeys
    }

    /// Whether this language's content carries translations at all.
    var hasTranslations: Bool {
        allDays.values.contains { $0.contains(where: \.hasTranslations) }
    }

    var friendlyDate: String {
        TriviaLogic.friendlyDate(fromKey: dateKey)
    }

    var currentQuestion: TriviaQuestion? {
        guard let state, questions.indices.contains(state.currentQuestionIndex) else { return nil }
        return questions[state.currentQuestionIndex]
    }

    var isCompleted: Bool {
        state?.completed ?? false
    }

    // MARK: - Loading & date selection

    func load() async {
        do {
            allDays = try await triviaStore.trivia(for: language)
            completedKeys = dailyState.completedDateKeys(game: .triviatsky, languageID: language.id)

            var initialKey = TriviaLogic.dateKey(for: .now)
            let arguments = ProcessInfo.processInfo.arguments
            if let flag = arguments.firstIndex(of: "-trivia-date"),
               arguments.indices.contains(flag + 1) {
                initialKey = arguments[flag + 1]
            }
            selectDate(initialKey)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func selectDate(_ key: String) {
        stopTimer()
        showNext = false
        isShowingResults = false
        isShowingCalendar = false
        dateKey = key

        guard let dayQuestions = allDays[key], !dayQuestions.isEmpty else {
            questions = []
            state = nil
            phase = .noGame
            return
        }
        questions = dayQuestions

        if let saved = dailyState.load(TriviaDayState.self, game: .triviatsky, languageID: language.id, dateKey: key),
           saved.matches(questions: dayQuestions) {
            state = saved
            if saved.completed {
                phase = .review
            } else if saved.started {
                phase = .start(canResume: true)
            } else {
                phase = .start(canResume: false)
            }
        } else {
            state = TriviaDayState(dateKey: key, questionCount: dayQuestions.count)
            phase = .start(canResume: false)
        }
    }

    // MARK: - Round flow

    func start() {
        guard var state, !state.completed else { return }
        state.started = true
        // Resume at the first unanswered question.
        if let firstOpen = state.revealed.firstIndex(of: false) {
            state.currentQuestionIndex = firstOpen
        }
        ensureOrder(&state, questionIndex: state.currentQuestionIndex)
        self.state = state
        phase = .playing
        showNext = false
        questionAppearance += 1
        questionShownAt = .now
        save()
        if state.revealed.allSatisfy({ $0 }) {
            // Every question was already revealed (interrupted right at the end).
            complete()
        } else {
            startTimerIfNeeded()
        }
    }

    /// Answers at their shuffled positions with current visual state.
    var displayedAnswers: [TriviaAnswer] {
        guard let state, let question = currentQuestion else { return [] }
        let qi = state.currentQuestionIndex
        let order = state.answerOrder[qi].isEmpty
            ? Array(0..<question.answers.count)
            : state.answerOrder[qi]
        let correctPosition = TriviaLogic.correctPosition(order: order, correctIndex: question.correctIndex)
        let revealed = state.revealed[qi]

        return order.enumerated().map { position, originalIndex in
            let answerState: TriviaAnswer.State =
                if revealed && position == correctPosition {
                    .correct
                } else if state.disabledOptions[qi].contains(position) {
                    .wrong
                } else if revealed {
                    .disabled
                } else {
                    .normal
                }
            return TriviaAnswer(
                position: position,
                text: question.answers[originalIndex],
                translation: question.answerTranslations?.indices.contains(originalIndex) == true
                    ? question.answerTranslations?[originalIndex]
                    : nil,
                state: answerState
            )
        }
    }

    func selectAnswer(at position: Int) {
        guard case .playing = phase, !isPaused else { return }
        guard var state, let question = currentQuestion else { return }
        let qi = state.currentQuestionIndex
        guard !state.revealed[qi], !state.disabledOptions[qi].contains(position) else { return }

        let correctPosition = TriviaLogic.correctPosition(
            order: state.answerOrder[qi],
            correctIndex: question.correctIndex
        )

        if position == correctPosition {
            // Perfect + under 5 seconds → gold bolt.
            if state.questionScores[qi] == 5,
               Date.now.timeIntervalSince(questionShownAt) < 5,
               state.fastAnswers.indices.contains(qi) {
                state.fastAnswers[qi] = true
            }
            self.state = state
            soundEngine.play(.correct)
            successTick += 1
            confettiTrigger += 1
            reveal(questionIndex: qi)
        } else {
            state.disabledOptions[qi].append(position)
            state.questionScores[qi] = max(0, state.questionScores[qi] - 1)
            self.state = state
            soundEngine.play(.wrong)
            errorTick += 1
            wrongShakePosition = position
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(500))
                if self?.wrongShakePosition == position {
                    self?.wrongShakePosition = nil
                }
            }
            // All wrong options exhausted → auto-reveal the correct answer.
            if state.disabledOptions[qi].count >= question.answers.count - 1 {
                reveal(questionIndex: qi)
            } else {
                save()
            }
        }
    }

    func next() {
        guard case .playing = phase, var state else { return }
        guard state.currentQuestionIndex < questions.count - 1 else { return }
        state.currentQuestionIndex += 1
        ensureOrder(&state, questionIndex: state.currentQuestionIndex)
        self.state = state
        showNext = false
        selectionTick += 1
        questionAppearance += 1
        questionShownAt = .now
        save()
        startTimerIfNeeded()
    }

    private func reveal(questionIndex qi: Int) {
        guard var state else { return }
        state.revealed[qi] = true
        self.state = state
        stopTimer()
        if qi == questions.count - 1 {
            complete()
        } else {
            showNext = true
            save()
        }
    }

    private func complete() {
        guard var state, !state.completed else { return }
        state.completed = true
        self.state = state
        stopTimer()
        save()
        completedKeys.insert(dateKey)
        soundEngine.play(.gameEnd)
        successTick += 1
        isShowingResults = true
        onComplete(
            TriviatskyResult(
                languageID: language.id,
                dateKey: dateKey,
                score: state.totalScore,
                maxScore: state.maxScore,
                questionCount: questions.count
            )
        )
    }

    /// Close the results card and browse answers via the tracker.
    func enterReview() {
        isShowingResults = false
        phase = .review
    }

    func showQuestion(_ index: Int) {
        guard case .review = phase, var state, questions.indices.contains(index) else { return }
        state.currentQuestionIndex = index
        self.state = state
        selectionTick += 1
        questionAppearance += 1
    }

    /// Question text for results rows.
    func questionText(at index: Int) -> String {
        questions.indices.contains(index) ? questions[index].question : ""
    }

    var shareText: String {
        guard let state else { return "" }
        var lines = ["Triviatsky \(friendlyDate)"]
        // Wordle-style grid: same-day puzzles make results comparable.
        let grid = state.questionScores.enumerated().map { i, score in
            let square = score == 5 ? "🟩" : score >= 3 ? "🟨" : "🟥"
            let bolt = state.fastAnswers.indices.contains(i) && state.fastAnswers[i] ? "⚡" : ""
            return square + bolt
        }.joined()
        lines.append(grid)
        for (i, score) in state.questionScores.enumerated() {
            let stars = String(repeating: "★", count: score) + String(repeating: "☆", count: 5 - score)
            lines.append("Q\(i + 1): \(stars)")
        }
        lines.append("Total: \(state.totalScore)/\(state.maxScore)")
        return lines.joined(separator: "\n")
    }

    // MARK: - Timer

    func setPaused(_ paused: Bool) {
        guard case .playing = phase else { return }
        isPaused = paused
    }

    private func startTimerIfNeeded() {
        stopTimer()
        guard let state, let question = currentQuestion,
              let seconds = question.timerSeconds, seconds > 0,
              !state.revealed[state.currentQuestionIndex]
        else { return }
        timerTotal = seconds
        timerRemaining = seconds
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.timerTick()
            }
        }
    }

    private func timerTick() {
        guard case .playing = phase, !isPaused, let remaining = timerRemaining else { return }
        let next = remaining - 1
        timerRemaining = next
        if next > 0, next <= 5 {
            soundEngine.play(.tick)
        }
        if next <= 0 {
            timerExpired()
        }
    }

    private func timerExpired() {
        stopTimer()
        guard var state else { return }
        let qi = state.currentQuestionIndex
        guard !state.revealed[qi] else { return }
        state.questionScores[qi] = 0
        self.state = state
        soundEngine.play(.wrong)
        errorTick += 1
        reveal(questionIndex: qi)
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
        timerRemaining = nil
    }

    // MARK: - Helpers

    private func ensureOrder(_ state: inout TriviaDayState, questionIndex: Int) {
        guard questions.indices.contains(questionIndex), state.answerOrder[questionIndex].isEmpty else { return }
        state.answerOrder[questionIndex] = TriviaLogic.shuffledOrder(
            count: questions[questionIndex].answers.count,
            rng: &rng
        )
    }

    private func save() {
        guard let state else { return }
        dailyState.save(
            state,
            game: .triviatsky,
            languageID: language.id,
            dateKey: dateKey,
            completed: state.completed
        )
    }
}
