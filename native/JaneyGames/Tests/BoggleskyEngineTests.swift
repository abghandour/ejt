import Testing
@testable import JaneyGames

struct BoggleskyEngineTests {
    // MARK: Adjacency

    @Test
    func cornerHasThreeNeighbors() {
        #expect(Set(BoggleskyEngine.neighbors(of: 0, size: 4)) == [1, 4, 5])
    }

    @Test
    func centerHasEightNeighbors() {
        #expect(BoggleskyEngine.neighbors(of: 5, size: 4).count == 8)
    }

    // MARK: Path validation

    @Test
    func adjacentNonRepeatingPathIsValid() {
        #expect(BoggleskyEngine.isValidPath([0, 1, 5, 4], size: 4))
    }

    @Test
    func nonAdjacentStepIsInvalid() {
        #expect(!BoggleskyEngine.isValidPath([0, 2], size: 4))
    }

    @Test
    func repeatedCellIsInvalid() {
        #expect(!BoggleskyEngine.isValidPath([0, 1, 0], size: 4))
    }

    @Test
    func singleCellIsInvalid() {
        #expect(!BoggleskyEngine.isValidPath([3], size: 4))
    }

    // MARK: Scoring (ported table: ≤3→1, 4→2, 5→4, 6→6, else len×2; hard ×1.5)

    @Test(arguments: [(3, 1), (4, 2), (5, 4), (6, 6), (7, 14), (8, 16)])
    func mediumScores(length: Int, expected: Int) {
        #expect(BoggleskyDifficulty.medium.score(forWordLength: length) == expected)
    }

    @Test(arguments: [(3, 2), (4, 3), (5, 6), (6, 9), (7, 21)])
    func hardScoresAreOneAndAHalfTimes(length: Int, expected: Int) {
        #expect(BoggleskyDifficulty.hard.score(forWordLength: length) == expected)
    }

    // MARK: Word finding

    private func makeTrie(_ words: [String]) -> BoggleskyEngine.Trie {
        BoggleskyEngine.Trie.build(words: words, minLength: 3, maxLength: 16)
    }

    @Test
    func findsWordAlongAdjacentPath() {
        // Board:  к о т
        //         а р м
        //         с у п
        let board = Array("кот" + "арм" + "суп")
        let found = BoggleskyEngine.findAllWords(
            letters: board,
            size: 3,
            trie: makeTrie(["кот", "суп", "рот", "мир"])
        )
        #expect(found.contains("кот"))
        #expect(found.contains("суп"))
        // "рот": р(4)→о(1)→т(2) — all adjacent, present on the board.
        #expect(found.contains("рот"))
        #expect(!found.contains("мир"))
    }

    @Test
    func doesNotReuseACell() {
        // "оол" needs two 'о' cells; board has only one.
        let board = Array("ол" + "ба")
        let found = BoggleskyEngine.findAllWords(letters: board, size: 2, trie: makeTrie(["оол"]))
        #expect(found.isEmpty)
    }

    @Test
    func wordsShorterThanMinimumAreExcludedFromTrie() {
        let trie = BoggleskyEngine.Trie.build(words: ["он", "она"], minLength: 3, maxLength: 16)
        let found = BoggleskyEngine.findAllWords(letters: Array("он" + "ат"), size: 2, trie: trie)
        #expect(found == ["она"])
    }

    // MARK: Board generation

    @Test
    func generatedBoardMeetsMinimumWhenDictionaryAllows() {
        // A pool of just two letters with matching short words makes success certain.
        var rng = SeedEngine(seed: 7)
        let trie = makeTrie(["ооо", "ааа", "оао", "аоа", "ооа", "аао", "оаа", "аоо"])
        let board = BoggleskyEngine.generateBoard(
            size: 4,
            pool: Array("оа"),
            trie: trie,
            rng: &rng
        )
        #expect(board.letters.count == 16)
        #expect(board.findableWords.count >= BoggleskyEngine.minFindableWords)
    }

    @Test
    func generationIsDeterministicForASeed() {
        let trie = makeTrie(["ооо", "ааа"])
        var rng1 = SeedEngine(seed: 99)
        var rng2 = SeedEngine(seed: 99)
        let a = BoggleskyEngine.generateBoard(size: 4, pool: Array("оаи"), trie: trie, rng: &rng1)
        let b = BoggleskyEngine.generateBoard(size: 4, pool: Array("оаи"), trie: trie, rng: &rng2)
        #expect(a.letters == b.letters)
    }

    @Test
    func impossibleDictionaryStillReturnsABoard() {
        var rng = SeedEngine(seed: 1)
        let trie = makeTrie(["яяяяяя"])
        let board = BoggleskyEngine.generateBoard(
            size: 4,
            pool: Array("оа"),
            trie: trie,
            rng: &rng,
            maxAttempts: 5
        )
        #expect(board.letters.count == 16)
        #expect(board.findableWords.isEmpty)
    }

    @Test
    func wordFromPathReadsLetters() {
        let board = Array("кота")
        #expect(BoggleskyEngine.word(fromPath: [0, 1, 2], letters: board) == "кот")
    }
}
