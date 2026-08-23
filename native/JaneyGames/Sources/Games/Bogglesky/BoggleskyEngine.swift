import Foundation

/// Pure game logic for Bogglesky: board generation, adjacency, trie word
/// search, and path validation. No UI, fully testable. Ported from the JS
/// implementation in web/mobile/bogglesky.html.
nonisolated enum BoggleskyEngine {
    static let minFindableWords = 5
    static let shufflePenaltySeconds = 20
    static let hintPenaltySeconds = 10

    struct Board: Sendable {
        let gridSize: Int
        let letters: [Character]
        let findableWords: Set<String>
    }

    /// Prefix tree over the dictionary for fast DFS pruning.
    final class Trie: Sendable {
        // Children keyed by letter; a completed word is stored at its terminal node.
        let children: [Character: Trie]
        let word: String?

        private init(children: [Character: Trie], word: String?) {
            self.children = children
            self.word = word
        }

        /// Builds the trie once per (dictionary, board size); reused across boards.
        static func build(words: [String], minLength: Int, maxLength: Int) -> Trie {
            final class Node {
                var children: [Character: Node] = [:]
                var word: String?
            }
            let root = Node()
            for word in words {
                let count = word.count
                guard count >= minLength, count <= maxLength else { continue }
                var node = root
                for ch in word {
                    if let next = node.children[ch] {
                        node = next
                    } else {
                        let next = Node()
                        node.children[ch] = next
                        node = next
                    }
                }
                node.word = word
            }
            func freeze(_ node: Node) -> Trie {
                Trie(children: node.children.mapValues(freeze), word: node.word)
            }
            return freeze(root)
        }
    }

    /// Indices of the up-to-8 cells surrounding `index` in a size×size grid.
    static func neighbors(of index: Int, size: Int) -> [Int] {
        let r = index / size
        let c = index % size
        var result: [Int] = []
        for dr in -1...1 {
            for dc in -1...1 where !(dr == 0 && dc == 0) {
                let nr = r + dr
                let nc = c + dc
                if nr >= 0, nr < size, nc >= 0, nc < size {
                    result.append(nr * size + nc)
                }
            }
        }
        return result
    }

    /// Every dictionary word reachable on this board by a non-repeating adjacent path.
    static func findAllWords(letters: [Character], size: Int, trie: Trie) -> Set<String> {
        var found: Set<String> = []
        let adjacency = (0..<letters.count).map { neighbors(of: $0, size: size) }

        func dfs(_ index: Int, _ visited: inout UInt32, _ node: Trie) {
            guard let next = node.children[letters[index]] else { return }
            if let word = next.word {
                found.insert(word)
            }
            visited |= 1 << index
            for neighbor in adjacency[index] where visited & (1 << neighbor) == 0 {
                dfs(neighbor, &visited, next)
            }
            visited &= ~(1 << index)
        }

        for start in 0..<letters.count {
            var visited: UInt32 = 0
            dfs(start, &visited, trie)
        }
        return found
    }

    static func randomLetters(count: Int, pool: [Character], rng: inout SeedEngine) -> [Character] {
        (0..<count).map { _ in pool[rng.nextInt(pool.count)] }
    }

    /// Generates boards until one has ≥ `minFindableWords`, best-effort within
    /// `maxAttempts` (the web version loops unbounded; small dictionaries would hang).
    static func generateBoard(
        size: Int,
        pool: [Character],
        trie: Trie,
        rng: inout SeedEngine,
        maxAttempts: Int = 400
    ) -> Board {
        let cellCount = size * size
        var best: Board?
        for _ in 0..<maxAttempts {
            let letters = randomLetters(count: cellCount, pool: pool, rng: &rng)
            let findable = findAllWords(letters: letters, size: size, trie: trie)
            let board = Board(gridSize: size, letters: letters, findableWords: findable)
            if findable.count >= minFindableWords {
                return board
            }
            if findable.count > (best?.findableWords.count ?? -1) {
                best = board
            }
        }
        return best ?? Board(gridSize: size, letters: [], findableWords: [])
    }

    /// Reshuffles existing letters (shuffle action); falls back to a fresh board
    /// if no arrangement yields enough words, mirroring the web behavior.
    static func shuffledBoard(
        letters: [Character],
        size: Int,
        pool: [Character],
        trie: Trie,
        rng: inout SeedEngine
    ) -> Board {
        for _ in 0..<50 {
            let shuffled = rng.shuffle(letters)
            let findable = findAllWords(letters: shuffled, size: size, trie: trie)
            if findable.count >= minFindableWords {
                return Board(gridSize: size, letters: shuffled, findableWords: findable)
            }
        }
        return generateBoard(size: size, pool: pool, trie: trie, rng: &rng)
    }

    static func word(fromPath path: [Int], letters: [Character]) -> String {
        String(path.map { letters[$0] })
    }

    /// A path is valid when every step is adjacent and no cell repeats.
    static func isValidPath(_ path: [Int], size: Int) -> Bool {
        guard path.count >= 2 else { return false }
        for i in 1..<path.count where !neighbors(of: path[i - 1], size: size).contains(path[i]) {
            return false
        }
        return Set(path).count == path.count
    }
}
