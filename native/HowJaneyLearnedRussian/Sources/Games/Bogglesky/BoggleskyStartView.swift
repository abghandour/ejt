import SwiftUI

/// Pre-round screen: title, description, difficulty picker, play button.
struct BoggleskyStartView: View {
    @Environment(BoggleskyModel.self) private var game
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

            Image(systemName: GameID.bogglesky.symbol)
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accentGlow, radius: 16)
                .accessibilityHidden(true)

            Text("BOGGLESKY")
                .heading(.largeTitle, kerning: 4)
                .foregroundStyle(theme.textPrimary)

            Text("Swipe across adjacent letters to form \(game.language.displayName) words. Find as many as you can before time runs out.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding * 2)

            DifficultyPickerView()

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
        Task { await game.startRound() }
    }
}

/// Easy / Medium / Hard segmented glass control.
struct DifficultyPickerView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var game = game
        GlassEffectContainer {
            HStack(spacing: 6) {
                ForEach(BoggleskyDifficulty.allCases) { difficulty in
                    DifficultyButton(difficulty: difficulty, isSelected: game.difficulty == difficulty) {
                        game.difficulty = difficulty
                    }
                }
            }
        }
    }
}

struct DifficultyButton: View {
    @Environment(\.theme) private var theme
    let difficulty: BoggleskyDifficulty
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(difficulty.displayName, systemImage: difficulty.symbol)
                .font(.subheadline)
                .bold()
                .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
                .padding(.horizontal, Design.padding)
                .padding(.vertical, 10)
        }
        .glassEffect(
            isSelected ? .regular.tint(theme.accentGlow).interactive() : .regular.interactive()
        )
        .animation(Design.snappy, value: isSelected)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
