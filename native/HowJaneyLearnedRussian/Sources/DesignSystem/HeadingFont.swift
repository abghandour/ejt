import CoreText
import SwiftUI

/// Display typography for game names and screen titles.
///
/// Themes without a custom face get the system rounded bold font with the
/// requested letter-spacing. Themes that bundle a display face (Soviet uses
/// Russo One) get that face instead at the matching Dynamic Type size, with
/// a little room to shrink so long names like "SCRAMBLISKY" stay on one line.
struct HeadingTextModifier: ViewModifier {
    @Environment(\.theme) private var theme
    let style: Font.TextStyle
    let kerning: Double

    func body(content: Content) -> some View {
        if let name = theme.headingFontName {
            content
                .font(.custom(name, size: Self.customSize(for: style), relativeTo: style))
                .kerning(kerning * 0.5)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        } else {
            content
                .font(.system(style, design: .rounded))
                .bold()
                .kerning(kerning)
        }
    }

    /// Point sizes for the custom face, matching the system text style defaults.
    private static func customSize(for style: Font.TextStyle) -> Double {
        switch style {
        case .largeTitle: 34
        case .title: 28
        case .title2: 22
        case .title3: 20
        case .headline: 17
        case .subheadline: 15
        case .footnote: 13
        case .caption: 12
        case .caption2: 11
        default: 17
        }
    }
}

extension View {
    /// Styles a header (game name, screen title) with the current theme's
    /// display face. `kerning` applies in full to the system-font fallback and
    /// at half strength to the custom face, which is already wide.
    func heading(_ style: Font.TextStyle, kerning: Double = 0) -> some View {
        modifier(HeadingTextModifier(style: style, kerning: kerning))
    }
}

/// Registers the fonts bundled under `Resources/Fonts` with CoreText so
/// `Font.custom` can resolve them without an Info.plist `UIAppFonts` entry.
enum FontRegistrar {
    static func registerBundledFonts() {
        let urls = Bundle.main.urls(forResourcesWithExtension: "ttf", subdirectory: "Fonts") ?? []
        for url in urls {
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error),
               let error = error?.takeRetainedValue() {
                // Already registered (e.g. previews) or corrupt; either way not fatal.
                print("Font registration skipped for \(url.lastPathComponent): \(error.localizedDescription)")
            }
        }
    }
}
