import SwiftUI

/// Meddleysky container: owns the run model and switches between the start
/// screen, the between-level transition, the hosted level, and the end screen.
struct MeddleyskyView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @State private var run: MeddleyskyModel?

    var body: some View {
        ZStack {
            ThemedBackground()
            if let run {
                MeddleyskyPhaseView()
                    .environment(run)
                    .overlay {
                        ConfettiView(trigger: run.confettiTrigger)
                    }
            } else {
                ProgressView()
            }
        }
        .task(createRunIfNeeded)
        .sensoryFeedback(.selection, trigger: run?.selectionTick ?? 0) { _, _ in
            model.settings.hapticsEnabled
        }
        .sensoryFeedback(.success, trigger: run?.successTick ?? 0) { _, _ in
            model.settings.hapticsEnabled
        }
        .sensoryFeedback(.error, trigger: run?.errorTick ?? 0) { _, _ in
            model.settings.hapticsEnabled
        }
    }

    private func createRunIfNeeded() async {
        guard run == nil else { return }
        let session = MeddleyskyModel(
            language: model.language,
            stats: model.stats,
            soundEngine: model.soundEngine
        ) { [weak model] result in
            model?.finishedMeddleysky(result)
        }
        run = session
        if ProcessInfo.processInfo.arguments.contains("-autostart-round") {
            session.startRun()
        }
    }
}

struct MeddleyskyPhaseView: View {
    @Environment(MeddleyskyModel.self) private var run

    var body: some View {
        switch run.phase {
        case .start:
            MeddleyskyStartView()
                .transition(.opacity)
        case .transition(let previous, let next):
            MeddleyTransitionView(previous: previous, next: next)
                .id(next.index)
                .transition(.opacity)
        case .playing(let plan):
            MeddleyLevelView(plan: plan)
                .id(plan.index)
                .safeAreaInset(edge: .bottom) {
                    MeddleyRunHUDView(plan: plan)
                }
                .transition(.opacity)
        case .finished:
            MeddleyskyEndView()
                .transition(.opacity.combined(with: .scale(scale: 1.05)))
        }
    }
}

/// Slim strip under a hosted level: level number, run score, combo.
struct MeddleyRunHUDView: View {
    @Environment(MeddleyskyModel.self) private var run
    @Environment(\.theme) private var theme
    let plan: MeddleyLevelPlan

    var body: some View {
        HStack(spacing: Design.spacing) {
            Label("Level \(plan.index)", systemImage: "dice.fill")
            Spacer()
            Label("\(run.runScore)", systemImage: "star.fill")
                .contentTransition(.numericText())
            Text("×\(plan.multiplier, specifier: "%.2f")")
                .monospacedDigit()
        }
        .font(.caption)
        .bold()
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, Design.padding)
        .padding(.vertical, 6)
        .glassEffect(.regular, in: .capsule)
        .padding(.horizontal, Design.padding)
        .padding(.bottom, 4)
        .accessibilityElement(children: .combine)
    }
}

/// Pre-run screen: rules, best run, play button.
struct MeddleyskyStartView: View {
    @Environment(MeddleyskyModel.self) private var run
    @Environment(AppModel.self) private var model
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

            MeddleyDiceIconView(size: 64)

            Text("MEDDLEYSKY")
                .heading(.largeTitle, kerning: 4)
                .foregroundStyle(theme.textPrimary)

            Text("Every game, shuffled into one run.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding * 2)

            VStack(alignment: .leading, spacing: Design.spacing) {
                MeddleyRuleRow(symbol: "dice.fill", text: "Each level is a different game, picked at random.")
                MeddleyRuleRow(symbol: "gauge.with.needle", text: "Difficulty adapts to how good you are at that game.")
                MeddleyRuleRow(symbol: "flame.fill", text: "Every level you survive grows your combo.")
                MeddleyRuleRow(symbol: "xmark.octagon.fill", text: "Score zero in a level and the run is over.")
            }
            .padding(Design.padding)
            .frame(maxWidth: 360)
            .glassEffect(.regular, in: .rect(cornerRadius: Design.cornerRadius))

            if run.previousBest > 0 {
                Label("Best run: \(run.previousBest)", systemImage: "trophy.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(theme.accent)
            }

            Button(action: play) {
                Label("Play", systemImage: "play.fill")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal, Design.padding * 2.5)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .disabled(run.availableGames.isEmpty)

            Spacer()
            Spacer()
        }
    }

    private func play() {
        run.startRun()
    }
}

private struct MeddleyRuleRow: View {
    @Environment(\.theme) private var theme
    let symbol: String
    let text: String

    var body: some View {
        Label {
            Text(text)
                .font(.subheadline)
                .foregroundStyle(theme.textPrimary)
        } icon: {
            Image(systemName: symbol)
                .foregroundStyle(theme.accent)
                .frame(width: 22)
        }
    }
}

/// The Meddleysky icon: a glowing die that idly tumbles.
struct MeddleyDiceIconView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let size: Double
    @State private var tilt = false

    var body: some View {
        Image(systemName: GameID.meddleysky.symbol)
            .font(.system(size: size))
            .foregroundStyle(theme.accent)
            .shadow(color: theme.accentGlow, radius: 16)
            .rotationEffect(.degrees(tilt ? 12 : -12))
            .animation(
                reduceMotion ? nil : .easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                value: tilt
            )
            .onAppear { tilt = true }
            .accessibilityHidden(true)
    }
}
