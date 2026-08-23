import Foundation
import Observation

/// One Scramblisky session: 90-second anagram sprint. Tap scrambled tiles to
/// spell the word; auto-submits when full. Ported from web/mobile/scramblisky.html.
@Observable
final class ScramblisyModel {
    enum Phase {
        case loading
        case start
        case playing
        case finished
        case failed(String)
    }

    enum SlotFlash {
        case correct, wrong
    }

    nonisolated static let startingTime = 90
    nonisolated static let skipPenaltySeconds = 10
    /// Explosion + regrow timing, matching the web's 480ms transition.
    nonisolated static let transitionMilliseconds = 480
    /// Consecutive clean solves needed before points double.
    nonisolated static let comboThreshold = 3
    /// Seconds gained per solve on hard — outrun the clock.
    nonisolated static let hardTimeBonusSeconds = 3

    struct TimeBonus: Equatable {
        let seconds: Int
        let id: Int
    }

    let language: Language

    private let soundEngine: SoundEngine
    private let dictionaryStore: DictionaryStore
    private let onFinish: (ScramblisyResult) -> Void

    // MARK: Round state

    private(set) var phase: Phase = .loading
    var difficulty: ScramblisyDifficulty = .medium
    /// Zen practice: no timer, no penalties, no leaderboard.
    var isZen = false
    /// Consecutive solves without a wrong answer or skip.
    private(set) var solveStreak = 0
    private(set) var currentWord: WordEntry?
    private(set) var scrambledLetters: [Character] = []
    private(set) var selectedIndices: [Int] = []
    private(set) var score = 0
    private(set) var wordsCompleted = 0
    private(set) var wordsSkipped = 0
    private(set) var wrongAttempts = 0
    private(set) var completedWords: [FoundWord] = []
    private(set) var timeLeft = 0
    private(set) var hintRevealed = false
    private(set) var isPaused = false
    /// True while tiles explode out and the next word grows in — input blocked.
    private(set) var isTransitioning = false

    // MARK: Transient UI feedback

    /// Bumped when a new word's tiles should grow in.
    private(set) var wordGeneration = 0
    /// Bumped when the current tiles should blast away.
    private(set) var explosionTrigger = 0
    private(set) var slotFlash: SlotFlash?
    private(set) var penalty: BoggleskyModel.Penalty?
    private(set) var timeBonus: TimeBonus?
    private(set) var selectionTick = 0
    private(set) var successTick = 0
    private(set) var errorTick = 0

    var isDangerTime: Bool { timeLeft <= 15 }

    var timeText: String {
        let t = max(0, timeLeft)
        return "\(t / 60):\(String(format: "%02d", t % 60))"
    }

    // MARK: Private

    @ObservationIgnored private var dictionary: [WordEntry] = []
    @ObservationIgnored private var wordQueue: [WordEntry] = []
    @ObservationIgnored private var wordIndex = 0
    @ObservationIgnored private var rng = SeedEngine(seed: Int.random(in: Int.min...Int.max))
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var pendingCheck: Task<Void, Never>?
    @ObservationIgnored private var eventID = 0

    init(
        language: Language,
        soundEngine: SoundEngine,
        dictionaryStore: DictionaryStore,
        onFinish: @escaping (ScramblisyResult) -> Void
    ) {
        self.language = language
        self.soundEngine = soundEngine
        self.dictionaryStore = dictionaryStore
        self.onFinish = onFinish
    }

    // MARK: - Lifecycle

    func load() async {
        do {
            dictionary = try await dictionaryStore.dictionary(for: language).entries
            phase = .start
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func startRound() {
        guard !dictionary.isEmpty else { return }
        // Word pool for the difficulty's length band; whole dictionary when thin.
        var candidates = dictionary.filter {
            difficulty.wordLengthRange.contains($0.word.count)
        }
        if candidates.count < 10 {
            candidates = dictionary
        }
        wordQueue = rng.shuffle(candidates)
        wordIndex = 0
        score = 0
        wordsCompleted = 0
        wordsSkipped = 0
        wrongAttempts = 0
        solveStreak = 0
        completedWords = []
        timeLeft = Self.startingTime
        isTransitioning = false
        phase = .playing
        presentWord()
        if !isZen {
            startTimer()
        }
    }

    func backToStart() {
        stopTimer()
        pendingCheck?.cancel()
        phase = .start
    }

    func setPaused(_ paused: Bool) {
        guard case .playing = phase else { return }
        isPaused = paused
    }

    // MARK: - Word flow

    private func nextQueuedWord() -> WordEntry {
        if wordIndex >= wordQueue.count {
            wordQueue = rng.shuffle(wordQueue)
            wordIndex = 0
        }
        return wordQueue[wordIndex]
    }

    private func presentWord() {
        let entry = nextQueuedWord()
        currentWord = entry
        scrambledLetters = rng.shuffle(Array(entry.word.lowercased()))
        selectedIndices = []
        hintRevealed = difficulty.hintMode == .always
        slotFlash = nil
        wordGeneration += 1
    }

    /// Explode the current tiles, then grow the next word in.
    private func transitionToNextWord() {
        guard !isTransitioning else { return }
        isTransitioning = true
        explosionTrigger += 1
        soundEngine.play(.explode)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(Self.transitionMilliseconds))
            guard let self, case .playing = self.phase else { return }
            self.wordIndex += 1
            self.presentWord()
            self.isTransitioning = false
        }
    }

    // MARK: - Input

    /// Letter rack rows: max 4 tiles per row, distributed evenly (web layout).
    var rackRows: [[Int]] {
        let total = scrambledLetters.count
        guard total > 0 else { return [] }
        let numRows = (total + 3) / 4
        let base = total / numRows
        let extra = total % numRows
        var rows: [[Int]] = []
        var index = 0
        for r in 0..<numRows {
            let count = base + (r < extra ? 1 : 0)
            rows.append(Array(index..<(index + count)))
            index += count
        }
        return rows
    }

    func isLetterUsed(_ index: Int) -> Bool {
        selectedIndices.contains(index)
    }

    func selectLetter(_ index: Int) {
        guard case .playing = phase, !isPaused, !isTransitioning, let currentWord else { return }
        guard !selectedIndices.contains(index) else { return }
        guard selectedIndices.count < currentWord.word.count else { return }

        selectedIndices.append(index)
        soundEngine.play(.select(step: selectedIndices.count - 1))
        selectionTick += 1

        if selectedIndices.count == currentWord.word.count {
            pendingCheck?.cancel()
            pendingCheck = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(150))
                guard !Task.isCancelled else { return }
                self?.checkAnswer()
            }
        }
    }

    func removeSlot(at position: Int) {
        guard case .playing = phase, !isPaused, !isTransitioning else { return }
        guard selectedIndices.indices.contains(position) else { return }
        pendingCheck?.cancel()
        selectedIndices.remove(at: position)
        soundEngine.play(.deselect)
        selectionTick += 1
    }

    func clearSelection() {
        guard case .playing = phase, !isPaused, !isTransitioning, !selectedIndices.isEmpty else { return }
        pendingCheck?.cancel()
        selectedIndices = []
        soundEngine.play(.deselect)
        selectionTick += 1
    }

    func revealHint() {
        guard difficulty.hintMode == .onRequest else { return }
        hintRevealed = true
    }

    func skipWord() {
        guard case .playing = phase, !isPaused, !isTransitioning else { return }
        soundEngine.play(.penalty)
        wordsSkipped += 1
        solveStreak = 0
        applyPenalty(seconds: Self.skipPenaltySeconds, playSound: false)
        if timeLeft > 0 || isZen {
            transitionToNextWord()
        }
    }

    private func checkAnswer() {
        guard case .playing = phase, !isTransitioning, let currentWord else { return }
        let attempt = String(selectedIndices.map { scrambledLetters[$0] })

        if attempt == currentWord.word.lowercased() {
            soundEngine.play(.correct)
            successTick += 1
            slotFlash = .correct
            solveStreak += 1
            // On fire: clean-solve chains double the points.
            let multiplier = solveStreak >= Self.comboThreshold ? 2 : 1
            let points = difficulty.score(forWordLength: currentWord.word.count) * multiplier
            score += points
            wordsCompleted += 1
            completedWords.append(
                FoundWord(word: currentWord.word, translation: currentWord.translation, points: points)
            )
            if difficulty == .hard, !isZen {
                grantTimeBonus(seconds: Self.hardTimeBonusSeconds)
            }
            scheduleTransition()
        } else {
            soundEngine.play(.wrong)
            errorTick += 1
            slotFlash = .wrong
            wrongAttempts += 1
            solveStreak = 0
            applyPenalty(seconds: difficulty.wrongPenaltySeconds, playSound: false)
            if timeLeft > 0 || isZen {
                scheduleTransition()
            }
        }
    }

    /// Whether the fire badge shows (combo active).
    var isOnFire: Bool {
        solveStreak >= Self.comboThreshold
    }

    private func grantTimeBonus(seconds: Int) {
        timeLeft += seconds
        eventID += 1
        timeBonus = TimeBonus(seconds: seconds, id: eventID)
        let bonusID = eventID
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            if self?.timeBonus?.id == bonusID {
                self?.timeBonus = nil
            }
        }
    }

    private func scheduleTransition() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard let self, case .playing = self.phase else { return }
            self.transitionToNextWord()
        }
    }

    private func applyPenalty(seconds: Int, playSound: Bool) {
        // Zen is judgment-free: no clock, no penalties.
        guard !isZen else { return }
        timeLeft = max(0, timeLeft - seconds)
        if playSound {
            soundEngine.play(.penalty)
        }
        errorTick += 1
        eventID += 1
        penalty = BoggleskyModel.Penalty(seconds: seconds, id: eventID)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.penalty = nil
        }
        if timeLeft <= 0 {
            endRound()
        }
    }

    // MARK: - Timer

    private func startTimer() {
        stopTimer()
        timerTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func stopTimer() {
        timerTask?.cancel()
        timerTask = nil
    }

    private func tick() {
        guard case .playing = phase, !isPaused else { return }
        timeLeft -= 1
        if timeLeft > 0, timeLeft <= 5 {
            soundEngine.play(.tick)
        }
        if timeLeft <= 0 {
            endRound()
        }
    }

    private func endRound() {
        guard case .playing = phase else { return }
        stopTimer()
        pendingCheck?.cancel()
        timeLeft = 0
        phase = .finished
        soundEngine.play(.gameEnd)
        successTick += 1
        onFinish(
            ScramblisyResult(
                languageID: language.id,
                difficulty: difficulty,
                score: score,
                wordsCompleted: wordsCompleted,
                wordsSkipped: wordsSkipped,
                wrongAttempts: wrongAttempts,
                words: completedWords
            )
        )
    }
}
