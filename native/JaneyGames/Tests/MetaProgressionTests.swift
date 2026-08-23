import Foundation
import Testing
@testable import JaneyGames

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

    // MARK: Achievement IDs are stable (App Store Connect contract)

    @Test
    func achievementIdentifiersAreStable() {
        #expect(AchievementService.ID.perfectRootsky.rawValue == "perfect_rootsky")
        #expect(AchievementService.ID.streak100.rawValue == "streak_100")
    }
}
