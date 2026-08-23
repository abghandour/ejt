import Foundation

/// Pure Snakesky rules, ported from web/mobile/snakesky.html: a snake on a
/// 15×15 grid eats the current word's letters in order; walls, its own body,
/// and out-of-order letters kill it.
nonisolated enum SnakeskyEngine {
    static let gridSize = 15

    struct Point: Hashable, Sendable {
        var x: Int
        var y: Int
    }

    enum Heading: Int, Sendable {
        case up = 0, right, down, left

        var dx: Int { [0, 1, 0, -1][rawValue] }
        var dy: Int { [-1, 0, 1, 0][rawValue] }

        func turned(_ turn: Turn) -> Heading {
            switch turn {
            case .left: Heading(rawValue: (rawValue + 3) % 4) ?? self
            case .right: Heading(rawValue: (rawValue + 1) % 4) ?? self
            }
        }
    }

    enum Turn: Sendable {
        case left, right
    }

    struct LetterDot: Hashable, Sendable {
        let point: Point
        let letter: Character
        /// Position of this letter within the current word.
        let index: Int
    }

    enum Collision: Sendable {
        case wall, body, wrongLetter
    }

    enum StepOutcome: Sendable {
        case moved
        case ateLetter
        case completedWord(WordEntry)
        case died(Collision)
    }

    struct State: Sendable {
        var snake: [Point]
        var heading: Heading
        var pendingTurn: Turn?
        var currentWord: WordEntry?
        var letterProgress = 0
        var letterDots: [LetterDot] = []
        var score = 0
        var wordsCompleted = 0
        var completedWords: [WordEntry] = []
        var growing = 0
        var wordQueue: [WordEntry]
        var wordQueueIndex = 0
        var rng: SeedEngine
    }

    /// Fresh state: 3-segment snake heading right from the grid center.
    static func makeState(dictionary: [WordEntry], seed: Int) -> State {
        var rng = SeedEngine(seed: seed)
        let queue = rng.shuffle(dictionary)
        let c = gridSize / 2
        var state = State(
            snake: [Point(x: c, y: c), Point(x: c - 1, y: c), Point(x: c - 2, y: c)],
            heading: .right,
            pendingTurn: nil,
            currentWord: nil,
            wordQueue: queue,
            rng: rng
        )
        loadNextWord(&state)
        return state
    }

    static func loadNextWord(_ state: inout State) {
        if state.wordQueueIndex >= state.wordQueue.count {
            state.wordQueue = state.rng.shuffle(state.wordQueue)
            state.wordQueueIndex = 0
        }
        state.currentWord = state.wordQueue[state.wordQueueIndex]
        state.wordQueueIndex += 1
        state.letterProgress = 0
        placeWord(&state)
    }

    /// Scatters the word's letters on cells not occupied by the snake.
    static func placeWord(_ state: inout State) {
        state.letterDots = []
        var occupied = Set(state.snake)
        guard let word = state.currentWord else { return }
        for (index, letter) in word.word.lowercased().enumerated() {
            var point = Point(x: 0, y: 0)
            for attempt in 0...500 {
                point = Point(x: state.rng.nextInt(gridSize), y: state.rng.nextInt(gridSize))
                if !occupied.contains(point) || attempt == 500 { break }
            }
            occupied.insert(point)
            state.letterDots.append(LetterDot(point: point, letter: letter, index: index))
        }
    }

    static func collision(in state: State, head: Point) -> Collision? {
        if head.x < 0 || head.x >= gridSize || head.y < 0 || head.y >= gridSize {
            return .wall
        }
        // The tail cell vacates this tick unless the snake is growing.
        let bodyLength = state.growing > 0 ? state.snake.count : state.snake.count - 1
        if state.snake.prefix(bodyLength).contains(head) {
            return .body
        }
        if let dot = state.letterDots.first(where: { $0.point == head }), dot.index != state.letterProgress {
            return .wrongLetter
        }
        return nil
    }

    /// One game tick: turn, move, collide, eat.
    static func step(_ state: inout State) -> StepOutcome {
        if let turn = state.pendingTurn {
            state.heading = state.heading.turned(turn)
            state.pendingTurn = nil
        }

        let head = state.snake[0]
        let newHead = Point(x: head.x + state.heading.dx, y: head.y + state.heading.dy)

        if let hit = collision(in: state, head: newHead) {
            return .died(hit)
        }

        state.snake.insert(newHead, at: 0)
        if state.growing > 0 {
            state.growing -= 1
        } else {
            state.snake.removeLast()
        }

        if let dotIndex = state.letterDots.firstIndex(where: { $0.point == newHead && $0.index == state.letterProgress }) {
            state.letterDots.remove(at: dotIndex)
            state.letterProgress += 1
            state.growing += 1

            if let word = state.currentWord, state.letterProgress >= word.word.count {
                state.wordsCompleted += 1
                state.score += word.word.count * 10
                state.completedWords.append(word)
                loadNextWord(&state)
                return .completedWord(word)
            }
            return .ateLetter
        }
        return .moved
    }
}
