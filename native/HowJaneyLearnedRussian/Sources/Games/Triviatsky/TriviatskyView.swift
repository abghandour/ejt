import SwiftUI

/// Triviatsky container: builds the session model, switches phases, and hosts
/// the results/calendar sheets and full-screen confetti.
struct TriviatskyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var game: TriviatskyModel?

    var body: some View {
        ZStack {
            GameStageBackground(game: .triviatsky)
            if let game {
                TriviatskyPhaseView()
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
        let session = TriviatskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            triviaStore: model.triviaStore,
            dailyState: model.dailyState
        ) { [weak model] result in
            model?.finishedTriviatsky(result)
        }
        game = session
        await session.load()
        if ProcessInfo.processInfo.arguments.contains("-autostart-round") {
            session.start()
        }
    }
}

/// Switches the visible screen for the current phase.
struct TriviatskyPhaseView: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var game = game
        Group {
            switch game.phase {
            case .loading:
                ProgressView()
            case .noGame:
                TriviaNoGameView()
            case .start(let canResume):
                TriviaStartView(canResume: canResume)
                    .transition(.opacity)
            case .playing, .review:
                TriviaPlayView()
                    .transition(.opacity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't load trivia", systemImage: "book.closed")
                } description: {
                    Text(message)
                } actions: {
                    Button("Back", action: { dismiss() })
                        .buttonStyle(.glass)
                }
            }
        }
        .sheet(isPresented: $game.isShowingCalendar) {
            TriviaCalendarView()
                .environment(game)
        }
        .sheet(isPresented: $game.isShowingResults) {
            TriviaResultsView()
                .environment(game)
        }
    }
}

/// Shown when the selected date has no trivia content.
struct TriviaNoGameView: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
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
            Image(systemName: GameID.triviatsky.symbol)
                .font(.system(size: 52))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text("No Game Today")
                .heading(.title)
                .foregroundStyle(theme.textPrimary)
            Text("There's no trivia for \(game.friendlyDate). Pick another day from the calendar.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding * 2)
            Button("Open Calendar", systemImage: "calendar", action: openCalendar)
                .buttonStyle(.glassProminent)
            Spacer()
            Spacer()
        }
    }

    private func openCalendar() {
        game.isShowingCalendar = true
    }
}
