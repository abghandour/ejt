import SwiftUI

/// The in-round screen: HUD, answer slots, letter rack, hint, found words, actions.
struct ScramblisyPlayView: View {
    @Environment(ScramblisyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing) {
            ScramblisyHUDView()
            Spacer()
            AnswerSlotsView()
            LetterRackView()
                .overlay {
                    if game.isTransitioning {
                        ExplosionBurstView(trigger: game.explosionTrigger)
                    }
                }
            ScramblisyHintView()
            Spacer()
            FoundWordChipsView()
            ScramblisyActionRowView()
        }
        .padding(.vertical, Design.spacing)
        .frame(maxWidth: Design.maxContentWidth)
    }
}

/// Close, score, timer (with penalty float), and word count.
struct ScramblisyHUDView: View {
    @Environment(ScramblisyModel.self) private var game
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

            if game.isOnFire {
                Label("×2", systemImage: "flame.fill")
                    .font(.headline)
                    .bold()
                    .foregroundStyle(theme.danger)
                    .transition(.scale.combined(with: .opacity))
                    .accessibilityLabel("Combo active, double points")
            }

            Spacer()

            Text(game.isZen ? "∞" : game.timeText)
                .font(.title2)
                .bold()
                .monospacedDigit()
                .foregroundStyle(game.isDangerTime && !game.isZen ? theme.danger : theme.accent)
                .scaleEffect(game.isDangerTime && !game.isZen ? 1.06 : 1)
                .animation(
                    game.isDangerTime && !game.isZen
                        ? .easeInOut(duration: 0.5).repeatForever(autoreverses: true)
                        : Design.snappy,
                    value: game.isDangerTime
                )
                .overlay(alignment: .top) {
                    if let bonus = game.timeBonus {
                        Text("+\(bonus.seconds)s")
                            .font(.headline)
                            .bold()
                            .foregroundStyle(theme.successText)
                            .offset(y: -24)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .offset(y: -20).combined(with: .opacity)
                            ))
                            .accessibilityHidden(true)
                    }
                }
                .animation(.easeOut(duration: 0.8), value: game.timeBonus)
                .overlay(alignment: .bottom) {
                    if let penalty = game.penalty {
                        Text("−\(penalty.seconds)s")
                            .font(.headline)
                            .bold()
                            .foregroundStyle(theme.danger)
                            .offset(y: 26)
                            .transition(.asymmetric(
                                insertion: .opacity,
                                removal: .offset(y: -30).combined(with: .opacity)
                            ))
                            .accessibilityHidden(true)
                    }
                }
                .animation(.easeOut(duration: 0.8), value: game.penalty)
                .accessibilityLabel("Time left \(game.timeText)")

            Spacer()

            Text("Words: \(game.wordsCompleted)")
                .font(.subheadline)
                .foregroundStyle(theme.info)
                .contentTransition(.numericText())
                .animation(Design.snappy, value: game.wordsCompleted)
        }
        .padding(.horizontal, Design.padding)
        .animation(Design.bouncy, value: game.isOnFire)
    }

    private func quit() {
        game.backToStart()
    }
}

/// Translation hint per difficulty: always, tap-to-reveal, or hidden.
struct ScramblisyHintView: View {
    @Environment(ScramblisyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        Group {
            switch game.difficulty.hintMode {
            case .never:
                Color.clear
            case .always, .onRequest:
                if game.hintRevealed {
                    Label(game.currentWord?.translation ?? "", systemImage: "lightbulb.fill")
                        .font(.title3)
                        .italic()
                        .foregroundStyle(theme.info)
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                } else {
                    Button("Show hint (translation)", systemImage: "lightbulb", action: reveal)
                        .labelStyle(.iconOnly)
                        .font(.title3)
                        .foregroundStyle(theme.info)
                        .padding(8)
                        .glassEffect(.regular.interactive())
                }
            }
        }
        .frame(minHeight: 44)
        .animation(Design.snappy, value: game.hintRevealed)
    }

    private func reveal() {
        game.revealHint()
    }
}

/// Last few solved words as green chips.
struct FoundWordChipsView: View {
    @Environment(ScramblisyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 6) {
                // Offset identity: the same word can be solved again after a queue recycle.
                ForEach(Array(game.completedWords.suffix(10).reversed().enumerated()), id: \.offset) { _, found in
                    Text(found.word)
                        .font(.caption)
                        .bold()
                        .foregroundStyle(theme.successText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(theme.correctGradient, in: .capsule)
                        .overlay(Capsule().strokeBorder(theme.correctBorder, lineWidth: 1))
                }
            }
            .padding(.horizontal, Design.padding)
        }
        .scrollIndicators(.hidden)
        .frame(height: 32)
        .animation(Design.snappy, value: game.completedWords)
    }
}

/// Clear (when allowed) and Next Word buttons.
struct ScramblisyActionRowView: View {
    @Environment(ScramblisyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        HStack(spacing: Design.spacing) {
            if game.difficulty.allowsClear {
                Button("Clear", systemImage: "delete.left", action: clear)
                    .font(.headline)
                    .buttonStyle(.glass)
            }
            Button(action: skip) {
                Label("Next Word (−\(ScramblisyModel.skipPenaltySeconds)s)", systemImage: "forward.fill")
                    .font(.headline)
            }
            .buttonStyle(.glass)
        }
        .padding(.horizontal, Design.padding)
    }

    private func clear() {
        game.clearSelection()
    }

    private func skip() {
        game.skipWord()
    }
}
