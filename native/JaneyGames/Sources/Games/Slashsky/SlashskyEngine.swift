import CoreGraphics
import Foundation

/// Pure Slashsky logic, ported 1:1 from web/mobile/slashsky-engine.js:
/// synonym slashing with parabolic word physics, a 60-second ramp of
/// difficulty, and Liang-Barsky swipe intersection.
nonisolated enum SlashskyEngine {
    // MARK: Dictionary

    struct Synonym: Hashable, Sendable, Decodable {
        let word: String
        let translation: String
    }

    struct MainWord: Hashable, Sendable, Decodable {
        let word: String
        let translation: String
        let synonyms: [Synonym]

        /// ≥3 non-empty synonyms, non-empty word/translation.
        var isValid: Bool {
            guard !word.trimmingCharacters(in: .whitespaces).isEmpty,
                  !translation.trimmingCharacters(in: .whitespaces).isEmpty,
                  synonyms.count >= 3
            else { return false }
            return synonyms.allSatisfy {
                !$0.word.trimmingCharacters(in: .whitespaces).isEmpty
                    && !$0.translation.trimmingCharacters(in: .whitespaces).isEmpty
            }
        }
    }

    struct Dictionary: Sendable, Decodable {
        let words: [MainWord]
        let distractors: [Synonym]
    }

    // MARK: Game state

    struct State: Sendable {
        var score = 0
        var lives = 3
        var timeRemaining = 60.0
        var elapsedTime = 0.0
        var currentMainWord: MainWord
        var collectedSynonyms: Set<String> = []
        var wordsCompleted = 0
        var totalSynonymsSlashed = 0
        var isGameOver = false
        var rng: SeedEngine
    }

    static func makeState(dictionary: Dictionary, seed: Int) -> State {
        var rng = SeedEngine(seed: seed)
        let index = rng.nextInt(dictionary.words.count)
        return State(currentMainWord: dictionary.words[index], rng: rng)
    }

    enum WordType: Sendable {
        case synonym, distractor, powerup, bomb
    }

    /// Slash scoring, ported: synonym +10, distractor −1 life, ±5s for powerup/bomb.
    static func processSlash(_ state: inout State, type: WordType, synonymWord: String?) {
        switch type {
        case .synonym:
            state.score += 10
            state.totalSynonymsSlashed += 1
            if let synonymWord {
                state.collectedSynonyms.insert(synonymWord)
            }
        case .distractor:
            state.lives -= 1
            if state.lives <= 0 {
                state.lives = 0
                state.isGameOver = true
            }
        case .powerup:
            state.timeRemaining += 5
        case .bomb:
            state.timeRemaining = max(0, state.timeRemaining - 5)
        }
    }

    static func allSynonymsCollected(_ state: State) -> Bool {
        state.collectedSynonyms.count == state.currentMainWord.synonyms.count
    }

    /// New main word (+25 bonus), avoiding a repeat when possible.
    static func rotateMainWord(_ state: inout State, dictionary: Dictionary) {
        state.score += 25
        state.wordsCompleted += 1
        state.collectedSynonyms = []
        if dictionary.words.count > 1 {
            var next = state.currentMainWord
            while next.word == state.currentMainWord.word {
                next = dictionary.words[state.rng.nextInt(dictionary.words.count)]
            }
            state.currentMainWord = next
        }
    }

    // MARK: Difficulty ramp (linear over 60s)

    struct Difficulty: Sendable {
        let launchSpeed: Double
        let launchInterval: Double
        let distractorRatio: Double
        let maxSimultaneous: Int
    }

    static func computeDifficulty(elapsedSeconds: Double) -> Difficulty {
        let t = min(max(elapsedSeconds / 60, 0), 1)
        return Difficulty(
            launchSpeed: 1.0 + t,
            launchInterval: (1500 - t * 900) / 1000,
            distractorRatio: 0.3 + t * 0.4,
            maxSimultaneous: Int((3 + t * 2).rounded())
        )
    }

    // MARK: Flying words

    struct FlyingWord: Identifiable, Sendable {
        let id: Int
        let text: String
        let translation: String
        let type: WordType
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        let gravity: Double
        var slashed = false
    }

    /// Launch parameters ported: bottom entry, upward arc with jitter, gravity
    /// proportional to the play-area height.
    static func createFlyingWord(
        id: Int,
        text: String,
        translation: String,
        type: WordType,
        areaWidth: Double,
        areaHeight: Double,
        rng: inout SeedEngine
    ) -> FlyingWord {
        let margin = areaWidth * 0.1
        let x = margin + rng.next() * (areaWidth - 2 * margin)
        let y = areaHeight + rng.next() * 20
        let baseVy = -(areaHeight * 0.8)
        let vy = baseVy + (rng.next() - 0.5) * (areaHeight * 0.3)
        let vx = (rng.next() - 0.5) * (areaWidth * 0.3)
        return FlyingWord(
            id: id, text: text, translation: translation, type: type,
            x: x, y: y, vx: vx, vy: vy, gravity: areaHeight * 0.8
        )
    }

    /// Parabolic step. Returns false once the word has fallen off the bottom.
    static func updatePosition(_ word: inout FlyingWord, dt: Double, areaHeight: Double) -> Bool {
        word.vy += word.gravity * dt
        word.x += word.vx * dt
        word.y += word.vy * dt
        return !(word.y > areaHeight && word.vy > 0)
    }

    /// Next launch: ~10% powerup, ~8% bomb, otherwise synonym vs distractor by ratio.
    static func selectNextWord(
        state: inout State,
        dictionary: Dictionary,
        difficulty: Difficulty
    ) -> (text: String, translation: String, type: WordType) {
        let roll = state.rng.next()
        if roll < 0.10 {
            return ("+5s", "+5s", .powerup)
        }
        if roll < 0.18 {
            return ("-5s", "-5s", .bomb)
        }

        let unslashed = state.currentMainWord.synonyms.filter {
            !state.collectedSynonyms.contains($0.word)
        }
        let pickDistractor = state.rng.next() < difficulty.distractorRatio || unslashed.isEmpty

        if pickDistractor {
            let d = dictionary.distractors[state.rng.nextInt(dictionary.distractors.count)]
            return (d.word, d.translation, .distractor)
        }
        let synonym = unslashed[state.rng.nextInt(unslashed.count)]
        return (synonym.word, synonym.translation, .synonym)
    }

    /// Liang-Barsky segment-vs-AABB intersection, ported exactly.
    static func segmentIntersectsRect(
        from p1: CGPoint,
        to p2: CGPoint,
        rect: CGRect
    ) -> Bool {
        let dx = p2.x - p1.x
        let dy = p2.y - p1.y
        let p = [-dx, dx, -dy, dy]
        let q = [p1.x - rect.minX, rect.maxX - p1.x, p1.y - rect.minY, rect.maxY - p1.y]

        var tMin = 0.0
        var tMax = 1.0
        for i in 0..<4 {
            if p[i] == 0 {
                if q[i] < 0 { return false }
            } else {
                let t = q[i] / p[i]
                if p[i] < 0 {
                    tMin = max(tMin, t)
                } else {
                    tMax = min(tMax, t)
                }
                if tMin > tMax { return false }
            }
        }
        return true
    }
}
