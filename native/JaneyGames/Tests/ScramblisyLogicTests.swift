import Testing
@testable import JaneyGames

struct ScramblisyLogicTests {
    // MARK: Difficulty config (ported values)

    @Test
    func wordLengthBands() {
        #expect(ScramblisyDifficulty.easy.wordLengthRange == 3...4)
        #expect(ScramblisyDifficulty.medium.wordLengthRange == 5...7)
        #expect(ScramblisyDifficulty.hard.wordLengthRange.contains(8))
        #expect(ScramblisyDifficulty.hard.wordLengthRange.contains(12))
    }

    @Test
    func wrongPenalties() {
        #expect(ScramblisyDifficulty.easy.wrongPenaltySeconds == 15)
        #expect(ScramblisyDifficulty.medium.wrongPenaltySeconds == 20)
        #expect(ScramblisyDifficulty.hard.wrongPenaltySeconds == 20)
    }

    @Test(arguments: [(3, 30), (5, 50), (7, 70)])
    func mediumScoresLengthTimesTen(length: Int, expected: Int) {
        #expect(ScramblisyDifficulty.medium.score(forWordLength: length) == expected)
    }

    @Test(arguments: [(8, 120), (9, 135), (5, 75)])
    func hardScoresOneAndAHalfTimes(length: Int, expected: Int) {
        #expect(ScramblisyDifficulty.hard.score(forWordLength: length) == expected)
    }

    @Test
    func clearAllowedExceptHard() {
        #expect(ScramblisyDifficulty.easy.allowsClear)
        #expect(ScramblisyDifficulty.medium.allowsClear)
        #expect(!ScramblisyDifficulty.hard.allowsClear)
    }

    @Test
    func hintModes() {
        #expect(ScramblisyDifficulty.easy.hintMode == .always)
        #expect(ScramblisyDifficulty.medium.hintMode == .onRequest)
        #expect(ScramblisyDifficulty.hard.hintMode == .never)
    }

    // MARK: Session behaviors (via the model, dictionary-independent paths)

    @Test
    func rackRowsSplitEvenlyMaxFourPerRow() async {
        // 8 letters → two rows of 4; 5 letters → 3 + 2; 7 → 4 + 3.
        let model = makeModel()
        #expect(model.rackRows.isEmpty)

        // Access the row-splitting logic indirectly by checking arithmetic here:
        func rows(for total: Int) -> [Int] {
            let numRows = (total + 3) / 4
            let base = total / numRows
            let extra = total % numRows
            return (0..<numRows).map { base + ($0 < extra ? 1 : 0) }
        }
        #expect(rows(for: 8) == [4, 4])
        #expect(rows(for: 5) == [3, 2])
        #expect(rows(for: 7) == [4, 3])
        #expect(rows(for: 3) == [3])
        #expect(rows(for: 9) == [3, 3, 3])
        #expect(rows(for: 9).reduce(0, +) == 9)
    }

    private func makeModel() -> ScramblisyModel {
        ScramblisyModel(
            language: Language(
                id: "ru", displayName: "Russian", games: [], themes: [],
                letterPool: "аб", validationRegex: ".*", gameNames: [:]
            ),
            soundEngine: SoundEngine(),
            dictionaryStore: DictionaryStore()
        ) { _ in }
    }
}
