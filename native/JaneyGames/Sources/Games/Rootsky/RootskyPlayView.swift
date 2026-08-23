import SwiftUI

/// The in-round (and review) screen: top bar, tracker, root medallion, the
/// word of the day, and the 2×3 answer grid. The medallion intro overlays
/// everything on a day's very first start.
struct RootskyPlayView: View {
    @Environment(RootskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing) {
            RootskyTopBarView()
            RootskyTrackerView()
            Spacer()
            RootskyWordAreaView()
            Spacer()
            RootskyAnswerGridView()
                .padding(.bottom, Design.padding)
        }
        .padding(.vertical, Design.spacing)
        .frame(maxWidth: Design.maxContentWidth)
        .overlay {
            if game.isIntroActive {
                RootMedallionIntroView()
            }
        }
        .animation(Design.bouncy, value: game.isIntroActive)
    }
}

/// Close, score + stopwatch, date/calendar, share (completed), leaderboard.
struct RootskyTopBarView: View {
    @Environment(RootskyModel.self) private var game
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: Design.spacing) {
            Button("Quit", systemImage: "xmark", action: { dismiss() })
                .labelStyle(.iconOnly)
                .padding(8)
                .glassEffect(.regular.interactive())

            Label("\(game.visibleScore)", systemImage: "star.fill")
                .font(.headline)
                .bold()
                .foregroundStyle(theme.accent)
                .contentTransition(.numericText())
                .animation(Design.snappy, value: game.visibleScore)
                .accessibilityLabel("Score \(game.visibleScore)")

            Label(game.elapsedText, systemImage: "stopwatch")
                .font(.subheadline)
                .monospacedDigit()
                .foregroundStyle(theme.info)
                .accessibilityLabel("Time \(game.elapsedText)")

            Spacer()

            Button(action: openCalendar) {
                Label(game.friendlyDate, systemImage: "calendar")
                    .font(.caption)
                    .bold()
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
            }
            .glassEffect(.regular.interactive())

            if game.isCompleted {
                ShareLink(item: game.shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .padding(8)
                }
                .glassEffect(.regular.interactive())
            }

            if model.gameCenter.isAuthenticated {
                Button("Ranks", systemImage: "chart.bar.fill", action: showLeaderboard)
                    .labelStyle(.iconOnly)
                    .padding(8)
                    .glassEffect(.regular.interactive())
            }
        }
        .padding(.horizontal, Design.padding)
    }

    private func openCalendar() {
        game.isShowingCalendar = true
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(game: game.game, languageID: game.language.id, difficulty: nil)
    }
}

/// Root medallion + the big word with TTS, translation, and stars.
struct RootskyWordAreaView: View {
    @Environment(RootskyModel.self) private var game
    @Environment(\.theme) private var theme

    private var showAnswerDetails: Bool {
        if case .review = game.phase { return true }
        return game.wordRevealed
    }

    var body: some View {
        VStack(spacing: Design.spacing) {
            if game.hasRoots {
                RootMedallionView(compact: true)
            }

            HStack(spacing: Design.spacing) {
                Text(game.currentWord?.wordOfTheDay ?? "—")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(theme.textPrimary)
                    .shadow(color: theme.accentGlow, radius: 12)
                if game.hasVoice {
                    Button("Listen", systemImage: "speaker.wave.2.fill", action: speak)
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(theme.info)
                        .padding(8)
                        .glassEffect(.regular.interactive())
                }
            }
            .id(game.wordGeneration)
            .transition(.scale(scale: 0.4).combined(with: .opacity))
            .overlay {
                WordLandingSparksView(trigger: game.wordGeneration)
            }

            if showAnswerDetails, let word = game.currentWord {
                Text(word.translation)
                    .font(.title3)
                    .foregroundStyle(theme.info)
                    .transition(.opacity.combined(with: .offset(y: 8)))
                TriviaStarsView(score: game.state?.wordScores[game.displayedIndex] ?? 0, starSize: 16)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, Design.padding)
        .animation(Design.bouncy, value: game.wordGeneration)
        .animation(Design.snappy, value: showAnswerDetails)
    }

    private func speak() {
        game.speakCurrentWord()
    }
}

/// The gold "Word Root of the day" medallion.
struct RootMedallionView: View {
    @Environment(RootskyModel.self) private var game
    @Environment(\.theme) private var theme
    let compact: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("WORD ROOT OF THE DAY")
                .font(compact ? .caption2 : .caption)
                .bold()
                .kerning(1.5)
                .foregroundStyle(theme.textSecondary)
            Text(game.currentWord?.rootWord ?? "")
                .font(compact ? .title3 : .largeTitle)
                .bold()
                .foregroundStyle(theme.accent)
            if let rootTranslation = game.currentWord?.rootTranslation {
                Text("(\(rootTranslation))")
                    .font(compact ? .caption : .body)
                    .italic()
                    .foregroundStyle(theme.info)
            }
        }
        .padding(.horizontal, Design.padding * 1.5)
        .padding(.vertical, compact ? 8 : Design.padding)
        .background(theme.tileSelectedGradient, in: .capsule)
        .overlay(Capsule().strokeBorder(theme.accent.opacity(0.5), lineWidth: 1.5))
        .shadow(color: theme.accentGlow, radius: 10)
        .accessibilityElement(children: .combine)
    }
}

/// Full-screen medallion intro on a day's first start.
struct RootMedallionIntroView: View {
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            RootMedallionView(compact: false)
                .scaleEffect(1.15)
                .transition(.scale(scale: 0.5).combined(with: .opacity))
        }
        .transition(.opacity)
    }
}

/// Gold sparks when a new word lands.
struct WordLandingSparksView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let trigger: Int
    @State private var start: Date = .now

    var body: some View {
        if reduceMotion || trigger == 0 {
            EmptyView()
        } else {
            ExplosionBurstView(trigger: trigger)
                .id(trigger)
        }
    }
}
