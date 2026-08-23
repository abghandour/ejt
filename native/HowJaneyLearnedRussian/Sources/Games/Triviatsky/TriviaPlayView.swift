import SwiftUI

/// The in-round (and review) screen: top bar, category, tracker, question,
/// timer, answers, and next button.
struct TriviaPlayView: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: Design.spacing) {
            TriviaTopBarView()
            TriviaTrackerView()

            ScrollView {
                VStack(spacing: Design.spacing) {
                    TriviaCategoryView()
                    TriviaQuestionCardView()
                        .id(game.questionAppearance)
                        .transition(.asymmetric(
                            insertion: .offset(y: 40).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
                            removal: .opacity
                        ))
                    if let remaining = game.timerRemaining {
                        TriviaTimerView(remaining: remaining, total: game.timerTotal)
                    }
                    TriviaAnswerGridView()
                    if game.showNext {
                        Button(action: next) {
                            Label("Next", systemImage: "arrow.right")
                                .font(.title3)
                                .bold()
                                .padding(.horizontal, Design.padding * 1.5)
                                .padding(.vertical, 6)
                        }
                        .buttonStyle(.glassProminent)
                        .transition(.scale(scale: 0.8).combined(with: .opacity))
                    }
                }
                .padding(.horizontal, Design.padding)
                .padding(.bottom, Design.padding)
                .frame(maxWidth: Design.maxContentWidth)
            }
            .scrollIndicators(.hidden)
        }
        .animation(Design.bouncy, value: game.questionAppearance)
        .animation(Design.snappy, value: game.showNext)
    }

    private func next() {
        game.next()
    }
}

/// Close, calendar (with date), share (completed days only).
struct TriviaTopBarView: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        HStack(spacing: Design.spacing) {
            Button("Quit", systemImage: "xmark", action: { dismiss() })
                .labelStyle(.iconOnly)
                .padding(8)
                .glassEffect(.regular.interactive())

            Button(action: openCalendar) {
                Label(game.friendlyDate, systemImage: "calendar")
                    .font(.subheadline)
                    .bold()
                    .foregroundStyle(theme.accent)
                    .padding(.horizontal, Design.spacing)
                    .padding(.vertical, 8)
            }
            .glassEffect(.regular.interactive())

            Spacer()

            if game.isCompleted {
                ShareLink(item: game.shareText) {
                    Label("Share", systemImage: "square.and.arrow.up")
                        .labelStyle(.iconOnly)
                        .padding(8)
                }
                .glassEffect(.regular.interactive())
            }

            if model.gameCenter.isAuthenticated {
                Button("Ranks", systemImage: "chart.bar.fill", action: showLeaderboard)
                    .labelStyle(.iconOnly)
                    .padding(8)
                    .glassEffect(.regular.interactive())
            }
        }
        .padding(.horizontal, Design.padding)
        .frame(maxWidth: Design.maxContentWidth)
    }

    private func openCalendar() {
        game.isShowingCalendar = true
    }

    private func showLeaderboard() {
        model.gameCenter.showLeaderboard(game: .triviatsky, languageID: game.language.id, difficulty: nil)
    }
}

/// Category badge above the question (Russian content only).
struct TriviaCategoryView: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        if let category = game.currentQuestion?.category {
            Label(category.uppercased(), systemImage: game.currentQuestion?.categorySymbol ?? "questionmark.circle")
                .font(.subheadline)
                .bold()
                .kerning(1.5)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

/// Question text, translation, and hint.
struct TriviaQuestionCardView: View {
    @Environment(TriviatskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 6) {
            if let question = game.currentQuestion {
                if let imageName = question.bundledImageName {
                    TriviaImageView(imageName: imageName, languageID: game.language.id)
                        .padding(.bottom, 4)
                }
                Text(question.question)
                    .font(.system(.title2, design: .rounded))
                    .bold()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(theme.textPrimary)

                if game.showTranslations, let translation = question.questionTranslation {
                    Text(translation)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.info)
                }

                if let hint = question.hint {
                    Text(hint)
                        .font(.footnote)
                        .italic()
                        .multilineTextAlignment(.center)
                        .foregroundStyle(theme.info)
                }
            }
        }
        .padding(.vertical, Design.spacing)
    }
}

/// Per-question countdown with a draining bar, urgent at ≤5s.
struct TriviaTimerView: View {
    @Environment(\.theme) private var theme
    let remaining: Int
    let total: Int

    private var isUrgent: Bool { remaining <= 5 }

    var body: some View {
        VStack(spacing: 4) {
            Text("\(max(0, remaining))s")
                .font(.headline)
                .monospacedDigit()
                .foregroundStyle(isUrgent ? theme.danger : theme.accent)
            Capsule()
                .fill(theme.tileBorder.opacity(0.4))
                .frame(height: 6)
                .overlay(alignment: .leading) {
                    GeometryReader { proxy in
                        Capsule()
                            .fill(isUrgent ? theme.danger : theme.accent)
                            .frame(width: proxy.size.width * fraction)
                            .animation(.linear(duration: 1), value: remaining)
                    }
                }
                .clipShape(.capsule)
        }
        .frame(maxWidth: 400)
        .accessibilityElement()
        .accessibilityLabel("\(max(0, remaining)) seconds left")
    }

    private var fraction: Double {
        total > 0 ? max(0, Double(remaining) / Double(total)) : 0
    }
}
