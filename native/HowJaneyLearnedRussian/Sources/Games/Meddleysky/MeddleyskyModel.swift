import Foundation
import Observation

/// One Meddleysky run: a shuffle-bag of every other game, each played as a
/// shortened level at a difficulty read from the player's history. Levels
/// score normalized points times a growing combo; a level worth zero ends the run.
@Observable
final class MeddleyskyModel {
    enum Phase {
        case start
        /// Between levels: celebrate the last one (if any) and spin up the next.
        case transition(previous: MeddleyLevelRecord?, next: MeddleyLevelPlan)
        case playing(MeddleyLevelPlan)
        case finished
    }

    /// What the run needs to know about the player's past with one game.
    nonisolated struct GameHistory: Sendable {
        var gamesPlayed = 0
        var totalScore = 0
        var bestScore = 0

        var averageScore: Double? {
            gamesPlayed > 0 ? Double(totalScore) / Double(gamesPlayed) : nil
        }
    }

    let language: Language
    private let history: (GameID) -> GameHistory?
    private let soundEngine: SoundEngine
    private let onFinish: (MeddleyskyResult) -> Void

    private(set) var phase: Phase = .start
    private(set) var levels: [MeddleyLevelRecord] = []
    private(set) var runScore = 0
    /// Best run score before this session (from local stats).
    private(set) var previousBest = 0
    /// True once this run beat `previousBest`.
    private(set) var isNewBest = false
    /// The level that ended the run (scored zero), if the player didn't quit.
    private(set) var fatalLevel: MeddleyLevelPlan?

    private(set) var confettiTrigger = 0
    private(set) var selectionTick = 0
    private(set) var successTick = 0
    private(set) var errorTick = 0

    /// Games this language offers, minus Meddleysky itself.
    @ObservationIgnored private(set) var availableGames: [GameID]
    @ObservationIgnored private var gameNames: [GameID: String]
    @ObservationIgnored private var bag: [GameID] = []
    @ObservationIgnored private var lastGame: GameID?
    @ObservationIgnored private var rng = SeedEngine(seed: Int.random(in: Int.min...Int.max))
    @ObservationIgnored private var advanceTask: Task<Void, Never>?

    /// `history` answers "how has this player done at that game?" — the app
    /// passes local stats; tests pass canned numbers.
    init(
        language: Language,
        soundEngine: SoundEngine,
        history: @escaping (GameID) -> GameHistory?,
        onFinish: @escaping (MeddleyskyResult) -> Void
    ) {
        self.language = language
        self.history = history
        self.soundEngine = soundEngine
        self.onFinish = onFinish
        availableGames = language.games.compactMap(GameID.init).filter { $0 != .meddleysky }
        gameNames = Dictionary(uniqueKeysWithValues: availableGames.map { game in
            (game, language.gameNames[game.rawValue]?.name ?? game.rawValue.capitalized)
        })
        previousBest = history(.meddleysky)?.bestScore ?? 0
    }

    convenience init(
        language: Language,
        stats: StatsService,
        soundEngine: SoundEngine,
        onFinish: @escaping (MeddleyskyResult) -> Void
    ) {
        let languageID = language.id
        self.init(language: language, soundEngine: soundEngine, history: { game in
            stats.stats(game: game, languageID: languageID).map {
                GameHistory(gamesPlayed: $0.gamesPlayed, totalScore: $0.totalScore, bestScore: $0.bestScore)
            }
        }, onFinish: onFinish)
    }

    var levelsCleared: Int { levels.count }

    var bestMultiplier: Double {
        levels.map(\.multiplier).max() ?? 1
    }

    var currentLevel: MeddleyLevelPlan? {
        if case .playing(let plan) = phase { return plan }
        return nil
    }

    func name(of game: GameID) -> String {
        gameNames[game] ?? game.rawValue.capitalized
    }

    // MARK: - Run flow

    func startRun() {
        guard !availableGames.isEmpty else { return }
        advanceTask?.cancel()
        levels = []
        runScore = 0
        isNewBest = false
        fatalLevel = nil
        bag = []
        lastGame = nil
        selectionTick += 1
        phase = .transition(previous: nil, next: nextPlan())
    }

    func beginLevel(_ plan: MeddleyLevelPlan) {
        guard case .transition(_, let next) = phase, next.index == plan.index else { return }
        advanceTask?.cancel()
        phase = .playing(plan)
    }

    /// Called by the hosted game when its round ends.
    func levelFinished(rawScore: Int, words: [FoundWord]) {
        guard case .playing(let plan) = phase else { return }
        let base = MeddleyTuning.basePoints(rawScore: rawScore, par: plan.par)
        let points = Int((Double(base) * plan.multiplier).rounded())
        let record = MeddleyLevelRecord(
            plan: plan, rawScore: rawScore, basePoints: base, points: points, words: words
        )

        // Let the hosted game's final frame land before switching screens.
        advanceTask?.cancel()
        advanceTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(900))
            guard let self, !Task.isCancelled, case .playing = self.phase else { return }
            if rawScore <= 0 {
                self.fatalLevel = plan
                self.errorTick += 1
                self.endRun()
            } else {
                self.levels.append(record)
                self.runScore += points
                self.successTick += 1
                if base >= 1000 {
                    self.confettiTrigger += 1
                }
                self.phase = .transition(previous: record, next: self.nextPlan())
            }
        }
    }

    /// The hosted game couldn't load its content: drop it and move on.
    func skipLevel() {
        guard case .playing(let plan) = phase else { return }
        availableGames.removeAll { $0 == plan.game }
        bag.removeAll { $0 == plan.game }
        if availableGames.isEmpty {
            endRun()
        } else {
            phase = .transition(previous: nil, next: nextPlan())
        }
    }

    /// Player pressed Quit inside a level: the run ends with what it has.
    func quitRun() {
        advanceTask?.cancel()
        if levels.isEmpty {
            phase = .start
        } else {
            endRun()
        }
    }

    func backToStart() {
        advanceTask?.cancel()
        phase = .start
    }

    private func endRun() {
        advanceTask?.cancel()
        phase = .finished
        soundEngine.play(.gameEnd)
        if runScore > previousBest {
            isNewBest = true
            confettiTrigger += 1
        }
        onFinish(
            MeddleyskyResult(
                languageID: language.id,
                score: runScore,
                levelsCleared: levels.count,
                bestMultiplier: bestMultiplier,
                words: levels.flatMap(\.words)
            )
        )
        if isNewBest {
            previousBest = runScore
        }
    }

    // MARK: - Planning

    /// Shuffle-bag draw: every game once before any repeats, never twice in a row.
    private func nextPlan() -> MeddleyLevelPlan {
        if bag.isEmpty {
            bag = rng.shuffle(availableGames)
            if bag.count > 1, bag.last == lastGame {
                bag.swapAt(bag.count - 1, 0)
            }
        }
        let game = bag.removeLast()
        lastGame = game

        let skill = skill(for: game)
        let difficulty = MeddleyTuning.hasDifficulty(game) ? skill.difficulty : nil
        let par = Int((Double(MeddleyTuning.levelPar(for: game)) * (difficulty?.parMultiplier ?? 1)).rounded())
        return MeddleyLevelPlan(
            index: levels.count + 1,
            game: game,
            gameName: name(of: game),
            difficulty: difficulty,
            skill: skill,
            par: max(1, par)
        )
    }

    /// Reads the player's average score for the game from their history.
    func skill(for game: GameID) -> MeddleySkill {
        MeddleySkill.estimate(
            averageScore: history(game)?.averageScore,
            fullPar: MeddleyTuning.fullPar(for: game)
        )
    }

    var shareText: String {
        var lines = ["🎲 Meddleysky — \(runScore) pts, \(levels.count) level\(levels.count == 1 ? "" : "s")"]
        for level in levels {
            lines.append("\(level.plan.index). \(level.plan.gameName) +\(level.points)")
        }
        return lines.joined(separator: "\n")
    }
}
