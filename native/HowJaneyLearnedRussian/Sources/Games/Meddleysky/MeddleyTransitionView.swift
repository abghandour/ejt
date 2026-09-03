import SwiftUI

/// Between levels: a "level cleared" card for the previous level (points and
/// combo counting up), then a slot-machine reel that lands on the next game
/// and reveals the difficulty the app picked. Auto-advances, or tap GO.
struct MeddleyTransitionView: View {
    @Environment(MeddleyskyModel.self) private var run
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let previous: MeddleyLevelRecord?
    let next: MeddleyLevelPlan

    @State private var reelSettled = false
    @State private var showDetails = false
    @State private var shownPoints = 0
    @State private var autoAdvance: Task<Void, Never>?

    private var spinDuration: Double { reduceMotion ? 0 : 1.7 }

    var body: some View {
        VStack(spacing: Design.spacing * 2) {
            HStack {
                Button("Quit", systemImage: "xmark", action: quit)
                    .labelStyle(.iconOnly)
                    .padding(10)
                    .glassEffect(.regular.interactive())
                Spacer()
                if previous != nil {
                    Label("\(run.runScore)", systemImage: "star.fill")
                        .font(.headline)
                        .bold()
                        .foregroundStyle(theme.accent)
                        .contentTransition(.numericText())
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .glassEffect(.regular)
                }
            }
            .padding(.horizontal, Design.padding)

            Spacer()

            if let previous {
                MeddleyClearedCard(record: previous, shownPoints: shownPoints)
                    .transition(.move(edge: .top).combined(with: .opacity))
            } else {
                Text("GET READY")
                    .heading(.title, kerning: 4)
                    .foregroundStyle(theme.textSecondary)
            }

            Text("LEVEL \(next.index)")
                .heading(.caption, kerning: 4)
                .foregroundStyle(theme.textMuted)

            MeddleyReelView(games: reelSequence, duration: spinDuration, settled: $reelSettled)

            VStack(spacing: Design.spacing) {
                Text(next.gameName.uppercased())
                    .heading(.largeTitle, kerning: 3)
                    .foregroundStyle(theme.textPrimary)
                    .opacity(reelSettled ? 1 : 0)
                    .scaleEffect(reelSettled ? 1 : 0.6)

                if showDetails {
                    MeddleyDifficultyChip(plan: next)
                        .transition(.scale.combined(with: .opacity))
                }
            }
            .frame(minHeight: 110)
            .animation(Design.bouncy, value: reelSettled)
            .animation(Design.bouncy, value: showDetails)

            Spacer()

            Button(action: go) {
                Label("Go", systemImage: "play.fill")
                    .font(.title2)
                    .bold()
                    .padding(.horizontal, Design.padding * 2.5)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.glassProminent)
            .disabled(!reelSettled)
            .opacity(reelSettled ? 1 : 0.4)

            Spacer()
        }
        .frame(maxWidth: Design.maxContentWidth)
        .task(runSequence)
        .onDisappear {
            autoAdvance?.cancel()
        }
    }

    /// Icons the reel scrolls through before stopping on `next.game`.
    private var reelSequence: [GameID] {
        let others = run.availableGames.filter { $0 != next.game }
        guard !others.isEmpty else { return [next.game] }
        var sequence: [GameID] = []
        let spins = reduceMotion ? 0 : 14
        for i in 0..<spins {
            sequence.append(others[i % others.count])
        }
        sequence.append(next.game)
        return sequence
    }

    private func runSequence() async {
        // 1. Count the previous level's points up.
        if let previous {
            let steps = 18
            for step in 1...steps {
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 35))
                guard !Task.isCancelled else { return }
                shownPoints = previous.points * step / steps
                if step % 3 == 0 {
                    model.soundEngine.play(.select(step: step / 3))
                }
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 400))
        }
        // 2. Spin the reel (the reel view animates itself once `settled` flips).
        let ticks = reduceMotion ? 0 : 12
        let tickTask = Task {
            for i in 0..<ticks {
                guard !Task.isCancelled else { return }
                model.soundEngine.play(.select(step: i % 4))
                // Ticks slow down as the reel loses momentum.
                try? await Task.sleep(for: .milliseconds(60 + i * i * 2))
            }
        }
        try? await Task.sleep(for: .seconds(spinDuration))
        tickTask.cancel()
        guard !Task.isCancelled else { return }
        reelSettled = true
        model.soundEngine.play(.boardClear)
        try? await Task.sleep(for: .milliseconds(reduceMotion ? 0 : 350))
        guard !Task.isCancelled else { return }
        showDetails = true
        // 3. Auto-advance unless the player already tapped GO.
        autoAdvance = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            go()
        }
    }

    private func go() {
        autoAdvance?.cancel()
        run.beginLevel(next)
    }

    private func quit() {
        autoAdvance?.cancel()
        run.quitRun()
    }
}

/// "Level N cleared" card: game, raw score, points, and combo.
private struct MeddleyClearedCard: View {
    @Environment(\.theme) private var theme
    let record: MeddleyLevelRecord
    let shownPoints: Int

    var body: some View {
        VStack(spacing: 6) {
            Text("LEVEL \(record.plan.index) CLEARED")
                .heading(.caption, kerning: 3)
                .foregroundStyle(theme.successText)
            HStack(spacing: 8) {
                GameIconView(game: record.plan.game, size: 22)
                    .foregroundStyle(theme.accent)
                Text(record.plan.gameName)
                    .font(.headline)
                    .foregroundStyle(theme.textPrimary)
                Text("· \(record.rawScore) pts")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("+\(shownPoints)")
                    .font(.system(size: 40, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                    .contentTransition(.numericText())
                    .animation(.linear(duration: 0.05), value: shownPoints)
                Label("×\(record.multiplier, specifier: "%.2f")", systemImage: "flame.fill")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(record.multiplier > 1 ? theme.dangerText : theme.textMuted)
            }
        }
        .padding(Design.padding)
        .frame(maxWidth: 340)
        .glassEffect(.regular.tint(theme.surface.opacity(0.5)), in: .rect(cornerRadius: Design.cornerRadius))
        .accessibilityElement(children: .combine)
    }
}

/// Vertical slot reel of game icons that scrolls and eases to a stop on the
/// last entry. The parent flips `settled` after `duration`.
private struct MeddleyReelView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let games: [GameID]
    let duration: Double
    @Binding var settled: Bool
    @State private var spun = false

    private let cell: Double = 96

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                ForEach(Array(games.enumerated()), id: \.offset) { _, game in
                    GameIconView(game: game, size: 52)
                        .foregroundStyle(theme.accent)
                        .frame(width: cell, height: cell)
                }
            }
            .offset(y: reelOffset)
            .animation(.timingCurve(0.15, 0.85, 0.2, 1, duration: duration), value: spun)
        }
        .frame(width: cell, height: cell)
        .clipShape(.rect(cornerRadius: Design.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: Design.cornerRadius)
                .strokeBorder(settled ? theme.accent : theme.tileBorder, lineWidth: settled ? 3 : 1.5)
        }
        .background(theme.tileGradient, in: .rect(cornerRadius: Design.cornerRadius))
        .shadow(color: settled ? theme.accentGlow : .clear, radius: 20)
        .scaleEffect(settled ? 1.12 : 1)
        .animation(Design.bouncy, value: settled)
        .onAppear {
            if reduceMotion {
                spun = true
            } else {
                Task {
                    try? await Task.sleep(for: .milliseconds(30))
                    spun = true
                }
            }
        }
        .accessibilityLabel("Next game reel")
    }

    /// The stack starts showing its first icon and ends showing its last.
    private var reelOffset: Double {
        let total = Double(games.count) * cell
        let restingOffset = (total - cell) / 2
        return spun ? -restingOffset : restingOffset
    }
}

/// Difficulty the app picked and why ("Rookie at Bogglesky → Easy").
private struct MeddleyDifficultyChip: View {
    @Environment(\.theme) private var theme
    let plan: MeddleyLevelPlan

    var body: some View {
        VStack(spacing: 4) {
            if let difficulty = plan.difficulty {
                Label(difficulty.displayName.uppercased(), systemImage: difficulty.symbol)
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(color(for: difficulty))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .glassEffect(.regular, in: .capsule)
            }
            Text(blurb)
                .font(.caption)
                .foregroundStyle(theme.textMuted)
        }
    }

    private var blurb: String {
        let level = plan.skill.label.lowercased()
        return plan.difficulty == nil
            ? "You're a \(level) at \(plan.gameName)"
            : "You're a \(level) at \(plan.gameName), so:"
    }

    private func color(for difficulty: MeddleyDifficulty) -> Color {
        switch difficulty {
        case .easy: theme.successText
        case .medium: theme.info
        case .hard: theme.dangerText
        }
    }
}
