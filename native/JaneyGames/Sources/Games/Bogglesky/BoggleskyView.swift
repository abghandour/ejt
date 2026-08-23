import SwiftUI

/// Bogglesky container: builds the session model and switches between
/// start / playing / finished phases.
struct BoggleskyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var game: BoggleskyModel?

    var body: some View {
        ZStack {
            ThemedBackground()
            if let game {
                BoggleskyPhaseView(game: game)
                    .environment(game)
                    .overlay {
                        ConfettiView(trigger: game.confettiTrigger)
                    }
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
        let session = BoggleskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            dictionaryStore: model.dictionaryStore,
            speech: model.speech
        ) { [weak model] result in
            model?.finishedBogglesky(result)
        }
        game = session
        await session.load()
        if ProcessInfo.processInfo.arguments.contains("-autostart-round") {
            await session.startRound()
        }
    }
}

/// Switches the visible screen for the current phase.
struct BoggleskyPhaseView: View {
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Bindable var game: BoggleskyModel

    var body: some View {
        switch game.phase {
        case .loading:
            ProgressView()
        case .start:
            BoggleskyStartView()
                .transition(.opacity)
        case .playing:
            BoggleskyPlayView()
                .transition(.opacity)
        case .finished:
            BoggleskyEndView()
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
