import SwiftUI

/// Pre-game screen: title, date, translation-difficulty toggle, start/resume.
struct TriviaStartView: View {
    @Environment(TriviatskyModel.self) private var game
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

            Image(systemName: GameID.triviatsky.symbol)
                .font(.system(size: 56))
                .foregroundStyle(theme.accent)
                .shadow(color: theme.accentGlow, radius: 16)
                .accessibilityHidden(true)

            Text("TRIVIATSKY")
                .heading(.largeTitle, kerning: 4)
                .foregroundStyle(theme.textPrimary)

            Text(game.friendlyDate)
                .font(.headline)
                .foregroundStyle(theme.accent)

            Text("Daily trivia challenge. Answer questions, earn stars!")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(theme.textSecondary)
                .padding(.horizontal, Design.padding * 2)

            if game.hasTranslations {
                TriviaModePickerView()
            }

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

    private func start() {
        game.start()
    }

    private func openCalendar() {
        game.isShowingCalendar = true
    }
}

/// Easy (with translations) vs Hard (target language only).
struct TriviaModePickerView: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        GlassEffectContainer {
            HStack(spacing: 6) {
                TriviaModeButton(
                    title: "Easy",
                    subtitle: "With English translation",
                    isSelected: game.showTranslations
                ) {
                    game.showTranslations = true
                }
                TriviaModeButton(
                    title: "Hard",
                    subtitle: "\(game.language.displayName) only",
                    isSelected: !game.showTranslations
                ) {
                    game.showTranslations = false
                }
            }
        }
        .padding(.horizontal, Design.padding)
    }
}

struct TriviaModeButton: View {
    @Environment(\.theme) private var theme
    let title: String
    let subtitle: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(isSelected ? theme.accent : theme.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
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
