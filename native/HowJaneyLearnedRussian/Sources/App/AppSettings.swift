import Foundation
import Observation

/// User preferences, stored in UserDefaults and mirrored to iCloud key-value
/// storage so they roam across the user's devices (the old `user_settings` table).
@Observable
final class AppSettings {
    private enum Key {
        static let language = "settings.language"
        static let theme = "settings.theme"
        static let sound = "settings.sound"
        static let haptics = "settings.haptics"
        static let displayName = "settings.displayName"
    }

    var languageID: String {
        didSet { save(languageID, forKey: Key.language) }
    }

    var themeSelection: ThemeSelection {
        didSet { save(themeSelection.rawValue, forKey: Key.theme) }
    }

    var soundEnabled: Bool {
        didSet { save(soundEnabled, forKey: Key.sound) }
    }

    var hapticsEnabled: Bool {
        didSet { save(hapticsEnabled, forKey: Key.haptics) }
    }

    /// Local display name, used when Game Center hasn't provided one.
    var displayName: String {
        didSet { save(displayName, forKey: Key.displayName) }
    }

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let cloud: NSUbiquitousKeyValueStore
    @ObservationIgnored private var observer: (any NSObjectProtocol)?

    init(defaults: UserDefaults = .standard, cloud: NSUbiquitousKeyValueStore = .default) {
        self.defaults = defaults
        self.cloud = cloud

        // Cloud value wins on first launch of a new device; local wins after.
        func stored(_ key: String) -> Any? {
            defaults.object(forKey: key) ?? cloud.object(forKey: key)
        }

        languageID = stored(Key.language) as? String ?? LanguageCatalog.fallbackLanguageID
        themeSelection = (stored(Key.theme) as? String).flatMap(ThemeSelection.init) ?? .soviet
        soundEnabled = stored(Key.sound) as? Bool ?? true
        hapticsEnabled = stored(Key.haptics) as? Bool ?? true
        displayName = stored(Key.displayName) as? String ?? ""

        cloud.synchronize()
        observer = NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: cloud,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.pullFromCloud()
            }
        }
    }

    private func save(_ value: Any, forKey key: String) {
        defaults.set(value, forKey: key)
        cloud.set(value, forKey: key)
    }

    private func pullFromCloud() {
        if let value = cloud.object(forKey: Key.language) as? String, value != languageID {
            languageID = value
        }
        if let value = (cloud.object(forKey: Key.theme) as? String).flatMap(ThemeSelection.init),
           value != themeSelection {
            themeSelection = value
        }
        if let value = cloud.object(forKey: Key.sound) as? Bool, value != soundEnabled {
            soundEnabled = value
        }
        if let value = cloud.object(forKey: Key.haptics) as? Bool, value != hapticsEnabled {
            hapticsEnabled = value
        }
        if let value = cloud.object(forKey: Key.displayName) as? String, value != displayName {
            displayName = value
        }
    }
}
