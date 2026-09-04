import Foundation
import Testing
@testable import HowJaneyLearnedRussian

struct MetaProgressionTests {
    // MARK: Rank ladder

    @Test
    func rankLadderIsMonotonic() {
        let thresholds = Rank.ladder.map(\.threshold)
        #expect(thresholds == thresholds.sorted())
        #expect(thresholds.first == 0)
        #expect(Set(thresholds).count == thresholds.count)
    }

    @Test(arguments: [(0, "Cadet"), (249, "Cadet"), (250, "Private"), (5_999, "Lieutenant"), (100_000, "Marshal")])
    func rankForXP(xp: Int, expected: String) {
        #expect(Rank.rank(forXP: xp).name == expected)
    }

    @Test
    func progressStaysInUnitInterval() {
        for xp in [0, 100, 250, 999, 10_000, 84_999, 85_000, 1_000_000] {
            let progress = Rank.progress(forXP: xp)
            #expect(progress >= 0 && progress <= 1)
        }
        #expect(Rank.progress(forXP: 1_000_000) == 1)
    }

    // MARK: Daily field passport

    @Test
    func dailyMissionsReflectRealRoundWordAndRouteProgress() {
        let missions = DailyMission.today(from: .init(rounds: 1, distinctGames: 3), collectedWords: 8)

        #expect(missions.count == 3)
        #expect(missions[0].isComplete)
        #expect(missions[1].isComplete)
        #expect(missions[2].isComplete)
        #expect(missions.map(\.progressText) == ["1/1", "8/8", "3/3"])
    }

    @Test
    func dailyMissionProgressCapsItsDisplayAtTheGoal() {
        let missions = DailyMission.today(from: .init(rounds: 5, distinctGames: 1), collectedWords: 2)

        #expect(missions[0].progressText == "1/1")
        #expect(missions[1].progressText == "2/8")
        #expect(missions[2].progressText == "1/3")
    }

    // MARK: Trivia state backward compatibility

    @Test
    func oldTriviaStateWithoutFastAnswersDecodes() throws {
        // A pre-fastAnswers blob, as saved by the earlier build.
        let old = """
        {"dateKey":"20260301","currentQuestionIndex":1,"questionScores":[5,4,5],
         "disabledOptions":[[],[2],[]],"revealed":[true,false,false],
         "answerOrder":[[1,0,2,3],[],[]],"started":true,"completed":false}
        """
        let state = try JSONDecoder().decode(TriviaDayState.self, from: Data(old.utf8))
        #expect(state.fastAnswers == [false, false, false])
        #expect(state.questionScores == [5, 4, 5])
    }

    @Test
    func newTriviaStateRoundTripsFastAnswers() throws {
        var state = TriviaDayState(dateKey: "20260301", questionCount: 2)
        state.fastAnswers = [true, false]
        let decoded = try JSONDecoder().decode(
            TriviaDayState.self,
            from: JSONEncoder().encode(state)
        )
        #expect(decoded.fastAnswers == [true, false])
    }

    // MARK: Bogglesky celebration banners

    @Test
    func bannerTiersByLength() {
        #expect(BoggleskyModel.banner(forWordLength: 3, languageID: "ru") == nil)
        #expect(BoggleskyModel.banner(forWordLength: 4, languageID: "ru") == nil)
        #expect(BoggleskyModel.banner(forWordLength: 5, languageID: "ru") == "Хорошо!")
        #expect(BoggleskyModel.banner(forWordLength: 6, languageID: "ru") == "Отлично!")
        #expect(BoggleskyModel.banner(forWordLength: 8, languageID: "ru") == "Легендарно!")
        #expect(BoggleskyModel.banner(forWordLength: 6, languageID: "xx") == "Amazing!")
    }

    // MARK: Sound recipes stay sane

    @Test
    func soundRecipesAreWellFormed() {
        var effects: [SoundEffect] = [
            .deselect, .correct, .wrong, .penalty, .boardClear, .gameEnd,
            .tick, .explode, .newWord, .slash,
        ]
        effects.append(contentsOf: (0..<SoundEffect.maxSelectSteps).map { .select(step: $0) })
        for effect in effects {
            let layers = effect.layers
            #expect(!layers.isEmpty)
            #expect(effect.length > 0 && effect.length < 2.0)
            for layer in layers {
                #expect(layer.duration > 0)
                #expect(layer.gain > 0 && layer.gain <= 0.2, "UI sounds stay quiet")
                #expect(layer.frequency > 20 && layer.frequency < 12_000)
            }
        }
    }

    // MARK: Achievement IDs are stable (App Store Connect contract)

    @Test
    func achievementIdentifiersAreStable() {
        #expect(AchievementService.ID.perfectRootsky.rawValue == "perfect_rootsky")
        #expect(AchievementService.ID.streak100.rawValue == "streak_100")
    }
}
