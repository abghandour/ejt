import SwiftUI

/// The player's rank insignia with progress toward the next rank.
struct RankBadgeView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme

    var body: some View {
        let xp = model.totalXP
        let rank = model.rank
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                ForEach(0..<rank.stars, id: \.self) { _ in
                    Image(systemName: rank.index >= 5 ? "star.circle.fill" : "star.fill")
                        .font(.subheadline)
                        .foregroundStyle(theme.accent)
                }
            }
            .accessibilityHidden(true)

            Text("\(rank.name) · \(rank.nativeName)")
                .font(.system(.headline, design: .rounded))
                .bold()
                .foregroundStyle(theme.accent)

            if let next = rank.next {
                ProgressView(value: Rank.progress(forXP: xp))
                    .tint(theme.accent)
                    .frame(maxWidth: 200)
                Text("\(xp) XP · \(next.threshold - xp) to \(next.name)")
                    .font(.caption)
                    .foregroundStyle(theme.textMuted)
            } else {
                Text("\(xp) XP · highest rank achieved")
                    .font(.caption)
                    .foregroundStyle(theme.textMuted)
            }
        }
        .accessibilityElement(children: .combine)
    }
}
