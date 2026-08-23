import SwiftUI

/// Scramblisky container: builds the session model and switches phases.
struct ScramblisyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var game: ScramblisyModel?

    var body: some View {
        ZStack {
            ThemedBackground()
            if let game {
                ScramblisyPhaseView()
                    .environment(game)
            } else {
                ProgressView()
            }
        }
        .task(createSessionIfNeeded)
        .onChange(of: scenePhase) {
            game?.setPaused(scenePhase != .active)
        }
        .sensoryFeedback(.selection, trigger: game?.selectionTick ?? 0) { _, _ in
            model.settings.hapticsEnabled
        }
        .sensoryFeedback(.success, trigger: game?.successTick ?? 0) { _, _ in
            model.settings.hapticsEnabled
        }
        .sensoryFeedback(.error, trigger: game?.errorTick ?? 0) { _, _ in
            model.settings.hapticsEnabled
        }
    }

    private func createSessionIfNeeded() async {
        guard game == nil else { return }
        let session = ScramblisyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            dictionaryStore: model.dictionaryStore
        ) { [weak model] result in
            model?.finishedScramblisky(result)
        }
        game = session
        await session.load()
        if ProcessInfo.processInfo.arguments.contains("-autostart-round") {
            session.startRound()
        }
    }
}

struct ScramblisyPhaseView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(ScramblisyModel.self) private var game

    var body: some View {
        switch game.phase {
        case .loading:
            ProgressView()
        case .start:
            ScramblisyStartView()
                .transition(.opacity)
        case .playing:
            ScramblisyPlayView()
                .transition(.opacity)
        case .finished:
            ScramblisyEndView()
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
        case .failed(let message):
            ContentUnavailableView {
                Label("Couldn't load dictionary", systemImage: "book.closed")
            } description: {
                Text(message)
            } actions: {
                Button("Back", action: { dismiss() })
                    .buttonStyle(.glass)
            }
        }
    }
}
