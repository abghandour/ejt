import SwiftUI

/// What a hosted game's session must expose for Meddleysky to drive it:
/// haptic ticks, pause, and a way to notice the player quit mid-level.
protocol MeddleyLevelSession: AnyObject, Observable {
    var selectionTick: Int { get }
    var successTick: Int { get }
    var errorTick: Int { get }
    /// True once the session dropped back to its start screen (Quit pressed).
    var isAtStart: Bool { get }
    /// True when the session couldn't load its content.
    var loadFailed: Bool { get }
    func setPaused(_ paused: Bool)
}

extension BoggleskyModel: MeddleyLevelSession {
    var isAtStart: Bool { if case .start = phase { true } else { false } }
    var loadFailed: Bool { if case .failed = phase { true } else { false } }
}

extension ScramblisyModel: MeddleyLevelSession {
    var isAtStart: Bool { if case .start = phase { true } else { false } }
    var loadFailed: Bool { if case .failed = phase { true } else { false } }
}

extension SnakeskyModel: MeddleyLevelSession {
    var isAtStart: Bool { if case .start = phase { true } else { false } }
    var loadFailed: Bool { if case .failed = phase { true } else { false } }
}

extension TetriskyModel: MeddleyLevelSession {
    var isAtStart: Bool { if case .start = phase { true } else { false } }
    var loadFailed: Bool { if case .failed = phase { true } else { false } }
}

extension SlashskyModel: MeddleyLevelSession {
    var isAtStart: Bool { if case .start = phase { true } else { false } }
    var loadFailed: Bool { if case .failed = phase { true } else { false } }
}

extension RootskyModel: MeddleyLevelSession {
    var isAtStart: Bool { if case .start = phase { true } else { false } }
    var loadFailed: Bool {
        switch phase {
        case .failed, .noGame: true
        default: false
        }
    }
}

extension TriviatskyModel: MeddleyLevelSession {
    var isAtStart: Bool { if case .start = phase { true } else { false } }
    var loadFailed: Bool {
        switch phase {
        case .failed, .noGame: true
        default: false
        }
    }
}

/// One level of a run: builds the right game session for the plan, starts it
/// straight into play (no start screen), and shows that game's play view.
struct MeddleyLevelView: View {
    @Environment(AppModel.self) private var model
    @Environment(MeddleyskyModel.self) private var run
    let plan: MeddleyLevelPlan

    var body: some View {
        switch plan.game {
        case .bogglesky:
            MeddleyLevelHost(make: makeBogglesky) { BoggleskyPlayView() }
        case .scramblisky:
            MeddleyLevelHost(make: makeScramblisky) { ScramblisyPlayView() }
        case .snakesky:
            MeddleyLevelHost(make: makeSnakesky) { SnakeskyPlayView() }
        case .tetrisky:
            MeddleyLevelHost(make: makeTetrisky) { TetriskyPlayView() }
        case .slashsky:
            MeddleyLevelHost(make: makeSlashsky) { SlashskyPlayView() }
        case .rootsky, .wordsky:
            MeddleyLevelHost(make: makeDailyWords) { RootskyPlayView() }
        case .triviatsky:
            MeddleyLevelHost(make: makeTrivia) { TriviaPlayView() }
        case .meddleysky:
            // A run never nests itself; treat it like a missing game.
            Color.clear.task { run.skipLevel() }
        }
    }

    private func finished(rawScore: Int, words: [FoundWord]) {
        run.levelFinished(rawScore: rawScore, words: words)
    }

    private func makeBogglesky() async -> BoggleskyModel {
        let session = BoggleskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            dictionaryStore: model.dictionaryStore,
            speech: model.speech
        ) { [weak run] result in
            run?.levelFinished(rawScore: result.score, words: result.words)
        }
        session.difficulty = BoggleskyDifficulty(rawValue: plan.difficulty?.rawValue ?? "") ?? .medium
        session.timeLimitOverride = MeddleyTuning.boggleskySeconds
        await session.load()
        if !session.loadFailed {
            await session.startRound()
        }
        return session
    }

    private func makeScramblisky() async -> ScramblisyModel {
        let session = ScramblisyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            dictionaryStore: model.dictionaryStore
        ) { [weak run] result in
            run?.levelFinished(rawScore: result.score, words: result.words)
        }
        session.difficulty = ScramblisyDifficulty(rawValue: plan.difficulty?.rawValue ?? "") ?? .medium
        session.timeLimitOverride = MeddleyTuning.scrambliskySeconds
        await session.load()
        if !session.loadFailed {
            session.startRound()
        }
        return session
    }

    private func makeSnakesky() async -> SnakeskyModel {
        let session = SnakeskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            dictionaryStore: model.dictionaryStore
        ) { [weak run] result in
            run?.levelFinished(rawScore: result.score, words: result.words)
        }
        session.difficulty = SnakeskyDifficulty(rawValue: plan.difficulty?.rawValue ?? "") ?? .medium
        await session.load()
        if !session.loadFailed {
            session.startRound()
        }
        return session
    }

    private func makeTetrisky() async -> TetriskyModel {
        let session = TetriskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            dictionaryStore: model.dictionaryStore
        ) { [weak run] result in
            run?.levelFinished(rawScore: result.score, words: result.words)
        }
        session.difficulty = TetriskyDifficulty(rawValue: plan.difficulty?.rawValue ?? "") ?? .medium
        await session.load()
        if !session.loadFailed {
            session.startRound()
        }
        return session
    }

    private func makeSlashsky() async -> SlashskyModel {
        let session = SlashskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            store: model.slashskyStore
        ) { [weak run] result in
            run?.levelFinished(rawScore: result.score, words: result.words)
        }
        session.timeLimitOverride = MeddleyTuning.slashskySeconds
        await session.load()
        if !session.loadFailed {
            session.startRound()
        }
        return session
    }

    private func makeDailyWords() async -> RootskyModel {
        let session = RootskyModel(
            game: plan.game,
            language: model.language,
            soundEngine: model.soundEngine,
            rootskyStore: plan.game == .wordsky ? model.wordskyStore : model.rootskyStore,
            dailyState: model.dailyState,
            speech: model.speech,
            wordCount: MeddleyTuning.rootskyWords,
            isSandboxed: true
        ) { [weak run] result in
            run?.levelFinished(rawScore: result.score, words: result.words)
        }
        session.onQuit = { [weak run] in run?.quitRun() }
        await session.load()
        if !session.loadFailed {
            session.start()
        }
        return session
    }

    private func makeTrivia() async -> TriviatskyModel {
        let session = TriviatskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            triviaStore: model.triviaStore,
            dailyState: model.dailyState,
            questionLimit: MeddleyTuning.triviaQuestions,
            isSandboxed: true
        ) { [weak run] result in
            run?.levelFinished(rawScore: result.score, words: [])
        }
        session.onQuit = { [weak run] in run?.quitRun() }
        await session.load()
        if !session.loadFailed {
            session.start()
        }
        return session
    }
}

/// Generic host: creates the session, injects it for the play view, wires
/// pause/haptics, and reports quits and load failures back to the run.
private struct MeddleyLevelHost<Session: MeddleyLevelSession, Content: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(MeddleyskyModel.self) private var run
    @Environment(\.scenePhase) private var scenePhase
    let make: () async -> Session
    @ViewBuilder let content: () -> Content
    @State private var session: Session?

    var body: some View {
        Group {
            if let session, !session.loadFailed {
                content()
                    .environment(session)
                    .transition(.opacity)
            } else {
                ProgressView()
            }
        }
        .task {
            guard session == nil else { return }
            let built = await make()
            session = built
            if built.loadFailed {
                run.skipLevel()
            }
        }
        .onChange(of: scenePhase) {
            session?.setPaused(scenePhase != .active)
        }
        .onChange(of: session?.isAtStart ?? false) { _, atStart in
            if atStart {
                run.quitRun()
            }
        }
        .sensoryFeedback(.selection, trigger: session?.selectionTick ?? 0) { _, _ in
            model.settings.hapticsEnabled
        }
        .sensoryFeedback(.success, trigger: session?.successTick ?? 0) { _, _ in
            model.settings.hapticsEnabled
        }
        .sensoryFeedback(.error, trigger: session?.errorTick ?? 0) { _, _ in
            model.settings.hapticsEnabled
        }
    }
}
