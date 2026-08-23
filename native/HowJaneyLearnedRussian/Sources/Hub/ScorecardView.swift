import SwiftUI

/// Fixed-size scorecard rendered to an image for sharing (ImageRenderer has
/// no environment, so everything arrives by value).
struct ScorecardView: View {
    let playerName: String
    let languageName: String
    let rankTitle: String
    let rows: [ProfileScoreboardView.Row]
    let theme: Theme

    var body: some View {
        VStack(spacing: 14) {
            Text("JANEY GAMES")
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .kerning(3)
                .foregroundStyle(theme.textSecondary)

            Text(playerName)
                .font(.system(size: 26, weight: .bold, design: .rounded))
                .foregroundStyle(theme.accent)

            Text(rankTitle)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.danger)

            Text("\(languageName) Scoreboard")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.textPrimary)

            if rows.isEmpty {
                Text("Just getting started!")
                    .font(.system(size: 14))
                    .foregroundStyle(theme.textMuted)
            } else {
                VStack(spacing: 8) {
                    ForEach(rows) { row in
                        HStack {
                            Image(systemName: row.game.symbol)
                                .foregroundStyle(theme.accent)
                                .frame(width: 24)
                            Text(row.name)
                                .font(.system(size: 15, weight: .bold))
                                .foregroundStyle(theme.textPrimary)
                            Spacer()
                            if row.bestStreak > 1 {
                                HStack(spacing: 2) {
                                    Image(systemName: "flame.fill")
                                    Text("\(row.bestStreak)")
                                }
                                .font(.system(size: 13, weight: .bold))
                                .foregroundStyle(theme.danger)
                            }
                            HStack(spacing: 2) {
                                Image(systemName: "star.fill")
                                Text("\(row.bestScore)")
                            }
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(theme.accent)
                            .frame(minWidth: 56, alignment: .trailing)
                        }
                    }
                }
            }

            Text("Think you can beat me?")
                .font(.system(size: 13, weight: .semibold))
                .italic()
                .foregroundStyle(theme.info)
        }
        .padding(24)
        .frame(width: 340)
        .background(theme.bgPrimary)
        .clipShape(.rect(cornerRadius: 20))
    }
}
