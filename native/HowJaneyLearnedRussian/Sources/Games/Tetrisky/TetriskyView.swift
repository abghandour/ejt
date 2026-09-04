import SwiftUI

/// Tetrisky container: builds the session model and switches phases.
struct TetriskyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var game: TetriskyModel?

    var body: some View {
        ZStack {
            GameStageBackground(game: .tetrisky)
            if let game {
                TetriskyPhaseView()
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
        let session = TetriskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            dictionaryStore: model.dictionaryStore
        ) { [weak model] result in
            model?.finishedTetrisky(result)
        }
        game = session
        await session.load()
        if ProcessInfo.processInfo.arguments.contains("-autostart-round") {
            session.startRound()
        }
    }
}

struct TetriskyPhaseView: View {
    @Environment(TetriskyModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch game.phase {
        case .loading:
            ProgressView()
        case .start:
            TetriskyStartView()
                .transition(.opacity)
        case .playing:
            TetriskyPlayView()
                .transition(.opacity)
        case .finished:
            TetriskyEndView()
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

/// Pre-round screen: title, rules, difficulty picker, play button.
struct TetriskyStartView: View {
    @Environment(TetriskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var game = game
        VStack(spacing: Design.spacing * 2) {
            HStack {
                Button("Close", systemImage: "xmark", action: { dismiss() })
                    .labelStyle(.iconOnly)
                    .padding(10)
                    .glassEffect(.regular.interactive())
                Spacer()
            }
            .padding(.horizontal, Design.padding)

            Spacer()

            Image(systemName: GameID.tetrisky.symbol)
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accentGlow, radius: 16)
                .accessibilityHidden(true)

            Text("TETRISKY")
                .heading(.largeTitle, kerning: 4)
                .foregroundStyle(theme.textPrimary)

            Text("Steer falling letters to spell \(game.language.displayName) words across or down. Clear the target word for a bonus.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding * 2)

            GlassEffectContainer {
                HStack(spacing: 6) {
                    ForEach(TetriskyDifficulty.allCases) { difficulty in
                        GlassSegmentButton(
                            title: difficulty.displayName,
                            symbol: difficulty.symbol,
                            isSelected: game.difficulty == difficulty
                        ) {
                            game.difficulty = difficulty
                        }
                    }
                }
            }

            Button(action: play) {
                Label("Play", systemImage: "play.fill")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal, Design.padding * 2.5)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)

            Spacer()
            Spacer()
        }
    }

    private func play() {
        game.startRound()
    }
}
