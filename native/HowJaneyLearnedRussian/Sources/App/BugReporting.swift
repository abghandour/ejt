import BugReporterKit
import Foundation
import GameKit

/// Everything this app tells VerticalCorn about itself.
///
/// The kit is anonymous by default: nothing here reads the Apple Account, the
/// device name, or Game Center unless the tester ticks the box in the sheet.
enum BugReporting {

    /// Read once at launch from the generated Info.plist, which gets them from
    /// the gitignored `Configuration/Secrets.xcconfig`.
    static var ingestKey: String {
        Bundle.main.object(forInfoDictionaryKey: "BugReportIngestKey") as? String ?? ""
    }

    /// Stored without a scheme because `//` starts a comment in an xcconfig.
    static var endpoint: URL {
        let host = Bundle.main.object(forInfoDictionaryKey: "BugReportHost") as? String ?? ""
        return URL(string: "https://\(host)") ?? URL(string: "https://invalid.invalid")!
    }

    /// `Application Support/HowJaneyLearnedRussian/Logs`: the kit owns this
    /// folder (`app.log`, `app.log.1`, `crashes/`, `outbox/`).
    static var logDirectory: URL {
        URL.applicationSupportDirectory
            .appending(path: "HowJaneyLearnedRussian/Logs", directoryHint: .isDirectory)
    }

    static func configure() {
        var config = BugReporterConfig(
            appID: "janey",
            ingestKey: ingestKey,
            endpoint: endpoint,
            logDirectory: logDirectory
        )
        config.identity = .optional
        config.attachmentSources = [.files, .photos]
        config.contextProvider = { BugReportContext.shared.snapshot() }
        config.gameCenterProvider = {
            // Only when the tester has already signed in and has ticked
            // "Include Game Center info" in the sheet.
            let player = GKLocalPlayer.local
            guard player.isAuthenticated else { return nil }
            return GameCenterInfo(
                displayName: player.displayName,
                teamPlayerID: player.teamPlayerID,
                alias: player.alias
            )
        }
        BugReporter.configure(config)
    }
}

/// A thread-safe snapshot of "where was the tester when this happened".
///
/// `contextProvider` is called from whatever thread is sending the report, and
/// `AppModel` is main-actor state, so the UI pushes a plain string dictionary
/// in here instead of the kit reaching into the model.
nonisolated final class BugReportContext: @unchecked Sendable {
    static let shared = BugReportContext()

    private let lock = NSLock()
    private var values: [String: String] = [:]

    private init() {}

    func snapshot() -> [String: String] {
        lock.lock()
        defer { lock.unlock() }
        return values
    }

    func update(_ newValues: [String: String]) {
        lock.lock()
        values = newValues
        lock.unlock()
    }
}

extension AppModel {
    /// Called whenever the language, the open game, or the visible sheet
    /// changes, so a report carries the state the tester was actually looking
    /// at rather than the state at launch.
    func publishBugReportContext() {
        BugReportContext.shared.update([
            "language": settings.languageID,
            "hubScreen": hubScreen,
            "gameMode": activeGame?.rawValue ?? "none",
            "premium": store.isPremium ? "yes" : "no",
            "flag.multiLanguage": FeatureFlags.multiLanguage ? "on" : "off",
        ])
    }

    /// Which part of the hub is in front of the tester.
    private var hubScreen: String {
        if activeGame != nil { return "game" }
        if isShowingSettings { return "settings" }
        if isShowingProfile { return "profile" }
        if isShowingWordBook { return "wordBook" }
        if isShowingPaywall { return "paywall" }
        return "home"
    }
}
