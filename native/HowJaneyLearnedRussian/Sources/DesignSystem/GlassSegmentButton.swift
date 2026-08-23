import SwiftUI

/// One segment of a glass choice row (difficulty pickers, mode toggles).
struct GlassSegmentButton: View {
    @Environment(\.theme) private var theme
    let title: String
    let symbol: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: symbol)
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
