import SwiftUI

/// A short, local ceremony for rank gains. This makes the hidden XP ladder
/// legible at the moment a round changes it.
struct RankUpBannerView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let rank: Rank
    let dismiss: () -> Void
    @State private var isPresented = false

    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 14) {
                Image(systemName: "rosette")
                    .font(.title.weight(.black))
                    .foregroundStyle(theme.accent)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(theme.accent.opacity(0.15)))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("RANK UP")
                        .font(.caption.weight(.black))
                        .tracking(1.4)
                        .foregroundStyle(theme.textSecondary)
                    Text("\(rank.name) · \(rank.nativeName)")
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(theme.textPrimary)
                    Text("Your expedition just earned a new insignia.")
                        .font(.caption)
                        .foregroundStyle(theme.textMuted)
                }
                Spacer(minLength: 0)
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textMuted)
                    .accessibilityHidden(true)
            }
            .expeditionPanel()
        }
        .buttonStyle(.plain)
        .scaleEffect(isPresented ? 1 : 0.86)
        .opacity(isPresented ? 1 : 0)
        .onAppear {
            guard !reduceMotion else {
                isPresented = true
                return
            }
            withAnimation(Design.celebration) {
                isPresented = true
            }
        }
        .accessibilityLabel("Rank up: \(rank.name), \(rank.nativeName)")
        .accessibilityHint("Dismisses this celebration")
    }
}

/// In-app achievement stamps remain satisfying even when Game Center is not
/// signed in, while Game Center reporting continues in the service layer.
struct AchievementStampView: View {
    @Environment(\.theme) private var theme
    let achievement: AchievementService.ID
    let dismiss: () -> Void

    var body: some View {
        Button(action: dismiss) {
            HStack(spacing: 14) {
                Image(systemName: achievement.symbol)
                    .font(.title2.weight(.black))
                    .foregroundStyle(theme.success)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(theme.success.opacity(0.15)))
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text("STAMP EARNED")
                        .font(.caption.weight(.black))
                        .tracking(1.3)
                        .foregroundStyle(theme.textSecondary)
                    Text(achievement.title)
                        .font(.system(.headline, design: .rounded).weight(.black))
                        .foregroundStyle(theme.textPrimary)
                    Text(achievement.message)
                        .font(.caption)
                        .foregroundStyle(theme.textMuted)
                        .lineLimit(2)
                }
                Spacer(minLength: 0)
                Image(systemName: "xmark")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(theme.textMuted)
                    .accessibilityHidden(true)
            }
            .expeditionPanel()
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Achievement earned: \(achievement.title). \(achievement.message)")
        .accessibilityHint("Dismisses this achievement")
    }
}
