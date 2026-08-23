import SwiftUI

/// Scrollable chips for every findable word: translations on easy (tap to
/// reveal at a time cost), mysteries on medium/hard, checkmarks once found.
struct HintBarView: View {
    @Environment(BoggleskyModel.self) private var game

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                ForEach(game.hintItems) { item in
                    HintChipView(item: item)
                }
            }
            .padding(.horizontal, Design.padding)
        }
        .scrollIndicators(.hidden)
        .frame(maxWidth: Design.maxContentWidth)
        .animation(Design.snappy, value: game.hintItems)
    }
}

struct HintChipView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme
    let item: HintItem

    var body: some View {
        Button(action: reveal) {
            content
                .padding(.horizontal, Design.spacing)
                .padding(.vertical, 8)
                .frame(minWidth: 44, minHeight: 44)
                .background(background, in: .capsule)
                .overlay(Capsule().strokeBorder(borderColor, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!isTappable)
        .accessibilityLabel(accessibilityText)
    }

    @ViewBuilder private var content: some View {
        switch item.state {
        case .found:
            HStack(spacing: 4) {
                Text(item.word)
                    .bold()
                    .foregroundStyle(theme.successText)
                Text(item.translation)
                    .foregroundStyle(theme.info)
                Image(systemName: "checkmark")
                    .font(.caption2)
                    .foregroundStyle(theme.successText)
                    .accessibilityHidden(true)
            }
            .font(.subheadline)
        case .translationOnly:
            Label(item.translation, systemImage: "lightbulb")
                .font(.subheadline)
                .foregroundStyle(theme.info)
        case .revealed:
            HStack(spacing: 4) {
                Text(item.word)
                    .bold()
                    .foregroundStyle(theme.accent)
                Text(item.translation)
                    .foregroundStyle(theme.info)
            }
            .font(.subheadline)
        case .mystery:
            Text("?")
                .font(.headline)
                .foregroundStyle(theme.textSecondary)
        }
    }

    private var isTappable: Bool {
        item.state == .translationOnly || (item.state == .found && game.speech.hasVoice(for: game.language.id))
    }

    private var background: AnyShapeStyle {
        switch item.state {
        case .found: AnyShapeStyle(theme.correctGradient)
        case .revealed: AnyShapeStyle(theme.tileSelectedGradient)
        case .translationOnly, .mystery: AnyShapeStyle(theme.tileGradient)
        }
    }

    private var borderColor: Color {
        switch item.state {
        case .found: theme.correctBorder
        case .revealed: theme.accent
        case .translationOnly, .mystery: theme.tileBorder
        }
    }

    private var accessibilityText: String {
        switch item.state {
        case .found: "Found \(item.word), \(item.translation). Tap to hear it."
        case .translationOnly: "Hint: \(item.translation). Tap to reveal the word for \(BoggleskyEngine.hintPenaltySeconds) seconds."
        case .revealed: "\(item.word), \(item.translation)"
        case .mystery: "Hidden word"
        }
    }

    private func reveal() {
        // Found chips replay their pronunciation; unrevealed easy hints reveal.
        if item.state == .found {
            game.speak(word: item.word)
        } else {
            game.revealHint(for: item.word)
        }
    }
}
