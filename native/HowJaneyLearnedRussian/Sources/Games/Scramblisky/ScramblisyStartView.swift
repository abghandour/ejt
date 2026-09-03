import SwiftUI

/// Pre-round screen: title, rules, difficulty picker, play button.
struct ScramblisyStartView: View {
    @Environment(ScramblisyModel.self) private var game
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

            Image(systemName: GameID.scramblisky.symbol)
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accentGlow, radius: 16)
                .accessibilityHidden(true)

            Text("SCRAMBLISKY")
                .heading(.largeTitle, kerning: 4)
                .foregroundStyle(theme.textPrimary)

            Text("Unscramble as many \(game.language.displayName) words as you can in 90 seconds. Wrong answers and skipping cost precious time.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding * 2)

            GlassEffectContainer {
                HStack(spacing: 6) {
                    ForEach(ScramblisyDifficulty.allCases) { difficulty in
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

            Toggle(isOn: $game.isZen) {
                Label("Zen mode — no timer, no penalties", systemImage: "leaf.circle")
                    .font(.subheadline)
                    .foregroundStyle(theme.textSecondary)
            }
            .toggleStyle(.switch)
            .tint(theme.success)
            .frame(maxWidth: 320)

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
