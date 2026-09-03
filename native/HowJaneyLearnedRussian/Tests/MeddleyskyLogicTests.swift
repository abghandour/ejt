import Testing
@testable import HowJaneyLearnedRussian

struct MeddleyskyLogicTests {
    @Test
    func skillBandsFromAverageScore() {
        #expect(MeddleySkill.estimate(averageScore: nil, fullPar: 100) == .rookie)
        #expect(MeddleySkill.estimate(averageScore: 20, fullPar: 100) == .rookie)
        #expect(MeddleySkill.estimate(averageScore: 40, fullPar: 100) == .solid)
        #expect(MeddleySkill.estimate(averageScore: 100, fullPar: 100) == .master)
    }

    @Test
    func skillMapsToDifficulty() {
        #expect(MeddleySkill.rookie.difficulty == .easy)
        #expect(MeddleySkill.solid.difficulty == .medium)
        #expect(MeddleySkill.master.difficulty == .hard)
    }

    @Test
    func basePointsNormalizeAgainstPar() {
        #expect(MeddleyTuning.basePoints(rawScore: 0, par: 100) == 0)
        #expect(MeddleyTuning.basePoints(rawScore: 50, par: 100) == 500)
        #expect(MeddleyTuning.basePoints(rawScore: 100, par: 100) == 1000)
        // Capped at 1.5× par so one strong game can't dominate a run.
        #expect(MeddleyTuning.basePoints(rawScore: 900, par: 100) == 1500)
    }

    @Test
    func comboGrowsPerLevelAndCaps() {
        func plan(_ index: Int) -> MeddleyLevelPlan {
            MeddleyLevelPlan(index: index, game: .bogglesky, gameName: "Bogglesky", difficulty: .easy, skill: .rookie, par: 10)
        }
        #expect(plan(1).multiplier == 1.0)
        #expect(abs(plan(3).multiplier - 1.3) < 0.0001)
        #expect(plan(40).multiplier == 3.0)
    }

    @Test
    func difficultyRawValuesMatchEveryGame() {
        for tier in MeddleyDifficulty.allCases {
            #expect(BoggleskyDifficulty(rawValue: tier.rawValue) != nil)
            #expect(ScramblisyDifficulty(rawValue: tier.rawValue) != nil)
            #expect(SnakeskyDifficulty(rawValue: tier.rawValue) != nil)
            #expect(TetriskyDifficulty(rawValue: tier.rawValue) != nil)
        }
    }
}

@MainActor
struct MeddleyskyRunTests {
    /// Canned history: a master at Bogglesky, a rookie everywhere else.
    private func makeRun(onFinish: @escaping (MeddleyskyResult) -> Void = { _ in }) -> MeddleyskyModel {
        MeddleyskyModel(
            language: Language(
                id: "ru", displayName: "Russian",
                games: ["meddleysky", "bogglesky", "snakesky", "triviatsky"], themes: [],
                letterPool: "аб", validationRegex: ".*", gameNames: [:]
            ),
            soundEngine: SoundEngine(),
            history: { game in
                switch game {
                case .bogglesky: MeddleyskyModel.GameHistory(gamesPlayed: 4, totalScore: 200, bestScore: 70)
                case .meddleysky: MeddleyskyModel.GameHistory(gamesPlayed: 1, totalScore: 2500, bestScore: 2500)
                default: nil
                }
            },
            onFinish: onFinish
        )
    }

    @Test
    func runExcludesItselfAndPicksDifficultyFromHistory() {
        let run = makeRun()
        #expect(!run.availableGames.contains(.meddleysky))
        #expect(run.availableGames.count == 3)
        #expect(run.previousBest == 2500)
        #expect(run.skill(for: .bogglesky) == .master)
        #expect(run.skill(for: .snakesky) == .rookie)
        run.startRun()
        guard case .transition(let previous, let next) = run.phase else {
            Issue.record("expected a transition"); return
        }
        #expect(previous == nil)
        #expect(next.index == 1)
        switch next.game {
        case .bogglesky: #expect(next.difficulty == .hard)
        case .snakesky: #expect(next.difficulty == .easy)
        default: #expect(next.difficulty == nil)
        }
    }

    @Test
    func clearedLevelScoresWithComboAndSpinsAgain() async throws {
        let run = makeRun()
        run.startRun()
        guard case .transition(_, let first) = run.phase else { return }
        run.beginLevel(first)
        run.levelFinished(rawScore: first.par, words: [])
        try await Task.sleep(for: .milliseconds(1200))
        guard case .transition(let previous, let second) = run.phase else {
            Issue.record("expected a transition after clearing level 1"); return
        }
        #expect(previous?.basePoints == 1000)
        #expect(previous?.points == 1000)
        #expect(run.runScore == 1000)
        #expect(second.index == 2)
        #expect(second.game != first.game)
        #expect(abs(second.multiplier - 1.15) < 0.0001)
    }

    @Test
    func zeroScoreEndsTheRunAndReportsIt() async throws {
        var reported: MeddleyskyResult?
        let run = makeRun { reported = $0 }
        run.startRun()
        guard case .transition(_, let first) = run.phase else { return }
        run.beginLevel(first)
        run.levelFinished(rawScore: 0, words: [])
        try await Task.sleep(for: .milliseconds(1200))
        guard case .finished = run.phase else {
            Issue.record("expected the run to be over"); return
        }
        #expect(run.fatalLevel?.index == 1)
        #expect(reported?.score == 0)
        #expect(reported?.levelsCleared == 0)
    }
}
