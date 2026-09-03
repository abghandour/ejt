import SwiftUI

/// Slashsky container: builds the session model and switches phases.
struct SlashskyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var game: SlashskyModel?

    var body: some View {
        ZStack {
            ThemedBackground()
            if let game {
                SlashskyPhaseView()
                    .environment(game)
            } else {
                ProgressView()
            }
        }
        .task(createSessionIfNeeded)
        .onChange(of: scenePhase) {
            game?.setPaused(scenePhase != .active)
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
        let session = SlashskyModel(
            language: model.language,
            soundEngine: model.soundEngine,
            store: model.slashskyStore
        ) { [weak model] result in
            model?.finishedSlashsky(result)
        }
        game = session
        await session.load()
        if ProcessInfo.processInfo.arguments.contains("-autostart-round") {
            session.startRound()
        }
        // Screenshot/demo hook: periodically sweep a synthetic slash through
        // the lower band where words fly.
        if ProcessInfo.processInfo.arguments.contains("-demo-slash") {
            Task { [weak session] in
                var sweep = 0
                while let session, case .playing = session.phase {
                    try? await Task.sleep(for: .milliseconds(900))
                    let size = session.areaSize
                    guard size.width > 0 else { continue }
                    sweep += 1
                    let bandY = sweep.isMultiple(of: 2) ? 0.62 : 0.8
                    session.swipeBegan(at: CGPoint(x: size.width * 0.03, y: size.height * (bandY + 0.06)))
                    for step in 1...14 {
                        let t = Double(step) / 14
                        session.swipeMoved(to: CGPoint(
                            x: size.width * (0.03 + 0.94 * t),
                            y: size.height * (bandY + 0.06 - 0.12 * t)
                        ))
                        try? await Task.sleep(for: .milliseconds(16))
                    }
                    session.swipeEnded()
                }
            }
        }
    }
}

struct SlashskyPhaseView: View {
    @Environment(SlashskyModel.self) private var game
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        switch game.phase {
        case .loading:
            ProgressView()
        case .start:
            SlashskyStartView()
                .transition(.opacity)
        case .playing:
            SlashskyPlayView()
                .transition(.opacity)
        case .finished:
            SlashskyEndView()
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

/// Pre-round screen.
struct SlashskyStartView: View {
    @Environment(SlashskyModel.self) private var game
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

            GameIconView(game: .slashsky, size: 56)
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accentGlow, radius: 16)
                .accessibilityHidden(true)

            Text("SLASHSKY")
                .heading(.largeTitle, kerning: 4)
                .foregroundStyle(theme.textPrimary)

            Text("Slash the synonyms of the main word. Avoid the distractors — they cost a life. Catch +5s, dodge −5s.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding * 2)

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
