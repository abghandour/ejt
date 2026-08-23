import SwiftUI

/// Snakesky container: builds the session model and switches phases.
struct SnakeskyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var game: SnakeskyModel?

    var body: some View {
        ZStack {
            ThemedBackground()
            if let game {
                SnakeskyPhaseView()
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
        let session = SnakeskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            dictionaryStore: model.dictionaryStore
        ) { [weak model] result in
            model?.finishedSnakesky(result)
        }
        game = session
        await session.load()
        if ProcessInfo.processInfo.arguments.contains("-autostart-round") {
            session.startRound()
        }
    }
}

struct SnakeskyPhaseView: View {
    @Environment(SnakeskyModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch game.phase {
        case .loading:
            ProgressView()
        case .start:
            SnakeskyStartView()
                .transition(.opacity)
        case .playing:
            SnakeskyPlayView()
                .transition(.opacity)
        case .finished:
            SnakeskyEndView()
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
struct SnakeskyStartView: View {
    @Environment(SnakeskyModel.self) private var game
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

            Image(systemName: GameID.snakesky.symbol)
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accentGlow, radius: 16)
                .accessibilityHidden(true)

            Text("SNAKESKY")
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .kerning(4)
                .foregroundStyle(theme.textPrimary)

            Text("Guide the snake to eat \(game.language.displayName) letters in order. Don't hit the walls or yourself.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding * 2)

            GlassEffectContainer {
                HStack(spacing: 6) {
                    ForEach(SnakeskyDifficulty.allCases) { difficulty in
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
