import Foundation
import SwiftData

/// Load/save daily game state blobs, generic over the per-game state type.
@Observable
final class DailyStateService {
    private let context: ModelContext

    init(container: ModelContainer) {
        context = container.mainContext
    }

    func load<State: Decodable>(_ type: State.Type, game: GameID, languageID: String, dateKey: String) -> State? {
        guard let record = record(game: game, languageID: languageID, dateKey: dateKey) else { return nil }
        return try? JSONDecoder().decode(State.self, from: record.stateJSON)
    }

    func save(_ state: some Encodable, game: GameID, languageID: String, dateKey: String, completed: Bool) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        if let record = record(game: game, languageID: languageID, dateKey: dateKey) {
            record.stateJSON = data
            record.completed = completed
            record.updatedAt = .now
        } else {
            context.insert(
                DailyStateRecord(
                    game: game.rawValue,
                    languageID: languageID,
                    dateKey: dateKey,
                    stateJSON: data,
                    completed: completed
                )
            )
        }
        try? context.save()
    }

    /// Date keys of completed days — powers calendar "played" marks and streaks.
    func completedDateKeys(game: GameID, languageID: String) -> Set<String> {
        let gameID = game.rawValue
        let descriptor = FetchDescriptor<DailyStateRecord>(
            predicate: #Predicate { $0.game == gameID && $0.languageID == languageID && $0.completed }
        )
        return Set(((try? context.fetch(descriptor)) ?? []).map(\.dateKey))
    }

    /// Decoded states of every completed day (e.g. trivia category mastery).
    func allCompletedStates<State: Decodable>(
        _ type: State.Type,
        game: GameID,
        languageID: String
    ) -> [String: State] {
        let gameID = game.rawValue
        let descriptor = FetchDescriptor<DailyStateRecord>(
            predicate: #Predicate { $0.game == gameID && $0.languageID == languageID && $0.completed }
        )
        var result: [String: State] = [:]
        for record in (try? context.fetch(descriptor)) ?? [] {
            if let state = try? JSONDecoder().decode(State.self, from: record.stateJSON) {
                result[record.dateKey] = state
            }
        }
        return result
    }

    /// Completed and in-progress date keys in one pass (calendar coloring).
    func progressDateKeys(game: GameID, languageID: String) -> (completed: Set<String>, inProgress: Set<String>) {
        let gameID = game.rawValue
        let descriptor = FetchDescriptor<DailyStateRecord>(
            predicate: #Predicate { $0.game == gameID && $0.languageID == languageID }
        )
        let records = (try? context.fetch(descriptor)) ?? []
        var completed: Set<String> = []
        var inProgress: Set<String> = []
        for record in records {
            if record.completed {
                completed.insert(record.dateKey)
            } else {
                inProgress.insert(record.dateKey)
            }
        }
        return (completed, inProgress)
    }

    private func record(game: GameID, languageID: String, dateKey: String) -> DailyStateRecord? {
        let gameID = game.rawValue
        let descriptor = FetchDescriptor<DailyStateRecord>(
            predicate: #Predicate { $0.game == gameID && $0.languageID == languageID && $0.dateKey == dateKey }
        )
        return try? context.fetch(descriptor).first
    }
}
