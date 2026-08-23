import Foundation
import Observation
import UserNotifications

/// Schedules a quiet evening reminder when a daily-game streak is about to
/// break. Uses provisional authorization (delivered silently, no prompt).
@Observable
final class StreakReminderService {
    nonisolated static let identifier = "streak-reminder"
    nonisolated static let reminderHour = 20

    @ObservationIgnored private var requestedAuthorization = false

    /// Recomputes the pending reminder from current stats. Call on foreground
    /// and after finishing a daily game.
    func refresh(stats: StatsService, languageID: String) {
        let center = UNUserNotificationCenter.current()
        if !requestedAuthorization {
            requestedAuthorization = true
            center.requestAuthorization(options: [.alert, .sound, .provisional]) { _, _ in }
        }

        let dailyGames: [GameID] = [.rootsky, .triviatsky]
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        var streakAtRisk = 0
        for game in dailyGames {
            guard let record = stats.stats(game: game, languageID: languageID),
                  record.currentStreak >= 3,
                  let last = record.lastPlayed
            else { continue }
            let lastDay = calendar.startOfDay(for: last)
            let gap = calendar.dateComponents([.day], from: lastDay, to: today).day ?? .max
            // Played yesterday but not yet today → the streak dies at midnight.
            if gap == 1 {
                streakAtRisk = max(streakAtRisk, record.currentStreak)
            }
        }

        center.removePendingNotificationRequests(withIdentifiers: [Self.identifier])
        guard streakAtRisk > 0 else { return }

        var fireComponents = calendar.dateComponents([.year, .month, .day], from: today)
        fireComponents.hour = Self.reminderHour
        guard let fireDate = calendar.date(from: fireComponents), fireDate > .now else { return }

        let content = UNMutableNotificationContent()
        content.title = "Your \(streakAtRisk)-day streak is on the line!"
        content.body = "Play today's daily game before midnight to keep it alive. 🔥"
        content.sound = .default

        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour], from: fireDate),
            repeats: false
        )
        center.add(UNNotificationRequest(identifier: Self.identifier, content: content, trigger: trigger))
    }
}
