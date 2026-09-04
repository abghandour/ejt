import Foundation
import Observation

/// One Tetrisky session: gravity loop, movement, and round lifecycle over the engine.
@Observable
final class TetriskyModel {
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
    private let onFinish: (TetriskyResult) -> Void

    private(set) var phase: Phase = .loading
    var difficulty: TetriskyDifficulty = .medium
    private(set) var state: TetriskyEngine.State?
    private(set) var startedAt: Date = .now
    private(set) var isPaused = false
    /// Presentation-only state for a short, continuous fall between board rows.
    private(set) var previousFalling: TetriskyEngine.Falling?
    private(set) var fallingMotion = 0
    private(set) var landingTick = 0

    private(set) var selectionTick = 0
    private(set) var successTick = 0
    private(set) var errorTick = 0

    @ObservationIgnored private var dictionary: [WordEntry] = []
    @ObservationIgnored private var wordSet: Set<String> = []
    @ObservationIgnored private var alphabet: [Character] = []
    @ObservationIgnored private var loopTask: Task<Void, Never>?

    init(
        language: Language,
        soundEngine: SoundEngine,
        dictionaryStore: DictionaryStore,
        onFinish: @escaping (TetriskyResult) -> Void
    ) {
        self.language = language
        self.soundEngine = soundEngine
        self.dictionaryStore = dictionaryStore
        self.onFinish = onFinish
    }

    func load() async {
        do {
            let loaded = try await dictionaryStore.dictionary(for: language, game: "snakesky")
            dictionary = loaded.entries
            wordSet = Set(loaded.wordMap.keys)
            // De-duplicated language alphabet from the letter pool.
            alphabet = Array(Set(language.letterPool)).sorted()
            phase = .start
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func startRound() {
        guard !dictionary.isEmpty else { return }
        var newState = TetriskyEngine.makeState(
            dictionary: dictionary,
            seed: Int.random(in: Int.min...Int.max),
            tickMilliseconds: difficulty.tickMilliseconds
        )
        TetriskyEngine.spawn(&newState, dictionary: dictionary, alphabet: alphabet)
        state = newState
        previousFalling = nil
        fallingMotion = 0
        landingTick = 0
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

    // MARK: - Input

    func moveLeft() {
        move(by: -1)
    }

    func moveRight() {
        move(by: 1)
    }

    private func move(by delta: Int) {
        guard case .playing = phase, !isPaused, var state, var falling = state.falling else { return }
        let previousFalling = falling
        let newCol = falling.col + delta
        guard (0..<TetriskyEngine.columns).contains(newCol),
              state.board[falling.row][newCol] == nil
        else { return }
        falling.col = newCol
        state.falling = falling
        self.previousFalling = previousFalling
        self.state = state
        fallingMotion += 1
        soundEngine.play(.select(step: 0))
        selectionTick += 1
    }

    func hardDrop() {
        guard case .playing = phase, !isPaused, var state, state.falling != nil else { return }
        if let ghost = TetriskyEngine.ghostRow(state), var falling = state.falling {
            falling.row = ghost
            state.falling = falling
        }
        soundEngine.play(.explode)
        selectionTick += 1
        resolveLanding(&state)
        previousFalling = nil
        self.state = state
        afterStep()
    }

    // MARK: - Loop

    private func startLoop() {
        stopLoop()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                let interval = self?.state?.tickMilliseconds ?? 800
                try? await Task.sleep(for: .milliseconds(interval))
                guard let self, !Task.isCancelled else { return }
                self.tick()
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func tick() {
        guard case .playing = phase, !isPaused, var state else { return }

        if state.falling == nil {
            TetriskyEngine.spawn(&state, dictionary: dictionary, alphabet: alphabet)
            previousFalling = nil
            self.state = state
            if !state.isAlive {
                gameOver()
            }
            return
        }

        if var falling = state.falling {
            let previousFalling = falling
            let nextRow = falling.row + 1
            if nextRow >= TetriskyEngine.rows || state.board[nextRow][falling.col] != nil {
                resolveLanding(&state)
                self.previousFalling = nil
            } else {
                falling.row = nextRow
                state.falling = falling
                self.previousFalling = previousFalling
                fallingMotion += 1
            }
        }
        self.state = state
        afterStep()
    }

    private func resolveLanding(_ state: inout TetriskyEngine.State) {
        let cleared = TetriskyEngine.land(&state, wordSet: wordSet, dictionary: dictionary)
        landingTick += 1
        if cleared.isEmpty {
            soundEngine.play(.deselect)
        } else {
            soundEngine.play(.correct)
            successTick += 1
        }
    }

    private func afterStep() {
        if let state, !state.isAlive {
            gameOver()
        }
    }

    private func gameOver() {
        stopLoop()
        phase = .finished
        soundEngine.play(.wrong)
        errorTick += 1
        soundEngine.play(.gameEnd)
        guard let state else { return }
        onFinish(
            TetriskyResult(
                languageID: language.id,
                difficulty: difficulty,
                score: state.score,
                wordsCompleted: state.wordsCompleted,
                durationSeconds: Int(Date.now.timeIntervalSince(startedAt)),
                words: state.completedWords.map { word in
                    FoundWord(
                        word: word,
                        translation: dictionary.first { $0.word.lowercased() == word }?.translation ?? "",
                        points: word.count * 10
                    )
                }
            )
        )
    }
}
