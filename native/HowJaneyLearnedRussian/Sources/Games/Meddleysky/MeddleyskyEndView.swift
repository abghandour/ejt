import SwiftUI

/// Run over: total, levels cleared, best combo, per-level breakdown,
/// Again / Share / Ranks.
struct MeddleyskyEndView: View {
    @Environment(MeddleyskyModel.self) private var run
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: Design.spacing * 1.5) {
                HStack {
                    Button("Close", systemImage: "xmark", action: { dismiss() })
                        .labelStyle(.iconOnly)
                        .padding(10)
                        .glassEffect(.regular.interactive())
                    Spacer()
                }
                .padding(.horizontal, Design.padding)

                MeddleyDiceIconView(size: 44)
                    .padding(.top, Design.spacing)

                Text(run.isNewBest ? "NEW BEST RUN!" : "RUN OVER")
                    .heading(.largeTitle, kerning: 3)
                    .foregroundStyle(run.isNewBest ? theme.accent : theme.textPrimary)

                if let fatal = run.fatalLevel {
                    Text("\(fatal.gameName) got you on level \(fatal.index).")
                        .font(.subheadline)
                        .foregroundStyle(theme.textSecondary)
                }

                Text("\(run.runScore)")
                    .font(.system(size: 56, weight: .heavy, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                    .shadow(color: theme.accentGlow, radius: 12)
                    .accessibilityLabel("Run score \(run.runScore)")

                VStack(spacing: 8) {
                    EndStatRow(label: "Levels cleared", value: "\(run.levelsCleared)", color: theme.textPrimary)
                    EndStatRow(
                        label: "Best combo",
                        value: String(format: "×%.2f", run.bestMultiplier),
                        color: theme.dangerText
                    )
                    EndStatRow(label: "Best run", value: "\(max(run.previousBest, run.runScore))", color: theme.accent)
                }
                .padding(Design.padding)
                .frame(maxWidth: 360)
                .glassEffect(.regular, in: .rect(cornerRadius: Design.cornerRadius))

                if !run.levels.isEmpty {
                    VStack(spacing: 6) {
                        ForEach(run.levels) { level in
                            MeddleyLevelRow(level: level)
                        }
                    }
                    .padding(Design.padding)
                    .frame(maxWidth: 360)
                    .glassEffect(.regular, in: .rect(cornerRadius: Design.cornerRadius))
                }

                HStack(spacing: Design.spacing) {
                    Button(action: again) {
                        Label("Again", systemImage: "arrow.counterclockwise")
                            .bold()
                            .padding(.horizontal, Design.padding)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)

                    ShareLink(item: run.shareText) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .padding(.horizontal, Design.padding)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glass)

                    if model.gameCenter.isAuthenticated {
                        Button("Ranks", systemImage: "chart.bar.fill", action: showLeaderboard)
                            .padding(.horizontal, Design.padding)
                            .padding(.vertical, 6)
                            .buttonStyle(.glass)
                    }
                }
                .padding(.bottom, Design.padding * 2)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func again() {
        run.startRun()
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(game: .meddleysky, languageID: run.language.id, difficulty: nil)
    }
}

/// One level in the breakdown: icon, game and tier, raw score, points earned.
private struct MeddleyLevelRow: View {
    @Environment(\.theme) private var theme
    let level: MeddleyLevelRecord

    var body: some View {
        HStack(spacing: Design.spacing) {
            Text("\(level.plan.index)")
                .font(.caption)
                .bold()
                .monospacedDigit()
                .foregroundStyle(theme.textMuted)
                .frame(width: 18, alignment: .trailing)
            GameIconView(game: level.plan.game, size: 18)
                .foregroundStyle(theme.accent)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(level.plan.gameName)
                    .font(.subheadline)
                    .foregroundStyle(theme.textPrimary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(theme.textMuted)
            }
            Spacer()
            Text("+\(level.points)")
                .font(.subheadline)
                .bold()
                .monospacedDigit()
                .foregroundStyle(theme.successText)
        }
        .accessibilityElement(children: .combine)
    }

    private var subtitle: String {
        var parts = ["\(level.rawScore) pts"]
        if let difficulty = level.plan.difficulty {
            parts.append(difficulty.displayName)
        }
        parts.append(String(format: "×%.2f", level.multiplier))
        return parts.joined(separator: " · ")
    }
}
