import SwiftUI

/// Swatch grid for the themes the current language offers.
struct ThemeGridView: View {
    @Environment(AppModel.self) private var model

    private let columns = [GridItem(.adaptive(minimum: 88), spacing: Design.spacing)]

    var body: some View {
        LazyVGrid(columns: columns, spacing: Design.spacing) {
            ForEach(model.availableThemes) { selection in
                ThemeSwatchView(selection: selection)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ThemeSwatchView: View {
    @Environment(AppModel.self) private var model
    @Environment(\.theme) private var theme
    let selection: ThemeSelection

    private var swatchTheme: Theme { selection.resolved() }
    private var isSelected: Bool { model.settings.themeSelection == selection }

    var body: some View {
        Button(action: select) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: Design.tileCornerRadius)
                        .fill(swatchTheme.bgPrimary)
                    HStack(spacing: 4) {
                        Circle().fill(swatchTheme.accent).frame(width: 12, height: 12)
                        Circle().fill(swatchTheme.tileTop).frame(width: 12, height: 12)
                        Circle().fill(swatchTheme.textPrimary).frame(width: 12, height: 12)
                    }
                    if model.isThemeLocked(selection) {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(.black.opacity(0.45), in: .circle)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                            .padding(4)
                    }
                }
                .frame(height: 48)
                .overlay(
                    RoundedRectangle(cornerRadius: Design.tileCornerRadius)
                        .strokeBorder(isSelected ? theme.accent : .clear, lineWidth: 2)
                )

                Text(displayName)
                    .font(.caption)
                    .foregroundStyle(isSelected ? theme.accent : theme.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .animation(Design.snappy, value: isSelected)
        .accessibilityLabel(accessibilityText)
    }

    private var displayName: String {
        selection == .festivus ? "Festivus · \(Holiday.current().displayName)" : selection.displayName
    }

    private var accessibilityText: String {
        var text = "\(displayName) theme"
        if isSelected { text += ", selected" }
        if model.isThemeLocked(selection) { text += ", requires Premium" }
        return text
    }

    private func select() {
        model.selectTheme(selection)
    }
}
