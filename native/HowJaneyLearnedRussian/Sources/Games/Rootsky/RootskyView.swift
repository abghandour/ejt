import SwiftUI

/// Rootsky container: builds the session model, switches phases, hosts the
/// calendar/results sheets.
struct RootskyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    /// `.rootsky` or `.wordsky` — same machinery, different data.
    var gameID: GameID = .rootsky
    @State private var game: RootskyModel?

    var body: some View {
        ZStack {
            ThemedBackground()
            if let game {
                RootskyPhaseView()
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
        let session = RootskyModel(
            game: gameID,
            language: model.language,
            soundEngine: model.soundEngine,
            rootskyStore: gameID == .wordsky ? model.wordskyStore : model.rootskyStore,
            dailyState: model.dailyState,
            speech: model.speech
        ) { [weak model] result in
            model?.finishedDailyWordGame(result)
        }
        game = session
        await session.load()
        if ProcessInfo.processInfo.arguments.contains("-autostart-round") {
            session.start()
        }
    }
}

struct RootskyPhaseView: View {
    @Environment(RootskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var game = game
        Group {
            switch game.phase {
            case .loading:
                ProgressView()
            case .noGame:
                RootskyNoGameView()
            case .start(let canResume):
                RootskyStartView(canResume: canResume)
                    .transition(.opacity)
            case .playing, .review:
                RootskyPlayView()
                    .transition(.opacity)
            case .failed(let message):
                ContentUnavailableView {
                    Label("Couldn't load Rootsky", systemImage: "book.closed")
                } description: {
                    Text(message)
                } actions: {
                    Button("Back", action: { dismiss() })
                        .buttonStyle(.glass)
                }
            }
        }
        .sheet(isPresented: $game.isShowingCalendar) {
            GameCalendarView(
                availableDateKeys: game.availableDateKeys,
                playedDateKeys: game.playedDateKeys,
                partialDateKeys: game.inProgressDateKeys,
                selectedDateKey: game.dateKey,
                disableFuture: true
            ) { key in
                game.selectDate(key)
            }
        }
        .sheet(isPresented: $game.isShowingResults) {
            RootskyEndView()
                .environment(game)
        }
    }
}

/// Shown when the selected date has no Rootsky content.
struct RootskyNoGameView: View {
    @Environment(RootskyModel.self) private var game
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
            Image(systemName: game.game.symbol)
                .font(.system(size: 52))
                .foregroundStyle(theme.accent)
                .accessibilityHidden(true)
            Text("No Game Today")
                .heading(.title)
                .foregroundStyle(theme.textPrimary)
            Text("There's no puzzle for \(game.friendlyDate). Pick another day from the calendar.")
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
