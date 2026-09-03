import Foundation

/// Compile-time switches for features that exist in code but are not ready to ship.
nonisolated enum FeatureFlags {
    /// The app ships as Russian-only for now; flip to re-surface the language
    /// picker (Home menu + Settings section) and multi-language paywall copy.
    static let multiLanguage = false
}
