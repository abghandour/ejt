import Testing
@testable import HowJaneyLearnedRussian

struct DictionaryValidationTests {
    private let russian = try? Regex("^[а-яёА-ЯЁ]+$")

    @Test
    func acceptsValidEntry() {
        let entry = WordEntry(word: "кот", translation: "cat")
        #expect(DictionaryStore.isValidEntry(entry, regex: russian))
    }

    @Test
    func rejectsTooShortAndTooLong() {
        #expect(!DictionaryStore.isValidEntry(WordEntry(word: "ко", translation: "x"), regex: russian))
        #expect(!DictionaryStore.isValidEntry(WordEntry(word: "переучёный", translation: "x"), regex: russian))
    }

    @Test
    func rejectsEmptyTranslation() {
        #expect(!DictionaryStore.isValidEntry(WordEntry(word: "кот", translation: "  "), regex: russian))
    }

    @Test
    func rejectsNonMatchingScript() {
        #expect(!DictionaryStore.isValidEntry(WordEntry(word: "cat", translation: "кот"), regex: russian))
    }

    @Test
    func wordMapIsLowercased() {
        let dictionary = WordDictionary(entries: [WordEntry(word: "Кот", translation: "cat")])
        #expect(dictionary.wordMap["кот"] == "cat")
    }

    @Test
    func languageCatalogLoadsBundledRegistry() {
        let languages = LanguageCatalog.load(from: .main)
        #expect(languages.contains { $0.id == "ru" })
        #expect(languages.first?.id == "ru")
        let russian = languages.first { $0.id == "ru" }
        #expect(russian?.games.contains("bogglesky") == true)
        #expect(russian?.themes.first == "korni")
    }
}
