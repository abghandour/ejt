import Foundation
import SwiftData

/// Records finished rounds and maintains aggregates, porting the streak logic
/// from the Supabase trigger: same day → unchanged, consecutive day → +1,
/// otherwise reset to 1.
@Observable
final class StatsService {
    struct TodayProgress {
        let rounds: Int
        let distinctGames: Int
    }

    private let context: ModelContext
    private(set) var revision = 0

    init(container: ModelContainer) {
        context = container.mainContext
    }

    func record(game: GameID, languageID: String, difficulty: String?, score: Int, wordsCompleted: Int) {
        context.insert(
            GameResultRecord(
                game: game.rawValue,
                languageID: languageID,
                difficulty: difficulty,
                score: score,
                wordsCompleted: wordsCompleted
            )
        )
        updateStats(game: game, languageID: languageID, score: score)
        try? context.save()
        revision += 1
    }

    func todayProgress(languageID: String) -> TodayProgress {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: .now)
        let descriptor = FetchDescriptor<GameResultRecord>(
            predicate: #Predicate { $0.languageID == languageID && $0.playedAt >= startOfToday }
        )
        let today = (try? context.fetch(descriptor)) ?? []
        let games = Set(today.compactMap { GameID(rawValue: $0.game) })

        return TodayProgress(
            rounds: today.count,
            distinctGames: games.count
        )
    }

    func stats(game: GameID, languageID: String) -> GameStatsRecord? {
        let gameID = game.rawValue
        var descriptor = FetchDescriptor<GameStatsRecord>(
            predicate: #Predicate { $0.game == gameID && $0.languageID == languageID }
        )
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    func allStats() -> [GameStatsRecord] {
        let descriptor = FetchDescriptor<GameStatsRecord>(
            sortBy: [SortDescriptor(\.game), SortDescriptor(\.languageID)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    private func updateStats(game: GameID, languageID: String, score: Int) {
        let record = stats(game: game, languageID: languageID) ?? {
            let new = GameStatsRecord(game: game.rawValue, languageID: languageID)
            context.insert(new)
            return new
        }()

        record.gamesPlayed += 1
        record.bestScore = max(record.bestScore, score)
        record.totalScore += score

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        if let last = record.lastPlayed {
            let lastDay = calendar.startOfDay(for: last)
            let dayGap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if dayGap == 1 {
                record.currentStreak += 1
            } else if dayGap != 0 {
                record.currentStreak = 1
            }
        } else {
            record.currentStreak = 1
        }
        record.bestStreak = max(record.bestStreak, record.currentStreak)
        record.lastPlayed = .now
    }
}
