import Foundation
import Observation
import SwiftData

/// Root app state: catalogs, services, active selections, and premium gating.
@Observable
final class AppModel {
    let languages: [Language]
    let settings: AppSettings
    let soundEngine: SoundEngine
    let dictionaryStore: DictionaryStore
    let triviaStore: TriviaStore
    let rootskyStore: RootskyStore
    let wordskyStore: RootskyStore
    let slashskyStore: SlashskyStore
    let speech: SpeechService
    let gameCenter: GameCenterService
    let store: StoreService
    let stats: StatsService
    let dailyState: DailyStateService
    let wordBook: WordBookService
    let achievements: AchievementService
    let streakReminder: StreakReminderService

    var activeGame: GameID?
    var isShowingSettings = false
    var isShowingPaywall = false
    var isShowingProfile = false
    var isShowingWordBook = false

    /// Game Center name wins; otherwise the user's local name; otherwise "Player".
    var displayName: String {
        if let gcName = gameCenter.playerName, !gcName.isEmpty {
            return gcName
        }
        let local = settings.displayName.trimmingCharacters(in: .whitespaces)
        return local.isEmpty ? "Player" : local
    }

    init(container: ModelContainer) {
        languages = LanguageCatalog.load()
        settings = AppSettings()
        soundEngine = SoundEngine()
        dictionaryStore = DictionaryStore()
        triviaStore = TriviaStore()
        rootskyStore = RootskyStore()
        wordskyStore = RootskyStore(resource: "wordsky")
        slashskyStore = SlashskyStore()
        speech = SpeechService()
        gameCenter = GameCenterService()
        store = StoreService()
        stats = StatsService(container: container)
        dailyState = DailyStateService(container: container)
        wordBook = WordBookService(container: container)
        achievements = AchievementService()
        streakReminder = StreakReminderService()
        soundEngine.isEnabled = settings.soundEnabled
    }

    var language: Language {
        languages.first { $0.id == settings.languageID }
            ?? languages.first
            ?? Language(
                id: "ru", displayName: "Russian", games: [], themes: ["soviet"],
                letterPool: "абв", validationRegex: ".*", gameNames: [:]
            )
    }

    var theme: Theme {
        settings.themeSelection.resolved()
    }

    var games: [GameInfo] {
        GameInfo.games(for: language)
    }

    /// Themes offered for the current language, in languages.json order.
    var availableThemes: [ThemeSelection] {
        language.themes.compactMap(ThemeSelection.init)
    }

    // MARK: - Premium gating (adjust here as the offering evolves)

    func isLanguageLocked(_ language: Language) -> Bool {
        language.id != LanguageCatalog.fallbackLanguageID && !store.isPremium
    }

    func isThemeLocked(_ selection: ThemeSelection) -> Bool {
        selection == .festivus && !store.isPremium
    }

    func selectLanguage(_ language: Language) {
        if isLanguageLocked(language) {
            isShowingPaywall = true
            return
        }
        settings.languageID = language.id
        // Keep the theme valid for the newly selected language.
        if !language.themes.contains(settings.themeSelection.rawValue),
           let first = language.themes.first,
           let fallback = ThemeSelection(rawValue: first) {
            settings.themeSelection = fallback
        }
    }

    func selectTheme(_ selection: ThemeSelection) {
        if isThemeLocked(selection) {
            isShowingPaywall = true
            return
        }
        settings.themeSelection = selection
    }

    func setSoundEnabled(_ enabled: Bool) {
        settings.soundEnabled = enabled
        soundEngine.isEnabled = enabled
    }

    // MARK: - Round completion

    /// Lifetime XP across every game and language.
    var totalXP: Int {
        stats.allStats().reduce(0) { $0 + $1.totalScore }
    }

    var rank: Rank {
        Rank.rank(forXP: totalXP)
    }

    /// Shared post-round bookkeeping: streak achievements + reminder refresh.
    private func afterRound(game: GameID, languageID: String) {
        if let record = stats.stats(game: game, languageID: languageID) {
            achievements.reportStreak(record.bestStreak)
        }
        streakReminder.refresh(stats: stats, languageID: language.id)
    }

    func refreshStreakReminder() {
        streakReminder.refresh(stats: stats, languageID: language.id)
    }

    /// Rootsky and Wordsky share the same completion shape.
    func finishedDailyWordGame(_ result: RootskyResult) {
        stats.record(
            game: result.game,
            languageID: result.languageID,
            difficulty: nil,
            score: result.score,
            wordsCompleted: RootskyModel.wordsPerDay
        )
        gameCenter.submit(
            score: result.score,
            game: result.game,
            languageID: result.languageID,
            difficulty: nil
        )
        wordBook.record(
            words: result.words.map { ($0.word, $0.translation) },
            languageID: result.languageID,
            game: result.game
        )
        if result.game == .rootsky, result.score == RootskyModel.maxScore {
            achievements.report(.perfectRootsky)
        }
        afterRound(game: result.game, languageID: result.languageID)
    }

    func finishedSlashsky(_ result: SlashskyResult) {
        stats.record(
            game: .slashsky,
            languageID: result.languageID,
            difficulty: nil,
            score: result.score,
            wordsCompleted: result.wordsCompleted
        )
        gameCenter.submit(
            score: result.score,
            game: .slashsky,
            languageID: result.languageID,
            difficulty: nil
        )
        wordBook.record(
            words: result.words.map { ($0.word, $0.translation) },
            languageID: result.languageID,
            game: .slashsky
        )
        afterRound(game: .slashsky, languageID: result.languageID)
    }

    func finishedSnakesky(_ result: SnakeskyResult) {
        stats.record(
            game: .snakesky,
            languageID: result.languageID,
            difficulty: result.difficulty.rawValue,
            score: result.score,
            wordsCompleted: result.wordsCompleted
        )
        gameCenter.submit(
            score: result.score,
            game: .snakesky,
            languageID: result.languageID,
            difficulty: result.difficulty.rawValue
        )
        wordBook.record(
            words: result.words.map { ($0.word, $0.translation) },
            languageID: result.languageID,
            game: .snakesky
        )
        afterRound(game: .snakesky, languageID: result.languageID)
    }

    func finishedTetrisky(_ result: TetriskyResult) {
        stats.record(
            game: .tetrisky,
            languageID: result.languageID,
            difficulty: result.difficulty.rawValue,
            score: result.score,
            wordsCompleted: result.wordsCompleted
        )
        gameCenter.submit(
            score: result.score,
            game: .tetrisky,
            languageID: result.languageID,
            difficulty: result.difficulty.rawValue
        )
        wordBook.record(
            words: result.words.filter { !$0.translation.isEmpty }.map { ($0.word, $0.translation) },
            languageID: result.languageID,
            game: .tetrisky
        )
        afterRound(game: .tetrisky, languageID: result.languageID)
    }

    func finishedScramblisky(_ result: ScramblisyResult) {
        stats.record(
            game: .scramblisky,
            languageID: result.languageID,
            difficulty: result.difficulty.rawValue,
            score: result.score,
            wordsCompleted: result.wordsCompleted
        )
        gameCenter.submit(
            score: result.score,
            game: .scramblisky,
            languageID: result.languageID,
            difficulty: result.difficulty.rawValue
        )
        wordBook.record(
            words: result.words.map { ($0.word, $0.translation) },
            languageID: result.languageID,
            game: .scramblisky
        )
        if result.wordsCompleted >= 10 {
            achievements.report(.scrambleTen)
        }
        afterRound(game: .scramblisky, languageID: result.languageID)
    }

    func finishedTriviatsky(_ result: TriviatskyResult) {
        stats.record(
            game: .triviatsky,
            languageID: result.languageID,
            difficulty: nil,
            score: result.score,
            wordsCompleted: result.questionCount
        )
        gameCenter.submit(
            score: result.score,
            game: .triviatsky,
            languageID: result.languageID,
            difficulty: nil
        )
        if result.score == result.maxScore {
            achievements.report(.perfectTrivia)
        }
        afterRound(game: .triviatsky, languageID: result.languageID)
    }

    func finishedBogglesky(_ result: BoggleskyResult) {
        stats.record(
            game: .bogglesky,
            languageID: result.languageID,
            difficulty: result.difficulty.rawValue,
            score: result.score,
            wordsCompleted: result.wordsFound
        )
        gameCenter.submit(
            score: result.score,
            game: .bogglesky,
            languageID: result.languageID,
            difficulty: result.difficulty.rawValue
        )
        wordBook.record(
            words: result.words.map { ($0.word, $0.translation) },
            languageID: result.languageID,
            game: .bogglesky
        )
        if result.clearedBoards > 0 {
            achievements.report(.boardClear)
        }
        afterRound(game: .bogglesky, languageID: result.languageID)
    }
}
