import SwiftUI

/// Loud streak flame in the hub header: best current streak across all games
/// for the active language. Pulses when it grows.
struct StreakFlameView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    private var streak: Int {
        model.games
            .compactMap { model.stats.stats(game: $0.id, languageID: model.language.id)?.currentStreak }
            .max() ?? 0
    }

    var body: some View {
        if streak >= 2 {
            HStack(spacing: 3) {
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange.gradient)
                    .scaleEffect(pulse ? 1.15 : 1)
                Text("\(streak)")
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle(theme.accent)
                    .contentTransition(.numericText())
            }
            .font(.headline)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .glassEffect(.regular.tint(theme.danger.opacity(0.15)))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
            .accessibilityLabel("\(streak) day streak")
        }
    }
}
