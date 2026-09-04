import SwiftUI

/// Question image loaded from the bundled TriviaImages/<lang>/ folder.
/// Renders nothing when the asset isn't bundled, matching the web's
/// silent `onerror` fallback.
struct TriviaImageView: View {
    @Environment(\.theme) private var theme
    let imageName: String
    let languageID: String

    var body: some View {
        if let image = loadedImage {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 400, maxHeight: 200)
                .clipShape(.rect(cornerRadius: Design.tileCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.tileCornerRadius)
                        .strokeBorder(theme.tileBorder, lineWidth: 1)
                )
                .accessibilityLabel("Question image")
        }
    }

    /// Decoded images keyed by "<lang>/<name>"; the card re-renders on every
    /// answer tap, so without this each render re-read and re-decoded the file.
    private static let cache = NSCache<NSString, UIImage>()

    private var loadedImage: UIImage? {
        let key = "\(languageID)/\(imageName)" as NSString
        if let cached = Self.cache.object(forKey: key) { return cached }
        guard let url = Bundle.main.url(
            forResource: (imageName as NSString).deletingPathExtension,
            withExtension: (imageName as NSString).pathExtension,
            subdirectory: "TriviaImages/\(languageID)"
        ), let image = UIImage(contentsOfFile: url.path) else { return nil }
        Self.cache.setObject(image, forKey: key)
        return image
    }
}
