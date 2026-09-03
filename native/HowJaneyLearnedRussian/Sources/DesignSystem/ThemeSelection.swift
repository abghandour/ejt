import Foundation

/// What the user picks in Settings. `festivus` resolves to a holiday variant at runtime.
nonisolated enum ThemeSelection: String, CaseIterable, Identifiable, Sendable {
    case korni, soviet, brazil, ukraine, dark, light, bw, festivus

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .korni: "Korni"
        case .soviet: "Soviet"
        case .brazil: "Brazil"
        case .ukraine: "Ukraine"
        case .dark: "Dark"
        case .light: "Light"
        case .bw: "Mono"
        case .festivus: "Festivus"
        }
    }

    /// Resolves to the concrete theme, applying the holiday rotation for festivus.
    func resolved(on date: Date = .now) -> Theme {
        switch self {
        case .festivus: ThemeCatalog.festivus(for: Holiday.current(on: date))
        default: ThemeCatalog.theme(id: rawValue) ?? ThemeCatalog.korni
        }
    }
}
