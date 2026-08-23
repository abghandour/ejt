import Foundation
import Observation

/// One Slashsky session: ~60fps physics loop, launching, swipe slashing,
/// and round lifecycle over the pure engine.
@Observable
final class SlashskyModel {
    enum Phase {
        case loading
        case start
        case playing
        case finished
        case failed(String)
    }

    /// Half of a cut word flying apart: same capsule, clipped along the slash
    /// line, spinning away with inherited momentum.
    struct WordFragment: Identifiable, Sendable {
        nonisolated static let lifetime = 0.8

        let id: Int
        let text: String
        let type: SlashskyEngine.WordType
        var x: Double
        var y: Double
        var vx: Double
        var vy: Double
        var rotation = 0.0
        let spin: Double
        /// Slash direction in radians; the cut runs through the word center.
        let cutAngle: Double
        /// Which side of the cut this fragment keeps.
        let keepPositiveSide: Bool
        var age = 0.0
    }

    /// Floating feedback text ("+10", "−1 ♥", "+5s"…).
    struct SlashPopup: Identifiable, Sendable {
        nonisolated static let lifetime = 0.9

        enum Kind: Sendable {
            case good, bad, bonus
        }

        let id: Int
        let text: String
        let kind: Kind
        let x: Double
        let y: Double
        var age = 0.0
    }

    /// Spark burst at the point of impact.
    struct SlashBurst: Identifiable, Sendable {
        nonisolated static let lifetime = 0.6

        let id: Int
        let x: Double
        let y: Double
        let isGood: Bool
        var age = 0.0
    }

    let language: Language

    private let soundEngine: SoundEngine
    private let store: SlashskyStore
    private let onFinish: (SlashskyResult) -> Void

    private(set) var phase: Phase = .loading
    private(set) var state: SlashskyEngine.State?
    private(set) var flyingWords: [SlashskyEngine.FlyingWord] = []
    /// Recent swipe points for the gold trail (play-area coordinates).
    private(set) var trailPoints: [CGPoint] = []
    private(set) var isPaused = false
    /// Play-area size reported by the view.
    var areaSize: CGSize = .zero

    private(set) var selectionTick = 0
    private(set) var successTick = 0
    private(set) var errorTick = 0
    /// Red flash on a distractor hit.
    private(set) var distractorFlash = 0
    /// Screen shake on a distractor hit.
    private(set) var shakeTrigger = 0
    /// Cut halves flying apart.
    private(set) var fragments: [WordFragment] = []
    /// Floating score popups.
    private(set) var popups: [SlashPopup] = []
    /// Impact spark bursts.
    private(set) var bursts: [SlashBurst] = []

    @ObservationIgnored private var dictionary: SlashskyEngine.Dictionary?
    @ObservationIgnored private var loopTask: Task<Void, Never>?
    @ObservationIgnored private var lastLaunch = 0.0
    @ObservationIgnored private var lastStep: Date = .now
    @ObservationIgnored private var nextWordID = 0
    @ObservationIgnored private var completedMainWords: [SlashskyEngine.MainWord] = []

    init(
        language: Language,
        soundEngine: SoundEngine,
        store: SlashskyStore,
        onFinish: @escaping (SlashskyResult) -> Void
    ) {
        self.language = language
        self.soundEngine = soundEngine
        self.store = store
        self.onFinish = onFinish
    }

    func load() async {
        do {
            dictionary = try await store.dictionary(for: language)
            phase = .start
        } catch {
            phase = .failed(error.localizedDescription)
        }
    }

    func startRound() {
        guard let dictionary else { return }
        state = SlashskyEngine.makeState(dictionary: dictionary, seed: Int.random(in: Int.min...Int.max))
        flyingWords = []
        completedMainWords = []
        trailPoints = []
        fragments = []
        popups = []
        bursts = []
        lastLaunch = 0
        lastStep = .now
        phase = .playing
        startLoop()
    }

    func backToStart() {
        stopLoop()
        phase = .start
    }

    func setPaused(_ paused: Bool) {
        guard case .playing = phase else { return }
        isPaused = paused
        lastStep = .now
    }

    /// Hit rectangle for a flying word, sized from its text (positions are
    /// the word's center in play-area coordinates).
    nonisolated static func hitRect(for word: SlashskyEngine.FlyingWord) -> CGRect {
        let width = Double(word.text.count) * 14 + 28
        return CGRect(x: word.x - width / 2, y: word.y - 22, width: width, height: 44)
    }

    // MARK: - Physics loop (~60fps)

    private func startLoop() {
        stopLoop()
        loopTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(16))
                guard !Task.isCancelled else { return }
                self?.step()
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }

    private func step() {
        guard case .playing = phase, !isPaused, var state, let dictionary,
              areaSize.width > 0, areaSize.height > 0
        else {
            lastStep = .now
            return
        }

        let now = Date.now
        let dt = min(now.timeIntervalSince(lastStep), 0.1)
        lastStep = now

        state.elapsedTime += dt
        state.timeRemaining = max(0, state.timeRemaining - dt)
        if state.timeRemaining <= 0 {
            self.state = state
            gameOver()
            return
        }

        let difficulty = SlashskyEngine.computeDifficulty(elapsedSeconds: state.elapsedTime)

        // Launch on the ramping interval, capped by simultaneity.
        if state.elapsedTime - lastLaunch >= difficulty.launchInterval,
           flyingWords.count < difficulty.maxSimultaneous {
            let pick = SlashskyEngine.selectNextWord(state: &state, dictionary: dictionary, difficulty: difficulty)
            nextWordID += 1
            let word = SlashskyEngine.createFlyingWord(
                id: nextWordID,
                text: pick.text,
                translation: pick.translation,
                type: pick.type,
                areaWidth: areaSize.width,
                areaHeight: areaSize.height,
                rng: &state.rng
            )
            flyingWords.append(word)
            lastLaunch = state.elapsedTime
        }

        // Advance physics; drop words that fell off-screen.
        var alive: [SlashskyEngine.FlyingWord] = []
        for var word in flyingWords {
            if SlashskyEngine.updatePosition(&word, dt: dt, areaHeight: areaSize.height) {
                alive.append(word)
            }
        }
        flyingWords = alive
        self.state = state

        // Age the ephemera: fragments tumble, popups float, bursts sparkle.
        for index in fragments.indices {
            fragments[index].age += dt
            fragments[index].vy += 900 * dt
            fragments[index].x += fragments[index].vx * dt
            fragments[index].y += fragments[index].vy * dt
            fragments[index].rotation += fragments[index].spin * dt
        }
        fragments.removeAll { $0.age >= WordFragment.lifetime }
        for index in popups.indices {
            popups[index].age += dt
        }
        popups.removeAll { $0.age >= SlashPopup.lifetime }
        for index in bursts.indices {
            bursts[index].age += dt
        }
        bursts.removeAll { $0.age >= SlashBurst.lifetime }

        // Fade the swipe trail.
        if !trailPoints.isEmpty, trailPoints.count > 24 {
            trailPoints.removeFirst(trailPoints.count - 24)
        }
    }

    // MARK: - Slashing

    func swipeBegan(at point: CGPoint) {
        trailPoints = [point]
        soundEngine.play(.slash)
    }

    func swipeMoved(to point: CGPoint) {
        guard case .playing = phase, !isPaused else { return }
        guard let last = trailPoints.last else {
            trailPoints = [point]
            return
        }
        trailPoints.append(point)

        // Only slash once the finger has actually travelled a little (20px web rule).
        let travelled = zip(trailPoints, trailPoints.dropFirst())
            .reduce(0.0) { $0 + hypot($1.1.x - $1.0.x, $1.1.y - $1.0.y) }
        guard travelled >= 20 else { return }

        for word in flyingWords where !word.slashed {
            if SlashskyEngine.segmentIntersectsRect(from: last, to: point, rect: Self.hitRect(for: word)) {
                slash(word, from: last, to: point)
            }
        }
    }

    func swipeEnded() {
        Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            self?.trailPoints = []
        }
    }

    private func slash(_ word: SlashskyEngine.FlyingWord, from p1: CGPoint, to p2: CGPoint) {
        guard var state, let dictionary else { return }
        SlashskyEngine.processSlash(&state, type: word.type, synonymWord: word.text)

        // The blade cuts through the word center along the swipe direction.
        let cutAngle = atan2(p2.y - p1.y, p2.x - p1.x)
        spawnFragments(for: word, cutAngle: cutAngle)
        nextWordID += 1
        bursts.append(
            SlashBurst(id: nextWordID, x: word.x, y: word.y, isGood: word.type == .synonym || word.type == .powerup)
        )

        var rotatedMainWord = false
        switch word.type {
        case .synonym:
            soundEngine.play(.newWord)
            successTick += 1
            if SlashskyEngine.allSynonymsCollected(state) {
                completedMainWords.append(state.currentMainWord)
                SlashskyEngine.rotateMainWord(&state, dictionary: dictionary)
                soundEngine.play(.correct)
                rotatedMainWord = true
            }
        case .distractor:
            soundEngine.play(.wrong)
            errorTick += 1
            distractorFlash += 1
            shakeTrigger += 1
        case .powerup:
            soundEngine.play(.boardClear)
            successTick += 1
        case .bomb:
            soundEngine.play(.penalty)
            errorTick += 1
            shakeTrigger += 1
        }

        // Floating feedback at the impact point.
        nextWordID += 1
        let popup: SlashPopup = switch word.type {
        case .synonym where rotatedMainWord:
            SlashPopup(id: nextWordID, text: "+35 ★", kind: .bonus, x: word.x, y: word.y - 30)
        case .synonym:
            SlashPopup(id: nextWordID, text: "+10", kind: .good, x: word.x, y: word.y - 30)
        case .distractor:
            SlashPopup(id: nextWordID, text: "−1 ♥", kind: .bad, x: word.x, y: word.y - 30)
        case .powerup:
            SlashPopup(id: nextWordID, text: "+5s", kind: .good, x: word.x, y: word.y - 30)
        case .bomb:
            SlashPopup(id: nextWordID, text: "−5s", kind: .bad, x: word.x, y: word.y - 30)
        }
        popups.append(popup)

        flyingWords.removeAll { $0.id == word.id }
        self.state = state

        if state.isGameOver {
            gameOver()
        }
    }

    /// Splits a slashed word into two halves that fly apart perpendicular to
    /// the cut, inheriting a share of the word's momentum plus spin.
    private func spawnFragments(for word: SlashskyEngine.FlyingWord, cutAngle: Double) {
        let normal = (x: -sin(cutAngle), y: cos(cutAngle))
        let separation = 150.0
        for keepPositive in [true, false] {
            nextWordID += 1
            let direction = keepPositive ? 1.0 : -1.0
            fragments.append(
                WordFragment(
                    id: nextWordID,
                    text: word.text,
                    type: word.type,
                    x: word.x,
                    y: word.y,
                    vx: word.vx * 0.4 + normal.x * separation * direction,
                    vy: word.vy * 0.25 + normal.y * separation * direction - 70,
                    spin: direction * Double.random(in: 2.5...4.5),
                    cutAngle: cutAngle,
                    keepPositiveSide: keepPositive
                )
            )
        }
    }

    private func gameOver() {
        stopLoop()
        phase = .finished
        flyingWords = []
        fragments = []
        popups = []
        bursts = []
        soundEngine.play(.gameEnd)
        guard let state else { return }
        onFinish(
            SlashskyResult(
                languageID: language.id,
                score: state.score,
                wordsCompleted: state.wordsCompleted,
                totalSynonymsSlashed: state.totalSynonymsSlashed,
                words: completedMainWords.map {
                    FoundWord(word: $0.word, translation: $0.translation, points: 25)
                }
            )
        )
    }

    var timeText: String {
        let t = Int((state?.timeRemaining ?? 0).rounded(.up))
        return "\(t / 60):\(String(format: "%02d", t % 60))"
    }
}
