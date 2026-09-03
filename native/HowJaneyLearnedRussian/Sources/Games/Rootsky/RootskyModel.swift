import Foundation
import Observation

/// One Rootsky session: five daily words sharing a root, 5-star scoring per
/// word, count-up stopwatch with per-word times, resume, and review mode.
/// Ported from the game controller in web/mobile/rootsky.html.
@Observable
final class RootskyModel {
    enum Phase {
        case loading
        case noGame
        case start(canResume: Bool)
        case playing
        case review
        case failed(String)
    }

    nonisolated static let wordsPerDay = 5
    nonisolated static let maxScore = 25

    /// `.rootsky` or `.wordsky` — the model runs both daily word games.
    let game: GameID
    let language: Language
    /// Words per round: 5 for the daily puzzle, fewer for Meddleysky levels.
    let wordCount: Int
    /// Sandboxed sessions (Meddleysky) play a random past day and never touch
    /// the calendar, saved progress, or the results sheet.
    let isSandboxed: Bool
    /// Replaces the top bar's dismiss when hosted inside another game.
    var onQuit: (() -> Void)?

    var maxScore: Int { wordCount * 5 }

    var title: String {
        game == .wordsky ? "WORDSKY" : "ROOTSKY"
    }

    /// Wordsky data has no roots; the medallion/intro/tree only show with them.
    var hasRoots: Bool {
        words.first?.rootWord != nil
    }

    private let soundEngine: SoundEngine
    private let rootskyStore: RootskyStore
    private let dailyState: DailyStateService
    let speech: SpeechService
    private let onComplete: (RootskyResult) -> Void

    // MARK: Day state

    private(set) var phase: Phase = .loading
    private(set) var dateKey = ""
    private(set) var words: [RootskyWord] = []
    private(set) var state: RootskyDayState?
    /// Which word is displayed in review mode.
    private(set) var reviewIndex = 0
    /// Answers as shown for the current word (reshuffled per presentation).
    private(set) var presentedAnswers: [String] = []
    /// The current word's correct answer has been found (word resolved).
    private(set) var wordRevealed = false
    private(set) var isPaused = false
    var isShowingResults = false
    var isShowingCalendar = false

    /// Root medallion intro plays on the very first start of a day.
    private(set) var isIntroActive = false

    // MARK: Transient UI feedback

    /// Bumped when a word lands (drives the landing spring + sparks).
    private(set) var wordGeneration = 0
    /// Fires the celebration confetti on a perfect 25/25 day.
    private(set) var confettiTrigger = 0
    private(set) var selectionTick = 0
    private(set) var successTick = 0
    private(set) var errorTick = 0

    // MARK: Private

    @ObservationIgnored private var allDays: [String: [RootskyWord]] = [:]
    @ObservationIgnored private var completedKeys: Set<String> = []
    @ObservationIgnored private var partialKeys: Set<String> = []
    @ObservationIgnored private var rng = SeedEngine(seed: Int.random(in: Int.min...Int.max))
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    /// Elapsed seconds when the current word started (per-word timing).
    @ObservationIgnored private var wordStartSeconds = 0

    init(
        game: GameID = .rootsky,
        language: Language,
        soundEngine: SoundEngine,
        rootskyStore: RootskyStore,
        dailyState: DailyStateService,
        speech: SpeechService,
        wordCount: Int = RootskyModel.wordsPerDay,
        isSandboxed: Bool = false,
        onComplete: @escaping (RootskyResult) -> Void
    ) {
        self.game = game
        self.language = language
        self.wordCount = min(max(1, wordCount), RootskyModel.wordsPerDay)
        self.isSandboxed = isSandboxed
        self.soundEngine = soundEngine
        self.rootskyStore = rootskyStore
        self.dailyState = dailyState
        self.speech = speech
        self.onComplete = onComplete
    }

    var availableDateKeys: Set<String> { Set(allDays.keys) }
    var playedDateKeys: Set<String> { completedKeys }
    var inProgressDateKeys: Set<String> { partialKeys }

    var friendlyDate: String {
        TriviaLogic.friendlyDate(fromKey: dateKey)
    }

    /// Compact "9/12" form for the in-game header.
    var shortDate: String {
        TriviaLogic.shortDate(fromKey: dateKey)
    }

    /// The word shown right now (active in play, browsed in review).
    var displayedIndex: Int {
        if case .review = phase { return reviewIndex }
        return state?.currentWordIndex ?? 0
    }

    var currentWord: RootskyWord? {
        words.indices.contains(displayedIndex) ? words[displayedIndex] : nil
    }

    var totalScore: Int {
        state?.totalScore ?? 0
    }

    /// Cumulative score over resolved words only (top-bar display).
    var visibleScore: Int {
        guard let state else { return 0 }
        if state.completed { return state.totalScore }
        let played = state.currentWordIndex + (wordRevealed ? 1 : 0)
        return state.wordScores.prefix(played).reduce(0, +)
    }

    var elapsedText: String {
        let t = state?.elapsedSeconds ?? 0
        return t >= 60 ? "\(t / 60):\(String(format: "%02d", t % 60))" : "\(t)s"
    }

    var isCompleted: Bool {
        state?.completed ?? false
    }

    var hasVoice: Bool {
        speech.hasVoice(for: language.id)
    }

    // MARK: - Loading & date selection

    func load() async {
        do {
            allDays = try await rootskyStore.words(for: language)
            if isSandboxed {
                selectDate(Self.randomPastDay(from: allDays.keys, rng: &rng))
                return
            }
            let progress = dailyState.progressDateKeys(game: game, languageID: language.id)
            completedKeys = progress.completed
            partialKeys = progress.inProgress

            var initialKey = TriviaLogic.dateKey(for: .now)
            let arguments = ProcessInfo.processInfo.arguments
            if let flag = arguments.firstIndex(of: "-\(game.rawValue)-date"),
               arguments.indices.contains(flag + 1) {
                initialKey = arguments[flag + 1]
            }
            selectDate(initialKey)
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    /// Any day except today, so a sandboxed round never spoils the daily puzzle.
    static func randomPastDay(from keys: some Collection<String>, rng: inout SeedEngine) -> String {
        let today = TriviaLogic.dateKey(for: .now)
        let candidates = keys.filter { $0 != today }.sorted()
        let pool = candidates.isEmpty ? keys.sorted() : candidates
        guard !pool.isEmpty else { return today }
        return pool[rng.nextInt(pool.count)]
    }

    func selectDate(_ key: String) {
        stopTimer()
        isShowingResults = false
        isShowingCalendar = false
        isIntroActive = false
        wordRevealed = false
        reviewIndex = 0
        dateKey = key

        guard let dayWords = allDays[key], dayWords.count >= wordCount else {
            words = []
            state = nil
            phase = .noGame
            return
        }
        words = Array(dayWords.prefix(wordCount))

        if !isSandboxed,
           let saved = dailyState.load(RootskyDayState.self, game: game, languageID: language.id, dateKey: key),
           saved.isShapeValid(wordCount: wordCount) {
            state = saved
            if saved.completed {
                phase = .review
                presentAnswers(for: reviewIndex)
            } else {
                phase = .start(canResume: saved.started)
            }
        } else {
            state = RootskyDayState(dateKey: key, wordCount: wordCount)
            phase = .start(canResume: false)
        }
    }

    // MARK: - Round flow

    func start() {
        guard var state, !state.completed else { return }
        let isFirstStart = !state.started
        state.started = true
        self.state = state
        phase = .playing
        wordRevealed = false
        save()
        partialKeys.insert(dateKey)

        if isFirstStart, hasRoots {
            isIntroActive = true
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(2200))
                guard let self, self.isIntroActive else { return }
                self.isIntroActive = false
                self.beginPlay()
            }
        } else {
            beginPlay()
        }
    }

    private func beginPlay() {
        wordStartSeconds = state?.elapsedSeconds ?? 0
        launchWord()
        startTimer()
    }

    private func launchWord() {
        presentAnswers(for: state?.currentWordIndex ?? 0)
        wordGeneration += 1
        soundEngine.play(.newWord)
        selectionTick += 1
    }

    /// Shuffle correct + wrong answers for a word (fresh order per presentation,
    /// like the web — wrong marks survive via answer text).
    private func presentAnswers(for index: Int) {
        guard words.indices.contains(index) else { return }
        let word = words[index]
        presentedAnswers = rng.shuffle([word.translation] + word.wordOptions)
    }

    enum AnswerState: Hashable {
        case normal, wrong, correct, disabled
    }

    func answerState(for answer: String) -> AnswerState {
        guard let state else { return .disabled }
        if case .review = phase {
            return answer == currentWord?.translation ? .correct : .disabled
        }
        let index = state.currentWordIndex
        if wordRevealed {
            return answer == currentWord?.translation ? .correct : .disabled
        }
        if state.disabledAnswers.indices.contains(index),
           state.disabledAnswers[index].contains(answer) {
            return .wrong
        }
        return .normal
    }

    func selectAnswer(_ answer: String) {
        guard case .playing = phase, !isPaused, !isIntroActive, !wordRevealed else { return }
        guard var state, let word = currentWord else { return }
        let index = state.currentWordIndex

        if answer == word.translation {
            wordRevealed = true
            soundEngine.play(.correct)
            successTick += 1
            // Record this word's time.
            let now = state.elapsedSeconds
            state.wordTimes[index] = max(0, now - wordStartSeconds)
            wordStartSeconds = now
            self.state = state
            save()

            if index >= wordCount - 1 {
                completeDay()
            } else {
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(1))
                    self?.advanceWord()
                }
            }
        } else {
            state.wordScores[index] = max(0, state.wordScores[index] - 1)
            state.disabledAnswers[index].append(answer)
            self.state = state
            soundEngine.play(.wrong)
            errorTick += 1
            save()
        }
    }

    private func advanceWord() {
        guard case .playing = phase, var state, !state.completed else { return }
        state.currentWordIndex += 1
        self.state = state
        wordRevealed = false
        save()
        launchWord()
    }

    private func completeDay() {
        guard var state, !state.completed else { return }
        state.completed = true
        self.state = state
        stopTimer()
        save()
        completedKeys.insert(dateKey)
        partialKeys.remove(dateKey)

        let isPerfect = state.totalScore == maxScore
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            guard let self else { return }
            self.soundEngine.play(.gameEnd)
            self.successTick += 1
            if isPerfect {
                self.confettiTrigger += 1
            }
            if !self.isSandboxed {
                self.isShowingResults = true
            }
        }

        onComplete(
            RootskyResult(
                game: game,
                languageID: language.id,
                dateKey: dateKey,
                score: state.totalScore,
                durationSeconds: state.elapsedSeconds,
                words: zip(words, state.wordScores).map {
                    FoundWord(word: $0.wordOfTheDay, translation: $0.translation, points: $1)
                }
            )
        )
    }

    /// Close the results card and browse words via the tracker.
    func enterReview() {
        isShowingResults = false
        guard isCompleted else { return }
        phase = .review
        reviewIndex = min(reviewIndex, wordCount - 1)
        presentAnswers(for: reviewIndex)
    }

    func showWord(_ index: Int) {
        guard case .review = phase, words.indices.contains(index) else { return }
        reviewIndex = index
        presentAnswers(for: index)
        wordGeneration += 1
        selectionTick += 1
    }

    func speakCurrentWord() {
        guard let word = currentWord else { return }
        speech.speak(word.wordOfTheDay, languageID: language.id)
    }

    var shareText: String {
        guard let state else { return "" }
        let y = dateKey.prefix(4), m = dateKey.dropFirst(4).prefix(2), d = dateKey.suffix(2)
        let header = game == .wordsky ? "📖 Wordsky" : "🌳 Rootsky"
        var lines = ["\(header) \(m)/\(d)/\(y)"]
        lines.append(state.wordScores.map { $0 == 5 ? "🟩" : $0 >= 3 ? "🟨" : "🟥" }.joined())
        let padLength = (words.map { $0.wordOfTheDay.count }.max() ?? 0) + 1
        for (i, score) in state.wordScores.enumerated() where words.indices.contains(i) {
            let word = words[i].wordOfTheDay.padding(toLength: padLength, withPad: " ", startingAt: 0)
            lines.append(word + String(repeating: "★", count: score))
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Stopwatch

    func setPaused(_ paused: Bool) {
        guard case .playing = phase else { return }
        isPaused = paused
    }

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tickUp()
            }
        }
    }

    private func tickUp() {
        guard case .playing = phase, !isPaused, !isIntroActive, !wordRevealed,
              !isShowingCalendar, !isShowingResults,
              var state, !state.completed
        else { return }
        state.elapsedSeconds += 1
        self.state = state
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func save() {
        guard let state, !isSandboxed else { return }
        dailyState.save(
            state,
            game: game,
            languageID: language.id,
            dateKey: dateKey,
            completed: state.completed
        )
    }
}
