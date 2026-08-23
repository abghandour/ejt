import CoreGraphics
import Testing
@testable import HowJaneyLearnedRussian

/// Engine tests for the three arcade ports: Snakesky, Tetrisky, Slashsky.
struct ArcadeEngineTests {
    private let dictionary = [
        WordEntry(word: "кот", translation: "cat"),
        WordEntry(word: "дом", translation: "house"),
        WordEntry(word: "мир", translation: "world"),
    ]

    // MARK: Snakesky

    @Test
    func snakeInitialStateIsCentered() {
        let state = SnakeskyEngine.makeState(dictionary: dictionary, seed: 1)
        #expect(state.snake.count == 3)
        #expect(state.snake[0] == SnakeskyEngine.Point(x: 7, y: 7))
        #expect(state.heading == .right)
        #expect(state.currentWord != nil)
        #expect(state.letterDots.count == state.currentWord?.word.count)
    }

    @Test
    func snakeTurnsAreRelative() {
        #expect(SnakeskyEngine.Heading.right.turned(.left) == .up)
        #expect(SnakeskyEngine.Heading.right.turned(.right) == .down)
        #expect(SnakeskyEngine.Heading.up.turned(.left) == .left)
        #expect(SnakeskyEngine.Heading.left.turned(.right) == .up)
    }

    @Test
    func snakeDiesAtTheWall() {
        var state = SnakeskyEngine.makeState(dictionary: dictionary, seed: 3)
        // March right until the wall — at most gridSize steps.
        state.letterDots = []
        var died = false
        for _ in 0..<SnakeskyEngine.gridSize {
            if case .died(let cause) = SnakeskyEngine.step(&state) {
                #expect(cause == .wall)
                died = true
                break
            }
        }
        #expect(died)
    }

    @Test
    func snakeEatsLettersInOrderAndGrows() {
        var state = SnakeskyEngine.makeState(dictionary: dictionary, seed: 5)
        // Plant the first needed letter directly in the snake's path.
        let head = state.snake[0]
        let firstLetter = state.currentWord!.word.lowercased().first!
        state.letterDots = [
            SnakeskyEngine.LetterDot(point: SnakeskyEngine.Point(x: head.x + 1, y: head.y), letter: firstLetter, index: 0)
        ]
        let lengthBefore = state.snake.count
        let outcome = SnakeskyEngine.step(&state)
        if case .died = outcome {
            Issue.record("snake should not die eating the correct letter")
        }
        #expect(state.letterProgress == 1)
        _ = SnakeskyEngine.step(&state)
        #expect(state.snake.count == lengthBefore + 1)
    }

    @Test
    func wrongOrderLetterKills() {
        var state = SnakeskyEngine.makeState(dictionary: dictionary, seed: 5)
        let head = state.snake[0]
        // A letter with index 1 sits in the path while progress is 0.
        state.letterDots = [
            SnakeskyEngine.LetterDot(point: SnakeskyEngine.Point(x: head.x + 1, y: head.y), letter: "х", index: 1)
        ]
        guard case .died(let cause) = SnakeskyEngine.step(&state) else {
            Issue.record("expected death on out-of-order letter")
            return
        }
        #expect(cause == .wrongLetter)
    }

    // MARK: Tetrisky

    @Test
    func tetriskyFindsHorizontalAndVerticalWords() {
        var board: [[Character?]] = Array(
            repeating: Array(repeating: nil, count: TetriskyEngine.columns),
            count: TetriskyEngine.rows
        )
        // "кот" horizontally on the bottom row.
        board[13][0] = "к"
        board[13][1] = "о"
        board[13][2] = "т"
        // "дом" vertically in the last column.
        board[11][7] = "д"
        board[12][7] = "о"
        board[13][7] = "м"
        let found = TetriskyEngine.findWords(board: board, wordSet: ["кот", "дом"])
        #expect(Set(found.map(\.word)) == ["кот", "дом"])
    }

    @Test
    func tetriskyGravityCompacts() {
        var state = TetriskyEngine.makeState(dictionary: dictionary, seed: 1, tickMilliseconds: 800)
        state.board[5][3] = "а"
        state.board[9][3] = "б"
        TetriskyEngine.applyGravity(&state)
        #expect(state.board[13][3] == "б")
        #expect(state.board[12][3] == "а")
        #expect(state.board[5][3] == nil)
    }

    @Test
    func tetriskyClearScoresAndTargetBonus() {
        var state = TetriskyEngine.makeState(dictionary: dictionary, seed: 7, tickMilliseconds: 800)
        let target = state.targetWord.word.lowercased()
        for (i, letter) in target.enumerated() {
            state.board[13][i] = letter
        }
        let words = TetriskyEngine.findWords(board: state.board, wordSet: [target])
        let clearedTarget = TetriskyEngine.clear(&state, words: words, dictionary: dictionary)
        #expect(clearedTarget)
        #expect(state.score == target.count * 10 + TetriskyEngine.targetBonus)
        #expect(state.board[13][0] == nil)
    }

    @Test
    func tetriskySpeedsUpWithFloor() {
        var state = TetriskyEngine.makeState(dictionary: dictionary, seed: 1, tickMilliseconds: 320)
        TetriskyEngine.advanceTarget(&state, dictionary: dictionary)
        #expect(state.tickMilliseconds == TetriskyEngine.minTickMilliseconds)
    }

    // MARK: Slashsky

    private var fruitDictionary: SlashskyEngine.Dictionary {
        SlashskyEngine.Dictionary(
            words: [
                SlashskyEngine.MainWord(
                    word: "большой", translation: "big",
                    synonyms: [
                        .init(word: "крупный", translation: "large"),
                        .init(word: "огромный", translation: "huge"),
                        .init(word: "великий", translation: "great"),
                    ]
                ),
                SlashskyEngine.MainWord(
                    word: "быстрый", translation: "fast",
                    synonyms: [
                        .init(word: "скорый", translation: "quick"),
                        .init(word: "шустрый", translation: "nimble"),
                        .init(word: "резвый", translation: "swift"),
                    ]
                ),
            ],
            distractors: [.init(word: "медленный", translation: "slow")]
        )
    }

    @Test
    func slashskySlashScoring() {
        var state = SlashskyEngine.makeState(dictionary: fruitDictionary, seed: 1)
        SlashskyEngine.processSlash(&state, type: .synonym, synonymWord: "крупный")
        #expect(state.score == 10)
        #expect(state.totalSynonymsSlashed == 1)
        SlashskyEngine.processSlash(&state, type: .distractor, synonymWord: nil)
        #expect(state.lives == 2)
        SlashskyEngine.processSlash(&state, type: .powerup, synonymWord: nil)
        #expect(state.timeRemaining == 65)
        SlashskyEngine.processSlash(&state, type: .bomb, synonymWord: nil)
        #expect(state.timeRemaining == 60)
    }

    @Test
    func slashskyThreeDistractorsEndTheGame() {
        var state = SlashskyEngine.makeState(dictionary: fruitDictionary, seed: 1)
        for _ in 0..<3 {
            SlashskyEngine.processSlash(&state, type: .distractor, synonymWord: nil)
        }
        #expect(state.isGameOver)
        #expect(state.lives == 0)
    }

    @Test
    func slashskyRotationBonusAndReset() {
        var state = SlashskyEngine.makeState(dictionary: fruitDictionary, seed: 1)
        let before = state.currentMainWord.word
        for synonym in state.currentMainWord.synonyms {
            SlashskyEngine.processSlash(&state, type: .synonym, synonymWord: synonym.word)
        }
        #expect(SlashskyEngine.allSynonymsCollected(state))
        SlashskyEngine.rotateMainWord(&state, dictionary: fruitDictionary)
        #expect(state.score == 30 + 25)
        #expect(state.wordsCompleted == 1)
        #expect(state.collectedSynonyms.isEmpty)
        #expect(state.currentMainWord.word != before)
    }

    @Test
    func slashskyDifficultyRamp() {
        let start = SlashskyEngine.computeDifficulty(elapsedSeconds: 0)
        #expect(start.launchSpeed == 1.0)
        #expect(start.launchInterval == 1.5)
        #expect(start.maxSimultaneous == 3)
        let end = SlashskyEngine.computeDifficulty(elapsedSeconds: 60)
        #expect(end.launchSpeed == 2.0)
        #expect(end.launchInterval == 0.6)
        #expect(end.maxSimultaneous == 5)
        #expect(abs(end.distractorRatio - 0.7) < 0.0001)
    }

    @Test
    func liangBarskySegmentIntersection() {
        let rect = CGRect(x: 10, y: 10, width: 20, height: 20)
        // Crossing through.
        #expect(SlashskyEngine.segmentIntersectsRect(from: CGPoint(x: 0, y: 20), to: CGPoint(x: 40, y: 20), rect: rect))
        // Fully inside.
        #expect(SlashskyEngine.segmentIntersectsRect(from: CGPoint(x: 12, y: 12), to: CGPoint(x: 18, y: 18), rect: rect))
        // Missing entirely.
        #expect(!SlashskyEngine.segmentIntersectsRect(from: CGPoint(x: 0, y: 0), to: CGPoint(x: 5, y: 40), rect: rect))
        // Parallel outside.
        #expect(!SlashskyEngine.segmentIntersectsRect(from: CGPoint(x: 0, y: 5), to: CGPoint(x: 40, y: 5), rect: rect))
    }

    @Test
    func slashskyPhysicsFallsOffBottom() {
        var rng = SeedEngine(seed: 9)
        var word = SlashskyEngine.createFlyingWord(
            id: 1, text: "тест", translation: "test", type: .synonym,
            areaWidth: 400, areaHeight: 600, rng: &rng
        )
        var alive = true
        var steps = 0
        while alive, steps < 1000 {
            alive = SlashskyEngine.updatePosition(&word, dt: 1 / 60, areaHeight: 600)
            steps += 1
        }
        #expect(!alive, "word should eventually fall off the bottom")
        #expect(steps > 10, "word should be airborne for a while first")
    }
}
