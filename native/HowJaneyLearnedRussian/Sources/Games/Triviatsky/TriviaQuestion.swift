import Foundation

/// One trivia question, mirroring the JSON schema in
/// Dictionaries/<lang>/triviatsky.json. Russian entries carry `category`/`hint`;
/// pt-br/uk entries carry translations, optional images, and per-question timers.
nonisolated struct TriviaQuestion: Hashable, Sendable {
    let question: String
    let answers: [String]
    let correctIndex: Int
    let category: String?
    let hint: String?
    let questionTranslation: String?
    let answerTranslations: [String]?
    let image: String?
    let postAnswerImage: String?
    let timerSeconds: Int?

    /// Validation ported from triviatsky.html `validateQuestion`.
    var isValid: Bool {
        guard !question.trimmingCharacters(in: .whitespaces).isEmpty else { return false }
        guard (2...6).contains(answers.count) else { return false }
        guard answers.allSatisfy({ !$0.trimmingCharacters(in: .whitespaces).isEmpty }) else { return false }
        return (0..<answers.count).contains(correctIndex)
    }

    var hasTranslations: Bool {
        questionTranslation != nil || answerTranslations?.count == answers.count
    }

    /// SF Symbol for the category badge.
    var categorySymbol: String {
        switch category {
        case "Grammar": "textformat"
        case "History": "clock.arrow.circlepath"
        case "Literature": "book"
        case "Geography": "globe.europe.africa.fill"
        case "Pop Culture": "film"
        case "Famous Russians": "person.fill"
        case "Idioms": "quote.bubble"
        case "Vocabulary": "character.book.closed"
        case "Holidays & Traditions": "party.popper"
        default: "questionmark.circle"
        }
    }

    /// Bundled image name, mapped from the web-relative path
    /// (e.g. "../shared/assets/triviatsky/uk/kyiv.jpg" → "kyiv.jpg").
    var bundledImageName: String? {
        guard let image else { return nil }
        return image.split(separator: "/").last.map(String.init)
    }
}

nonisolated extension TriviaQuestion: Decodable {
    private enum CodingKeys: String, CodingKey {
        case question, answers, correctIndex, category, hint
        case questionTranslation, answerTranslations, image, postAnswerImage, timerSeconds
    }

    /// Lenient decoding matching the web's validateQuestion-and-skip behavior:
    /// a malformed `correctIndex` (e.g. null in the shipped Russian data) makes
    /// the question invalid instead of failing the whole file.
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        question = try container.decodeIfPresent(String.self, forKey: .question) ?? ""
        answers = try container.decodeIfPresent([String].self, forKey: .answers) ?? []
        correctIndex = (try? container.decodeIfPresent(Int.self, forKey: .correctIndex)) ?? -1
        category = try container.decodeIfPresent(String.self, forKey: .category)
        hint = try container.decodeIfPresent(String.self, forKey: .hint)
        questionTranslation = try container.decodeIfPresent(String.self, forKey: .questionTranslation)
        answerTranslations = try container.decodeIfPresent([String].self, forKey: .answerTranslations)
        image = try container.decodeIfPresent(String.self, forKey: .image)
        postAnswerImage = try container.decodeIfPresent(String.self, forKey: .postAnswerImage)
        timerSeconds = try container.decodeIfPresent(Int.self, forKey: .timerSeconds)
    }
}
