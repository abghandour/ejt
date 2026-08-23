import SwiftUI

/// The in-round screen: HUD, hint bar, current word, letter grid, shuffle.
struct BoggleskyPlayView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing) {
            BoggleskyHUDView()
            HintBarView()
            CurrentWordView()
            BoggleGridView()
                .frame(maxWidth: Design.maxContentWidth, maxHeight: .infinity)
            ShuffleButtonView()
        }
        .padding(.vertical, Design.spacing)
        .overlay(alignment: .center) {
            if let toast = game.toast {
                ToastView(message: toast)
            }
        }
        .overlay(alignment: .top) {
            if let celebration = game.celebration {
                CelebrationBannerView(celebration: celebration)
                    .padding(.top, 80)
            }
        }
        .overlay {
            if game.isPaused {
                PauseOverlayView()
            }
            if game.isDangerTime, case .playing = game.phase {
                DangerVignetteView()
            }
        }
        .animation(Design.snappy, value: game.toast)
        .animation(Design.bouncy, value: game.celebration)
        .animation(Design.snappy, value: game.isPaused)
    }
}

/// Long-word / combo banner ("Отлично!", "×3!").
struct CelebrationBannerView: View {
    @Environment(\.theme) private var theme
    let celebration: BoggleskyModel.Celebration

    var body: some View {
        HStack(spacing: 8) {
            if let banner = celebration.banner {
                Text(banner)
                    .font(.system(.title2, design: .rounded))
                    .bold()
                    .foregroundStyle(theme.accent)
            }
            if celebration.multiplier > 1 {
                Text("×\(celebration.multiplier)!")
                    .font(.system(.title2, design: .rounded))
                    .bold()
                    .foregroundStyle(theme.danger)
            }
        }
        .padding(.horizontal, Design.padding * 1.5)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(theme.accentGlow), in: .capsule)
        .shadow(color: theme.accentGlow, radius: 12)
        .transition(.scale(scale: 0.5).combined(with: .opacity))
        .allowsHitTesting(false)
        .accessibilityLabel(
            [celebration.banner, celebration.multiplier > 1 ? "combo times \(celebration.multiplier)" : nil]
                .compactMap { $0 }
                .joined(separator: ", ")
        )
    }
}

/// Pulsing red edge glow for the final seconds.
struct DangerVignetteView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulsing = false

    var body: some View {
        Rectangle()
            .strokeBorder(theme.danger.opacity(pulsing ? 0.5 : 0.15), lineWidth: 6)
            .blur(radius: 6)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    pulsing = true
                }
            }
    }
}

/// Score, timer (with danger pulse + floating penalty), and words-found count.
struct BoggleskyHUDView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: Design.spacing) {
            Button("Quit", systemImage: "xmark", action: quit)
                .labelStyle(.iconOnly)
                .padding(8)
                .glassEffect(.regular.interactive())

            Label("\(game.score)", systemImage: "star.fill")
                .font(.title3)
                .bold()
                .foregroundStyle(theme.accent)
                .contentTransition(.numericText())
                .animation(Design.snappy, value: game.score)
                .accessibilityLabel("Score \(game.score)")

            Spacer()

            VStack(spacing: 0) {
                Text(game.timeText)
                    .font(.title2)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(game.isDangerTime ? theme.danger : theme.accent)
                    .scaleEffect(game.isDangerTime ? 1.06 : 1)
                    .animation(
                        game.isDangerTime
                            ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                            : Design.snappy,
                        value: game.isDangerTime
                    )
                    .accessibilityLabel("Time left \(game.timeText)")
            }
            .overlay(alignment: .bottom) {
                if let penalty = game.penalty {
                    Text("−\(penalty.seconds)s")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(theme.danger)
                        .offset(y: 24)
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .offset(y: -30).combined(with: .opacity)
                        ))
                        .accessibilityHidden(true)
                }
            }
            .animation(.easeOut(duration: 0.8), value: game.penalty)

            Spacer()

            Text("Words: \(game.wordsFound.count)")
                .font(.subheadline)
                .foregroundStyle(theme.info)
                .contentTransition(.numericText())
                .animation(Design.snappy, value: game.wordsFound.count)
        }
        .padding(.horizontal, Design.padding)
        .frame(maxWidth: Design.maxContentWidth)
    }

    private func quit() {
        game.backToStart()
    }
}

/// The word being traced right now.
struct CurrentWordView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        Text(game.currentWord)
            .font(.system(.title, design: .rounded))
            .bold()
            .kerning(2)
            .foregroundStyle(theme.accent)
            .shadow(color: theme.accentGlow, radius: 10)
            .frame(minHeight: 40)
            .animation(Design.snappy, value: game.currentWord)
            .accessibilityLabel(game.currentWord.isEmpty ? "No letters selected" : "Current word \(game.currentWord)")
    }
}

struct ShuffleButtonView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        Button(action: shuffle) {
            Label("Shuffle (−\(BoggleskyEngine.shufflePenaltySeconds)s)", systemImage: "shuffle")
                .font(.headline)
                .padding(.horizontal, Design.padding)
                .padding(.vertical, 4)
        }
        .buttonStyle(.glass)
    }

    private func shuffle() {
        Task { await game.shuffle() }
    }
}

/// Centered glass toast ("Already found", "Board cleared!").
struct ToastView: View {
    @Environment(\.theme) private var theme
    let message: String

    var body: some View {
        Text(message)
            .font(.headline)
            .foregroundStyle(theme.textPrimary)
            .padding(.horizontal, Design.padding * 1.5)
            .padding(.vertical, Design.spacing)
            .glassEffect(.regular, in: .capsule)
            .transition(.scale(scale: 0.85).combined(with: .opacity))
            .allowsHitTesting(false)
    }
}

/// Shown when the app goes inactive mid-round.
struct PauseOverlayView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
            VStack(spacing: Design.spacing * 2) {
                Text("PAUSED")
                    .font(.system(.title, design: .rounded))
                    .bold()
                    .kerning(4)
                    .foregroundStyle(theme.accent)
                Button(action: resume) {
                    Label("Resume", systemImage: "play.fill")
                        .font(.title3)
                        .bold()
                        .padding(.horizontal, Design.padding)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private func resume() {
        game.setPaused(false)
    }
}
