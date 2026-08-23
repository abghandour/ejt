import Foundation

/// Pure Tetrisky rules, ported from web/mobile/tetrisky.html: single-letter
/// pieces fall onto an 8×14 board; any horizontal/vertical run that spells a
/// dictionary word (≥3 letters) clears for points, with gravity + one chain.
nonisolated enum TetriskyEngine {
    static let columns = 8
    static let rows = 14
    static let targetBonus = 50
    static let minTickMilliseconds = 300
    static let speedUpPerTarget = 30

    struct Falling: Hashable, Sendable {
        var row: Int
        var col: Int
        let letter: Character
    }

    struct FoundBoardWord: Sendable {
        let word: String
        let cells: [(row: Int, col: Int)]
    }

    struct State: Sendable {
        /// board[row][col], row 0 at the top.
        var board: [[Character?]]
        var falling: Falling?
        var score = 0
        var wordsCompleted = 0
        var completedWords: [String] = []
        var targetWord: WordEntry
        var wordQueue: [WordEntry]
        var wordQueueIndex = 0
        var tickMilliseconds: Int
        var isAlive = true
        var rng: SeedEngine
    }

    static func makeState(dictionary: [WordEntry], seed: Int, tickMilliseconds: Int) -> State {
        var rng = SeedEngine(seed: seed)
        let queue = rng.shuffle(dictionary)
        return State(
            board: Array(repeating: Array(repeating: nil, count: columns), count: rows),
            falling: nil,
            targetWord: queue[0],
            wordQueue: queue,
            tickMilliseconds: tickMilliseconds,
            rng: rng
        )
    }

    /// Weighted letter choice: 40% from the target word, then 50/50 between a
    /// random dictionary word's letter and the language alphabet.
    static func pickLetter(_ state: inout State, dictionary: [WordEntry], alphabet: [Character]) -> Character {
        let target = Array(state.targetWord.word.lowercased())
        if !target.isEmpty, state.rng.next() < 0.4 {
            return target[state.rng.nextInt(target.count)]
        }
        if state.rng.next() < 0.5 {
            let word = Array(dictionary[state.rng.nextInt(dictionary.count)].word.lowercased())
            if !word.isEmpty {
                return word[state.rng.nextInt(word.count)]
            }
        }
        return alphabet[state.rng.nextInt(alphabet.count)]
    }

    /// Spawns a piece at the top; a blocked spawn cell ends the game.
    static func spawn(_ state: inout State, dictionary: [WordEntry], alphabet: [Character]) {
        let col = state.rng.nextInt(columns)
        let letter = pickLetter(&state, dictionary: dictionary, alphabet: alphabet)
        state.falling = Falling(row: 0, col: col, letter: letter)
        if state.board[0][col] != nil {
            state.isAlive = false
        }
    }

    /// All dictionary words on the board (left→right, top→bottom, ≥3 letters),
    /// longest first, overlapping matches dropped.
    static func findWords(board: [[Character?]], wordSet: Set<String>) -> [FoundBoardWord] {
        var found: [FoundBoardWord] = []

        for r in 0..<rows {
            for startC in 0..<columns where board[r][startC] != nil {
                var text = ""
                var cells: [(Int, Int)] = []
                var c = startC
                while c < columns, let letter = board[r][c] {
                    text.append(letter)
                    cells.append((r, c))
                    if text.count >= 3, wordSet.contains(text) {
                        found.append(FoundBoardWord(word: text, cells: cells))
                    }
                    c += 1
                }
            }
        }
        for c in 0..<columns {
            for startR in 0..<rows where board[startR][c] != nil {
                var text = ""
                var cells: [(Int, Int)] = []
                var r = startR
                while r < rows, let letter = board[r][c] {
                    text.append(letter)
                    cells.append((r, c))
                    if text.count >= 3, wordSet.contains(text) {
                        found.append(FoundBoardWord(word: text, cells: cells))
                    }
                    r += 1
                }
            }
        }

        var used = Set<Int>()
        var result: [FoundBoardWord] = []
        for candidate in found.sorted(by: { $0.word.count > $1.word.count }) {
            let keys = candidate.cells.map { $0.row * columns + $0.col }
            if keys.allSatisfy({ !used.contains($0) }) {
                result.append(candidate)
                used.formUnion(keys)
            }
        }
        return result
    }

    /// Clears found words, scores them, advances the target on a match.
    /// Returns true when the target word itself was cleared.
    static func clear(_ state: inout State, words: [FoundBoardWord], dictionary: [WordEntry]) -> Bool {
        var clearedTarget = false
        for found in words {
            state.completedWords.append(found.word)
            state.wordsCompleted += 1
            state.score += found.word.count * 10
            if found.word == state.targetWord.word.lowercased() {
                state.score += targetBonus
                advanceTarget(&state, dictionary: dictionary)
                clearedTarget = true
            }
            for cell in found.cells {
                state.board[cell.row][cell.col] = nil
            }
        }
        return clearedTarget
    }

    static func applyGravity(_ state: inout State) {
        for c in 0..<columns {
            var writeRow = rows - 1
            for r in stride(from: rows - 1, through: 0, by: -1) {
                if let letter = state.board[r][c] {
                    if writeRow != r {
                        state.board[writeRow][c] = letter
                        state.board[r][c] = nil
                    }
                    writeRow -= 1
                }
            }
        }
    }

    static func advanceTarget(_ state: inout State, dictionary: [WordEntry]) {
        state.wordQueueIndex += 1
        if state.wordQueueIndex >= state.wordQueue.count {
            state.wordQueue = state.rng.shuffle(dictionary)
            state.wordQueueIndex = 0
        }
        state.targetWord = state.wordQueue[state.wordQueueIndex]
        state.tickMilliseconds = max(minTickMilliseconds, state.tickMilliseconds - speedUpPerTarget)
    }

    /// Lands the current piece and resolves words + gravity + one chain pass.
    /// Returns the words cleared (empty if none).
    static func land(_ state: inout State, wordSet: Set<String>, dictionary: [WordEntry]) -> [String] {
        guard let falling = state.falling else { return [] }
        state.board[falling.row][falling.col] = falling.letter
        state.falling = nil

        var cleared: [String] = []
        let words = findWords(board: state.board, wordSet: wordSet)
        if !words.isEmpty {
            cleared.append(contentsOf: words.map(\.word))
            _ = clear(&state, words: words, dictionary: dictionary)
            applyGravity(&state)
            let chain = findWords(board: state.board, wordSet: wordSet)
            if !chain.isEmpty {
                cleared.append(contentsOf: chain.map(\.word))
                _ = clear(&state, words: chain, dictionary: dictionary)
                applyGravity(&state)
            }
        }
        return cleared
    }

    /// Where the falling piece would land (ghost row), or nil.
    static func ghostRow(_ state: State) -> Int? {
        guard let falling = state.falling else { return nil }
        var row = falling.row
        while row + 1 < rows, state.board[row + 1][falling.col] == nil {
            row += 1
        }
        return row
    }
}
