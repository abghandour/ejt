import SwiftUI

/// A complete visual token set, mirroring the CSS custom properties in
/// web/shared/theme.css. Adding a theme means adding one `Theme` value to
/// `ThemeCatalog` — every view reads tokens from the environment.
nonisolated struct Theme: Identifiable, Sendable {
    let id: String
    let name: String
    /// Drives system chrome (status bar, glass) via `preferredColorScheme`.
    let isDark: Bool

    let bgPrimary: Color
    let bgSecondary: Color
    let surface: Color

    let textPrimary: Color
    let textSecondary: Color
    let textMuted: Color

    let accent: Color
    let info: Color
    let success: Color
    let successText: Color
    let danger: Color
    let dangerText: Color

    let tileTop: Color
    let tileBottom: Color
    let tileBorder: Color
    let tileSelectedTop: Color
    let tileSelectedBottom: Color
    let correctTop: Color
    let correctBottom: Color
    let correctBorder: Color
    let wrongTop: Color
    let wrongBottom: Color
    let wrongBorder: Color

    let playTop: Color
    let playBottom: Color
    let playBorder: Color

    let sunburst1: Color
    let sunburst2: Color
    let sunburstOpacity: Double

    var accentGlow: Color { accent.opacity(0.35) }
    var tileGradient: LinearGradient {
        LinearGradient(colors: [tileTop, tileBottom], startPoint: .top, endPoint: .bottom)
    }
    var tileSelectedGradient: LinearGradient {
        LinearGradient(colors: [tileSelectedTop, tileSelectedBottom], startPoint: .top, endPoint: .bottom)
    }
    var correctGradient: LinearGradient {
        LinearGradient(colors: [correctTop, correctBottom], startPoint: .top, endPoint: .bottom)
    }
    var wrongGradient: LinearGradient {
        LinearGradient(colors: [wrongTop, wrongBottom], startPoint: .top, endPoint: .bottom)
    }
    var playGradient: LinearGradient {
        LinearGradient(colors: [playTop, playBottom], startPoint: .top, endPoint: .bottom)
    }
}

extension EnvironmentValues {
    @Entry var theme: Theme = ThemeCatalog.soviet
}
