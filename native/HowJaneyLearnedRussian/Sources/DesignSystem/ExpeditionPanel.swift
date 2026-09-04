import SwiftUI

/// The app's paper-and-ink surface treatment. It replaces the repeated
/// translucent glass cards with a tactile field-notebook vocabulary.
struct ExpeditionPanelModifier: ViewModifier {
    @Environment(\.theme) private var theme

    func body(content: Content) -> some View {
        content
            .padding(Design.padding)
            .background {
                RoundedRectangle(cornerRadius: Design.cardCornerRadius, style: .continuous)
                    .fill(theme.surface.opacity(theme.isDark ? 0.94 : 0.9))
                    .overlay {
                        RoundedRectangle(cornerRadius: Design.cardCornerRadius, style: .continuous)
                            .stroke(theme.textPrimary.opacity(theme.isDark ? 0.16 : 0.11), lineWidth: 1)
                    }
                    .shadow(color: theme.textPrimary.opacity(theme.isDark ? 0.24 : 0.12), radius: 12, y: 7)
            }
    }
}

extension View {
    func expeditionPanel() -> some View {
        modifier(ExpeditionPanelModifier())
    }
}
