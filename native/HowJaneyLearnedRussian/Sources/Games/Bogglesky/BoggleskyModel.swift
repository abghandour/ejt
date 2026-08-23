import Foundation
import Observation

/// One Bogglesky session: round lifecycle, timer, drag/selection state, and
/// transient UI feedback. Pure rules live in `BoggleskyEngine`.
@Observable
final class BoggleskyModel {
    enum Phase {
        case loading
        case start
        case playing
        case finished
        case failed(String)
    }

    enum FlashKind {
        case correct, wrong
    }

    struct Flash: Equatable {
        let kind: FlashKind
        let cells: Set<Int>
        let id: Int
    }

    struct Burst: Equatable {
        let cells: [Int]
        let id: Int
    }

    struct Penalty: Equatable {
        let seconds: Int
        let id: Int
    }

    /// Fired on a found word worth celebrating: chained combo and/or a
    /// long-word banner in the target language.
    struct Celebration: Equatable {
        let banner: String?
        let multiplier: Int
        let id: Int
    }

    /// Seconds between finds that keep a combo chain alive.
    nonisolated static let comboWindowSeconds = 5

    let language: Language

    private let soundEngine: SoundEngine
    private let dictionaryStore: DictionaryStore
    let speech: SpeechService
    private let onFinish: (BoggleskyResult) -> Void

    // MARK: Round state

    private(set) var phase: Phase = .loading
    var difficulty: BoggleskyDifficulty = .medium
    private(set) var board: BoggleskyEngine.Board?
    private(set) var selectedPath: [Int] = []
    private(set) var score = 0
    private(set) var wordsFound: [FoundWord] = []
    private(set) var foundSet: Set<String> = []
    private(set) var timeLeft = 0
    private(set) var revealedHints: Set<String> = []
    private(set) var isPaused = false
    /// Bumped whenever a fresh board appears, driving the tile grow-in animation.
    private(set) var boardGeneration = 0

    // MARK: Transient UI feedback

    private(set) var flash: Flash?
    private(set) var burst: Burst?
    private(set) var penalty: Penalty?
    private(set) var toast: String?
    private(set) var celebration: Celebration?
    private(set) var confettiTrigger = 0
    /// Haptic triggers observed by `sensoryFeedback`.
    private(set) var selectionTick = 0
    private(set) var successTick = 0
    private(set) var errorTick = 0

    // MARK: Private

    @ObservationIgnored private var wordMap: [String: String] = [:]
    @ObservationIgnored private var trie: BoggleskyEngine.Trie?
    @ObservationIgnored private var rng = SeedEngine(seed: Int.random(in: Int.min...Int.max))
    @ObservationIgnored private var letterPool: [Character] = []
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var dwellTask: Task<Void, Never>?
    @ObservationIgnored private var dwellIndex = -1
    @ObservationIgnored private var isDragging = false
    @ObservationIgnored private var eventID = 0
    @ObservationIgnored private var comboCount = 0
    @ObservationIgnored private var lastFoundTimeLeft: Int?
    @ObservationIgnored private var clearedBoards = 0
    private(set) var previewIndex: Int?

    var isDangerTime: Bool { timeLeft <= 15 }

    var currentWord: String {
        guard let board else { return "" }
        return BoggleskyEngine.word(fromPath: selectedPath, letters: board.letters)
    }

    var timeText: String {
        let t = max(0, timeLeft)
        return "\(t / 60):\(String(format: "%02d", t % 60))"
    }

    init(
        language: Language,
        soundEngine: SoundEngine,
        dictionaryStore: DictionaryStore,
        speech: SpeechService,
        onFinish: @escaping (BoggleskyResult) -> Void
    ) {
        self.language = language
        self.soundEngine = soundEngine
        self.dictionaryStore = dictionaryStore
        self.speech = speech
        self.onFinish = onFinish
    }

    func speak(word: String) {
        speech.speak(word, languageID: language.id)
    }

    // MARK: - Lifecycle

    func load() async {
        do {
            let dictionary = try await dictionaryStore.dictionary(for: language)
            wordMap = dictionary.wordMap
            letterPool = Array(language.letterPool)
            phase = .start
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func startRound() async {
        guard !wordMap.isEmpty else { return }
        score = 0
        wordsFound = []
        foundSet = []
        selectedPath = []
        revealedHints = []
        comboCount = 0
        lastFoundTimeLeft = nil
        clearedBoards = 0
        timeLeft = difficulty.gameTime

        let size = difficulty.gridSize
        let words = Array(wordMap.keys)
        let minLength = difficulty.minWordLength
        let pool = letterPool
        let (board, builtTrie, nextRNG) = await Self.generate(
            words: words, minLength: minLength, size: size, pool: pool, rng: rng
        )
        rng = nextRNG
        trie = builtTrie
        self.board = board
        boardGeneration += 1
        phase = .playing
        startTimer()
    }

    @concurrent
    private nonisolated static func generate(
        words: [String],
        minLength: Int,
        size: Int,
        pool: [Character],
        rng: SeedEngine
    ) async -> (BoggleskyEngine.Board, BoggleskyEngine.Trie, SeedEngine) {
        var rng = rng
        let trie = BoggleskyEngine.Trie.build(words: words, minLength: minLength, maxLength: size * size)
        let board = BoggleskyEngine.generateBoard(size: size, pool: pool, trie: trie, rng: &rng)
        return (board, trie, rng)
    }

    func backToStart() {
        stopTimer()
        phase = .start
    }

    func setPaused(_ paused: Bool) {
        guard case .playing = phase else { return }
        isPaused = paused
        if paused {
            stopTimer()
        } else {
            startTimer()
        }
    }

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
        stopTimer()
        cancelDwell()
        isDragging = false
        selectedPath = []
        timeLeft = 0
        phase = .finished
        soundEngine.play(.gameEnd)
        successTick += 1
        onFinish(
            BoggleskyResult(
                languageID: language.id,
                difficulty: difficulty,
                score: score,
                wordsFound: wordsFound.count,
                findableWords: board?.findableWords.count ?? 0,
                words: wordsFound,
                clearedBoards: clearedBoards
            )
        )
    }

    // MARK: - Dragging

    func dragBegan(at index: Int) {
        guard case .playing = phase, !isPaused else { return }
        isDragging = true
        selectedPath = [index]
        cancelDwell()
        soundEngine.play(.select(step: 0))
        selectionTick += 1
    }

    func dragMoved(to point: CGPoint, geometry: BoggleGridGeometry) {
        guard isDragging else { return }

        if let index = geometry.cell(at: point) {
            previewIndex = nil
            guard index != dwellIndex else { return }
            cancelDwell()
            guard index != selectedPath.last else { return }
            // Sliding back to the previous tile undoes instantly.
            if selectedPath.count >= 2, selectedPath[selectedPath.count - 2] == index {
                commit(index)
                return
            }
            dwellIndex = index
            dwellTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(60))
                guard !Task.isCancelled else { return }
                self?.commit(index)
            }
            return
        }

        cancelDwell()
        guard let last = selectedPath.last else { return }
        previewIndex = geometry.bestNeighbor(of: last, toward: point, excluding: Set(selectedPath))
    }

    func dragEnded() {
        guard isDragging else { return }
        isDragging = false
        previewIndex = nil
        cancelDwell()
        submitWord()
    }

    private func commit(_ index: Int) {
        previewIndex = nil
        cancelDwell()
        guard isDragging, let board else { return }

        // Backtrack?
        if selectedPath.count >= 2, selectedPath[selectedPath.count - 2] == index {
            selectedPath.removeLast()
            soundEngine.play(.deselect)
            selectionTick += 1
            return
        }
        guard !selectedPath.contains(index) else { return }
        guard let last = selectedPath.last,
              BoggleskyEngine.neighbors(of: last, size: board.gridSize).contains(index)
        else { return }

        selectedPath.append(index)
        soundEngine.play(.select(step: selectedPath.count - 1))
        selectionTick += 1
    }

    private func cancelDwell() {
        dwellTask?.cancel()
        dwellTask = nil
        dwellIndex = -1
    }

    // MARK: - Word submission

    private func submitWord() {
        guard let board else { return }
        let path = selectedPath

        guard path.count >= difficulty.minWordLength else {
            selectedPath = []
            return
        }

        let word = BoggleskyEngine.word(fromPath: path, letters: board.letters)

        if foundSet.contains(word) {
            showToast("Already found")
            reject(path)
            return
        }

        guard wordMap[word] != nil, BoggleskyEngine.isValidPath(path, size: board.gridSize) else {
            reject(path)
            return
        }

        // Combo chain: finds within the window multiply points (×2, ×3 cap).
        if let last = lastFoundTimeLeft, last - timeLeft <= Self.comboWindowSeconds {
            comboCount += 1
        } else {
            comboCount = 1
        }
        lastFoundTimeLeft = timeLeft
        let multiplier = min(comboCount, 3)

        let points = difficulty.score(forWordLength: word.count) * multiplier
        score += points
        wordsFound.append(FoundWord(word: word, translation: wordMap[word] ?? "", points: points))
        foundSet.insert(word)
        soundEngine.play(.correct)
        successTick += 1

        let banner = Self.banner(forWordLength: word.count, languageID: language.id)
        if banner != nil || multiplier > 1 {
            eventID += 1
            celebration = Celebration(banner: banner, multiplier: multiplier, id: eventID)
            let celebrationID = eventID
            Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(1400))
                if self?.celebration?.id == celebrationID {
                    self?.celebration = nil
                }
            }
        }
        eventID += 1
        flash = Flash(kind: .correct, cells: Set(path), id: eventID)
        burst = Burst(cells: path, id: eventID)
        let burstID = eventID
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            if self?.burst?.id == burstID {
                self?.burst = nil
            }
        }
        scheduleClearSelection()

        if board.findableWords.subtracting(foundSet).isEmpty {
            boardCleared()
        }
    }

    private func reject(_ path: [Int]) {
        soundEngine.play(.wrong)
        errorTick += 1
        eventID += 1
        flash = Flash(kind: .wrong, cells: Set(path), id: eventID)
        scheduleClearSelection()
    }

    private func scheduleClearSelection() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            self?.selectedPath = []
            try? await Task.sleep(for: .milliseconds(150))
            self?.flash = nil
        }
    }

    /// Long-word exclamations in the target language (English fallback).
    nonisolated static func banner(forWordLength length: Int, languageID: String) -> String? {
        let tiers: [String: (String, String, String)] = [
            "ru": ("Хорошо!", "Отлично!", "Легендарно!"),
            "uk": ("Добре!", "Відмінно!", "Легендарно!"),
            "pt-br": ("Bom!", "Ótimo!", "Lendário!"),
        ]
        let (good, great, legendary) = tiers[languageID] ?? ("Nice!", "Amazing!", "Legendary!")
        switch length {
        case ..<5: return nil
        case 5: return good
        case 6: return great
        default: return legendary
        }
    }

    private func boardCleared() {
        stopTimer()
        clearedBoards += 1
        confettiTrigger += 1
        showToast("Board cleared!")
        soundEngine.play(.boardClear)
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(600))
            await self?.refreshBoard(resetFound: true)
            self?.startTimer()
        }
    }

    private func refreshBoard(resetFound: Bool) async {
        guard let board, let trie else { return }
        let size = board.gridSize
        let pool = letterPool
        let newBoard = await Self.regenerate(size: size, pool: pool, trie: trie, rng: rng)
        self.board = newBoard.board
        rng = newBoard.rng
        if resetFound { foundSet = [] }
        selectedPath = []
        revealedHints = []
        boardGeneration += 1
    }

    @concurrent
    private nonisolated static func regenerate(
        size: Int,
        pool: [Character],
        trie: BoggleskyEngine.Trie,
        rng: SeedEngine
    ) async -> (board: BoggleskyEngine.Board, rng: SeedEngine) {
        var rng = rng
        let board = BoggleskyEngine.generateBoard(size: size, pool: pool, trie: trie, rng: &rng)
        return (board, rng)
    }

    // MARK: - Shuffle & hints

    func shuffle() async {
        guard case .playing = phase, !isPaused, let board, let trie else { return }
        selectedPath = []
        let letters = board.letters
        let size = board.gridSize
        let pool = letterPool
        let result = await Self.reshuffle(letters: letters, size: size, pool: pool, trie: trie, rng: rng)
        self.board = result.board
        rng = result.rng
        boardGeneration += 1
        applyPenalty(seconds: BoggleskyEngine.shufflePenaltySeconds)
    }

    @concurrent
    private nonisolated static func reshuffle(
        letters: [Character],
        size: Int,
        pool: [Character],
        trie: BoggleskyEngine.Trie,
        rng: SeedEngine
    ) async -> (board: BoggleskyEngine.Board, rng: SeedEngine) {
        var rng = rng
        let board = BoggleskyEngine.shuffledBoard(letters: letters, size: size, pool: pool, trie: trie, rng: &rng)
        return (board, rng)
    }

    func revealHint(for word: String) {
        guard case .playing = phase, !isPaused else { return }
        guard difficulty == .easy, !revealedHints.contains(word), !foundSet.contains(word) else { return }
        revealedHints.insert(word)
        applyPenalty(seconds: BoggleskyEngine.hintPenaltySeconds)
    }

    private func applyPenalty(seconds: Int) {
        timeLeft = max(0, timeLeft - seconds)
        soundEngine.play(.penalty)
        errorTick += 1
        eventID += 1
        penalty = Penalty(seconds: seconds, id: eventID)
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.penalty = nil
        }
        if timeLeft <= 0 {
            endRound()
        }
    }

    private func showToast(_ message: String) {
        toast = message
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(1))
            self?.toast = nil
        }
    }

    /// Hint-bar rows: every findable word sorted short→long with its display state.
    var hintItems: [HintItem] {
        guard let board else { return [] }
        return board.findableWords
            .sorted { ($0.count, $0) < ($1.count, $1) }
            .map { word in
                HintItem(
                    word: word,
                    translation: wordMap[word] ?? "",
                    state: hintState(for: word)
                )
            }
    }

    private func hintState(for word: String) -> HintItem.State {
        if foundSet.contains(word) { return .found }
        if difficulty == .easy {
            return revealedHints.contains(word) ? .revealed : .translationOnly
        }
        return .mystery
    }
}

nonisolated struct HintItem: Identifiable, Hashable, Sendable {
    enum State: Hashable {
        case translationOnly
        case revealed
        case found
        case mystery
    }

    let word: String
    let translation: String
    let state: State

    var id: String { word }
}
