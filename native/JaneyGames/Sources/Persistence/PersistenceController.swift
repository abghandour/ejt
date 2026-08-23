import Foundation
import SwiftData

/// Builds the model container: CloudKit-mirrored when the entitlement/account
/// allow it, plain local storage otherwise, in-memory as a last resort.
nonisolated enum PersistenceController {
    static func makeContainer() -> ModelContainer {
        let schema = Schema([
            GameResultRecord.self, GameStatsRecord.self, DailyStateRecord.self, LearnedWordRecord.self,
        ])

        if let cloud = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .automatic)]
        ) {
            return cloud
        }
        if let local = try? ModelContainer(
            for: schema,
            configurations: [ModelConfiguration(schema: schema, cloudKitDatabase: .none)]
        ) {
            return local
        }
        do {
            return try ModelContainer(
                for: schema,
                configurations: [ModelConfiguration(schema: schema, isStoredInMemoryOnly: true, cloudKitDatabase: .none)]
            )
        } catch {
            fatalError("Unable to create any model container: \(error)")
        }
    }
}
