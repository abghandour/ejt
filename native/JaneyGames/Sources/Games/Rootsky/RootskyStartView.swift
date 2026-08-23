import SwiftUI

/// Pre-game screen: title, date, description, start/resume.
struct RootskyStartView: View {
    @Environment(RootskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss
    let canResume: Bool

    var body: some View {
        VStack(spacing: Design.spacing * 2) {
            HStack {
                Button("Close", systemImage: "xmark", action: { dismiss() })
                    .labelStyle(.iconOnly)
                    .padding(10)
                    .glassEffect(.regular.interactive())
                Spacer()
                Button("Calendar", systemImage: "calendar", action: openCalendar)
                    .labelStyle(.iconOnly)
                    .padding(10)
                    .glassEffect(.regular.interactive())
            }
            .padding(.horizontal, Design.padding)

            Spacer()

            Image(systemName: game.game.symbol)
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accentGlow, radius: 16)
                .accessibilityHidden(true)

            Text(game.title)
                .font(.system(.largeTitle, design: .rounded))
                .bold()
                .kerning(4)
                .foregroundStyle(theme.textPrimary)

            Text(game.friendlyDate)
                .font(.headline)
                .foregroundStyle(theme.accent)

            Text(startLabel)
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding * 2)

            Button(action: start) {
                Label(canResume ? "Resume" : "Start", systemImage: "play.fill")
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

    private var startLabel: String {
        if canResume, let state = game.state {
            "Resume game — Word \(state.currentWordIndex + 1)/\(RootskyModel.wordsPerDay)"
        } else if game.game == .wordsky {
            "Guess the translation of each \(game.language.displayName) word. 5 words, daily challenge."
        } else {
            "Match \(game.language.displayName) words to their roots. 5 words, daily challenge."
        }
    }

    private func start() {
        game.start()
    }

    private func openCalendar() {
        game.isShowingCalendar = true
    }
}
