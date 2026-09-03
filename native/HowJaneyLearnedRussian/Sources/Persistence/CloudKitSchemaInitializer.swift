#if DEBUG
import CloudKit
import CoreData
import Foundation
import SwiftData

/// Debug-only helper that pushes the full SwiftData schema to the CloudKit
/// **Development** environment without needing any records to be written.
///
/// Launch the app with `--init-cloudkit-schema` on a device signed into iCloud,
/// then deploy the schema to Production in CloudKit Console.
nonisolated enum CloudKitSchemaInitializer {
    static let launchArgument = "--init-cloudkit-schema"
    static let containerIdentifier = "iCloud.com.mokotti-solutions.howjaneylearnedrussian"

    static let modelTypes: [any PersistentModel.Type] = [
        GameResultRecord.self, GameStatsRecord.self, DailyStateRecord.self, LearnedWordRecord.self,
    ]

    /// Returns `true` if the argument was present (whether or not the push succeeded).
    @discardableResult
    static func runIfRequested() -> Bool {
        guard CommandLine.arguments.contains(launchArgument) else { return false }
        do {
            guard let model = NSManagedObjectModel.makeManagedObjectModel(for: modelTypes) else {
                print("[CloudKitSchema] could not derive managed object model")
                return true
            }
            let storeURL = URL.temporaryDirectory.appending(path: "cloudkit-schema-init.sqlite")
            try? FileManager.default.removeItem(at: storeURL)

            let description = NSPersistentStoreDescription(url: storeURL)
            description.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: containerIdentifier
            )
            let container = NSPersistentCloudKitContainer(name: "CloudKitSchemaInit", managedObjectModel: model)
            container.persistentStoreDescriptions = [description]
            container.loadPersistentStores { _, error in
                if let error { print("[CloudKitSchema] store load failed: \(error)") }
            }
            try container.initializeCloudKitSchema(options: [])
            print("[CloudKitSchema] schema pushed to CloudKit Development for \(containerIdentifier)")
        } catch {
            print("[CloudKitSchema] failed: \(error)")
        }
        return true
    }
}
#endif
