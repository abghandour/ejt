import Foundation
import Testing
@testable import HowJaneyLearnedRussian

struct RootskyLogicTests {
    private func makeWord(
        word: String = "поспешный",
        translation: String = "hasty",
        options: [String] = ["a", "b", "c", "d", "e"]
    ) -> RootskyWord {
        RootskyWord(
            wordOfTheDay: word,
            translation: translation,
            wordOptions: options,
            rootWord: "спешить",
            rootTranslation: "to hurry"
        )
    }

    // MARK: Validation (ported from validateWordEntry)

    @Test
    func validWordPasses() {
        #expect(makeWord().isValid)
    }

    @Test
    func emptyFieldsFail() {
        #expect(!makeWord(word: " ").isValid)
        #expect(!makeWord(translation: "").isValid)
        #expect(!makeWord(options: ["a", "b", "c", "d", " "]).isValid)
    }

    @Test
    func exactlyFiveOptionsRequired() {
        #expect(!makeWord(options: ["a", "b", "c", "d"]).isValid)
        #expect(!makeWord(options: ["a", "b", "c", "d", "e", "f"]).isValid)
    }

    // MARK: Day state

    @Test
    func freshStateShape() {
        let state = RootskyDayState(dateKey: "20260821")
        #expect(state.wordScores == [5, 5, 5, 5, 5])
        #expect(state.totalScore == 25)
        #expect(state.isShapeValid)
        #expect(!state.started && !state.completed)
    }

    @Test
    func stateRoundTripsThroughJSON() throws {
        var state = RootskyDayState(dateKey: "20260821")
        state.wordScores = [5, 4, 3, 0, 5]
        state.disabledAnswers = [[], ["x"], ["y", "z"], ["a", "b", "c", "d", "e"], []]
        state.currentWordIndex = 4
        state.started = true
        state.elapsedSeconds = 123
        state.wordTimes = [10, 20, 30, 40, 0]

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(RootskyDayState.self, from: data)
        #expect(decoded == state)
        #expect(decoded.totalScore == 17)
    }

    // MARK: Bundled data sanity

    @Test
    func russianRootskyLoadsWithFiveWordDays() throws {
        let url = try #require(
            Bundle.main.url(forResource: "rootsky", withExtension: "json", subdirectory: "Dictionaries/ru")
        )
        let data = try Data(contentsOf: url)
        let days = try JSONDecoder().decode([String: [RootskyWord]].self, from: data)
        #expect(days.count > 200)
        for (key, words) in days {
            #expect(key.count == 8)
            #expect(words.count == 5, "day \(key) should have 5 words")
            let allValid = words.allSatisfy { $0.isValid }
            #expect(allValid, "day \(key) has invalid words")
        }
    }

    // MARK: Speech voice mapping

    @Test
    func voiceLanguageMapping() {
        #expect(SpeechService.voiceLanguage(for: "ru") == "ru-RU")
        #expect(SpeechService.voiceLanguage(for: "uk") == "uk-UA")
        #expect(SpeechService.voiceLanguage(for: "pt-br") == "pt-BR")
    }
}
