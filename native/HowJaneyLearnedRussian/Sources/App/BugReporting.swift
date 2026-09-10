import BugReporterKit
import Foundation
import GameKit
import SwiftUI

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
        config.performance = PerformanceConfig(sampleInterval: 1, maxDuration: 600, builtIn: .all)
        BugReporter.configure(config)
        registerMetrics()
    }

    // MARK: - Performance metrics

    /// The metrics Janey reports during a performance capture, on top of the
    /// kit's CPU, memory, main-thread stall, frame hitch and thermal samplers.
    /// Names are stable: the viewer compares captures by them.
    enum Metric {
        static let dictionaryLoad = "dictionary.load_ms"
        static let speech = "speech.speak_ms"
        static let soundEffects = "sound.effects"
        static let statsRecord = "stats.record_ms"
        static let wordBookRecord = "wordbook.record_ms"
        static let wordBookWords = "wordbook.words_recorded"
    }

    private static func registerMetrics() {
        BugReporter.metrics.register(
            timer: Metric.dictionaryLoad, description: "Loading and validating a game dictionary")
        BugReporter.metrics.register(
            timer: Metric.speech, description: "Preparing an utterance and handing it to the synthesizer")
        BugReporter.metrics.register(
            counter: Metric.soundEffects, unit: "plays", description: "Sound effects scheduled")
        BugReporter.metrics.register(
            timer: Metric.statsRecord, description: "Saving a game result and its stats")
        BugReporter.metrics.register(
            timer: Metric.wordBookRecord, description: "Recording a round's words in the word book")
        BugReporter.metrics.register(
            counter: Metric.wordBookWords, unit: "words", description: "Words written to the word book")
    }

    /// Marks the game lifecycle on the capture timeline so spikes can be read
    /// against what the tester was doing. A game session is a span.
    @MainActor
    static func gameChanged(from old: GameID?, to new: GameID?) {
        if let old {
            BugReporter.metrics.end(span: "game.\(old.rawValue)")
            BugReporter.metrics.mark("left \(old.rawValue)")
        }
        if let new {
            BugReporter.metrics.mark("opened \(new.rawValue)")
            BugReporter.metrics.begin(span: "game.\(new.rawValue)")
        }
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

extension BugReporting {
    /// The QA mode button and the sheet it opens live in their own window, so
    /// they inherit none of `RootView`'s environment. Hand the kit the same
    /// tint and body font `RootView` applies, and call this again whenever the
    /// theme changes.
    @MainActor
    static func applyTheme(_ theme: Theme) {
        BugReporter.setQAOverlayStyle(
            tint: theme.accent,
            font: theme.bodyFontName.map { .custom($0, size: 17, relativeTo: .body) }
        )
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
