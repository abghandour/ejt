import Foundation
import SwiftData

/// Records finished rounds and maintains aggregates, porting the streak logic
/// from the Supabase trigger: same day → unchanged, consecutive day → +1,
/// otherwise reset to 1.
@Observable
final class StatsService {
    private let context: ModelContext

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
    }

    func stats(game: GameID, languageID: String) -> GameStatsRecord? {
        let gameID = game.rawValue
        let descriptor = FetchDescriptor<GameStatsRecord>(
            predicate: #Predicate { $0.game == gameID && $0.languageID == languageID }
        )
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
