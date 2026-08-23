import Foundation
import Observation

/// One Snakesky session: game loop, input, and round lifecycle over the pure engine.
@Observable
final class SnakeskyModel {
    enum Phase {
        case loading
        case start
        case playing
        case finished
        case failed(String)
    }

    let language: Language

    private let soundEngine: SoundEngine
    private let dictionaryStore: DictionaryStore
    private let onFinish: (SnakeskyResult) -> Void

    private(set) var phase: Phase = .loading
    var difficulty: SnakeskyDifficulty = .medium
    private(set) var state: SnakeskyEngine.State?
    private(set) var startedAt: Date = .now
    private(set) var deathCause: SnakeskyEngine.Collision?
    private(set) var isPaused = false

    private(set) var selectionTick = 0
    private(set) var successTick = 0
    private(set) var errorTick = 0

    @ObservationIgnored private var dictionary: [WordEntry] = []
    @ObservationIgnored private var loopTask: Task<Void, Never>?

    init(
        language: Language,
        soundEngine: SoundEngine,
        dictionaryStore: DictionaryStore,
        onFinish: @escaping (SnakeskyResult) -> Void
    ) {
        self.language = language
        self.soundEngine = soundEngine
        self.dictionaryStore = dictionaryStore
        self.onFinish = onFinish
    }

    func load() async {
        do {
            dictionary = try await dictionaryStore.dictionary(for: language, game: "snakesky").entries
            // Show a preview board behind the start screen, like the web.
            state = SnakeskyEngine.makeState(dictionary: dictionary, seed: 42)
            phase = .start
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func startRound() {
        guard !dictionary.isEmpty else { return }
        state = SnakeskyEngine.makeState(dictionary: dictionary, seed: Int.random(in: Int.min...Int.max))
        deathCause = nil
        startedAt = .now
        phase = .playing
        startLoop()
    }

    func backToStart() {
        stopLoop()
        phase = .start
    }

    func setPaused(_ paused: Bool) {
        guard case .playing = phase else { return }
        isPaused = paused
    }

    func turn(_ turn: SnakeskyEngine.Turn) {
        guard case .playing = phase, !isPaused, var state, state.pendingTurn == nil else { return }
        state.pendingTurn = turn
        self.state = state
        selectionTick += 1
    }

    private func startLoop() {
        stopLoop()
        let interval = difficulty.tickMilliseconds
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(interval))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func tick() {
        guard case .playing = phase, !isPaused, var state else { return }
        let outcome = SnakeskyEngine.step(&state)
        self.state = state

        switch outcome {
        case .moved:
            break
        case .ateLetter:
            soundEngine.play(.select(step: state.letterProgress))
            selectionTick += 1
        case .completedWord:
            soundEngine.play(.correct)
            successTick += 1
        case .died(let cause):
            deathCause = cause
            died()
        }
    }

    private func died() {
        stopLoop()
        phase = .finished
        soundEngine.play(.wrong)
        errorTick += 1
        soundEngine.play(.gameEnd)
        guard let state else { return }
        onFinish(
            SnakeskyResult(
                languageID: language.id,
                difficulty: difficulty,
                score: state.score,
                wordsCompleted: state.wordsCompleted,
                durationSeconds: Int(Date.now.timeIntervalSince(startedAt)),
                words: state.completedWords.map {
                    FoundWord(word: $0.word, translation: $0.translation, points: $0.word.count * 10)
                }
            )
        )
    }

    // MARK: - Display helpers

    /// Letter states for the word header: eaten / next / pending (or "?" on hard).
    enum LetterDisplay: Hashable {
        case eaten(Character)
        case next(Character)
        case pending(Character)
        case hidden
    }

    var wordDisplay: [LetterDisplay] {
        guard let state, let word = state.currentWord else { return [] }
        return word.word.lowercased().enumerated().map { index, letter in
            if index < state.letterProgress {
                .eaten(letter)
            } else if !difficulty.showsNextLetterHint {
                .hidden
            } else if index == state.letterProgress {
                .next(letter)
            } else {
                .pending(letter)
            }
        }
    }

    var translationText: String {
        state?.currentWord?.translation ?? ""
    }
}
