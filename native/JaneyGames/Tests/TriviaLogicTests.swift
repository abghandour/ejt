import Foundation
import Testing
@testable import JaneyGames

struct TriviaLogicTests {
    // MARK: Question validation (port of validateQuestion)

    private func makeQuestion(
        question: String = "Столица России?",
        answers: [String] = ["Москва", "Париж", "Лондон"],
        correctIndex: Int = 0
    ) -> TriviaQuestion {
        TriviaQuestion(
            question: question, answers: answers, correctIndex: correctIndex,
            category: nil, hint: nil, questionTranslation: nil, answerTranslations: nil,
            image: nil, postAnswerImage: nil, timerSeconds: nil
        )
    }

    @Test
    func validQuestionPasses() {
        #expect(makeQuestion().isValid)
    }

    @Test
    func emptyQuestionFails() {
        #expect(!makeQuestion(question: "  ").isValid)
    }

    @Test
    func answerCountBoundsEnforced() {
        #expect(!makeQuestion(answers: ["один"]).isValid)
        #expect(!makeQuestion(answers: Array(repeating: "а", count: 7), correctIndex: 0).isValid)
        #expect(makeQuestion(answers: ["а", "б"], correctIndex: 1).isValid)
    }

    @Test
    func correctIndexMustBeInRange() {
        #expect(!makeQuestion(correctIndex: 3).isValid)
        #expect(!makeQuestion(correctIndex: -1).isValid)
    }

    @Test
    func blankAnswerFails() {
        #expect(!makeQuestion(answers: ["Москва", " ", "Лондон"]).isValid)
    }

    // MARK: Shuffle order

    @Test
    func shuffledOrderIsAPermutation() {
        var rng = SeedEngine(seed: 5)
        let order = TriviaLogic.shuffledOrder(count: 5, rng: &rng)
        #expect(order.sorted() == [0, 1, 2, 3, 4])
    }

    @Test
    func correctPositionTracksThroughShuffle() {
        for seed in 0..<50 {
            var rng = SeedEngine(seed: seed)
            let order = TriviaLogic.shuffledOrder(count: 5, rng: &rng)
            let position = TriviaLogic.correctPosition(order: order, correctIndex: 2)
            #expect(order[position] == 2)
        }
    }

    // MARK: Date keys

    @Test
    func dateKeyRoundTrips() throws {
        let date = try #require(TriviaLogic.date(fromKey: "20260305"))
        #expect(TriviaLogic.dateKey(for: date) == "20260305")
    }

    @Test
    func invalidKeyReturnsNil() {
        #expect(TriviaLogic.date(fromKey: "2026035") == nil)
        #expect(TriviaLogic.date(fromKey: "banana!!") == nil)
    }

    // MARK: Day state

    @Test
    func freshStateHasFiveStarsPerQuestion() {
        let state = TriviaDayState(dateKey: "20260206", questionCount: 7)
        #expect(state.questionScores == Array(repeating: 5, count: 7))
        #expect(state.totalScore == 35)
        #expect(state.maxScore == 35)
        #expect(!state.completed && !state.started)
    }

    @Test
    func stateRoundTripsThroughJSON() throws {
        var state = TriviaDayState(dateKey: "20260206", questionCount: 3)
        state.questionScores = [5, 3, 0]
        state.revealed = [true, true, false]
        state.answerOrder = [[2, 0, 1, 3, 4], [], []]
        state.disabledOptions = [[], [1, 4], []]
        state.currentQuestionIndex = 2
        state.started = true

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(TriviaDayState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.totalScore == 8)
    }

    @Test
    func stateMatchesQuestionsGuardsShapeChanges() {
        let questions = [makeQuestion(), makeQuestion(), makeQuestion()]
        var state = TriviaDayState(dateKey: "20260206", questionCount: 3)
        #expect(state.matches(questions: questions))

        // Wrong question count → stale.
        let bigger = TriviaDayState(dateKey: "20260206", questionCount: 4)
        #expect(!bigger.matches(questions: questions))

        // An answer order that no longer fits the answer count → stale.
        state.answerOrder[0] = [0, 1, 2, 3, 4]
        #expect(!state.matches(questions: questions))
    }

    // MARK: Bundled data sanity

    @Test
    func russianTriviaLoadsAndValidates() throws {
        let url = try #require(
            Bundle.main.url(forResource: "triviatsky", withExtension: "json", subdirectory: "Dictionaries/ru")
        )
        let data = try Data(contentsOf: url)
        let days = try JSONDecoder().decode([String: [TriviaQuestion]].self, from: data)
        #expect(!days.isEmpty)
        for key in days.keys {
            #expect(key.count == 8)
        }
        // The shipped data contains some questions with a null correctIndex
        // (the web version silently skips them). Lenient decoding must keep the
        // file loadable, mark those invalid, and leave every day playable.
        for (key, questions) in days {
            let validCount = questions.count(where: \.isValid)
            #expect(validCount >= 2, "day \(key) has too few valid questions")
            for question in questions where !question.isValid {
                #expect(question.correctIndex == -1, "unexpected invalidity on \(key): \(question.question)")
            }
        }
    }

    @Test
    func malformedCorrectIndexDecodesAsInvalid() throws {
        let json = #"[{"question": "т", "answers": ["а", "б"], "correctIndex": null}]"#
        let questions = try JSONDecoder().decode([TriviaQuestion].self, from: Data(json.utf8))
        #expect(questions.count == 1)
        #expect(!questions[0].isValid)
    }
}
