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

    private var loadedImage: UIImage? {
        guard let url = Bundle.main.url(
            forResource: (imageName as NSString).deletingPathExtension,
            withExtension: (imageName as NSString).pathExtension,
            subdirectory: "TriviaImages/\(languageID)"
        ) else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}
