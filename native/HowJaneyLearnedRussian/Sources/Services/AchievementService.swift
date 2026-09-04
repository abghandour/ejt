import GameKit
import Observation

/// Reports Game Center achievements. IDs must be registered in App Store
/// Connect with these exact identifiers.
@Observable
final class AchievementService {
    nonisolated enum ID: String {
        /// A perfect 25/25 Rootsky day.
        case perfectRootsky = "perfect_rootsky"
        /// Cleared an entire Bogglesky board before the timer.
        case boardClear = "board_clear"
        /// Solved 10+ words in one Scramblisky run.
        case scrambleTen = "scramble_ten"
        /// 5-starred every question of a Triviatsky day.
        case perfectTrivia = "perfect_trivia"
        case streak7 = "streak_7"
        case streak30 = "streak_30"
        case streak100 = "streak_100"

        var title: String {
            switch self {
            case .perfectRootsky: "Root archaeologist"
            case .boardClear: "Board clearer"
            case .scrambleTen: "Letter runner"
            case .perfectTrivia: "Quiz scout"
            case .streak7: "Seven-day trail"
            case .streak30: "Thirty-day trail"
            case .streak100: "One-hundred-day trail"
            }
        }

        var message: String {
            switch self {
            case .perfectRootsky: "You found every branch in a Rootsky round."
            case .boardClear: "Every word on the Boggle board is yours."
            case .scrambleTen: "Ten Scramblisky words, one quick mind."
            case .perfectTrivia: "A perfect Triviatsky dispatch."
            case .streak7: "A week of showing up for your words."
            case .streak30: "A full month on the language trail."
            case .streak100: "A hundred days of steady discovery."
            }
        }

        var symbol: String {
            switch self {
            case .perfectRootsky: "tree.fill"
            case .boardClear: "square.grid.3x3.fill"
            case .scrambleTen: "text.word.spacing"
            case .perfectTrivia: "checkmark.seal.fill"
            case .streak7, .streak30, .streak100: "flame.fill"
            }
        }
    }

    @ObservationIgnored private var reported: Set<ID> = []
    @ObservationIgnored private let storageKey = "achievement-service-unlocked"
    @ObservationIgnored private var unlocked: Set<ID>
    /// Only milestones earned during this launch wait for Game Center auth.
    /// Keeping this in memory prevents a prior device user's data from being
    /// replayed to a different Game Center account on a shared device.
    @ObservationIgnored private var pendingGameCenterReports: Set<ID> = []
    @ObservationIgnored private var queuedUnlocks: [ID] = []
    private(set) var latestUnlock: ID?
    private(set) var unlockRevision = 0

    init() {
        let savedIDs = UserDefaults.standard.stringArray(forKey: storageKey) ?? []
        unlocked = Set(savedIDs.compactMap(ID.init(rawValue:)))
    }

    func report(_ id: ID) {
        if unlocked.insert(id).inserted {
            UserDefaults.standard.set(unlocked.map(\.rawValue), forKey: storageKey)
            if latestUnlock == nil {
                latestUnlock = id
            } else {
                queuedUnlocks.append(id)
            }
            unlockRevision += 1
        }

        pendingGameCenterReports.insert(id)
        reportToGameCenter(id)
    }

    /// Authentication can complete after a round ends. Retry only milestones
    /// earned during this launch, which is safe if the device's Game Center
    /// account changes between launches.
    func reportPendingToGameCenter() {
        for id in pendingGameCenterReports {
            reportToGameCenter(id)
        }
    }

    private func reportToGameCenter(_ id: ID) {
        guard GKLocalPlayer.local.isAuthenticated, !reported.contains(id) else { return }
        reported.insert(id)
        pendingGameCenterReports.remove(id)
        let achievement = GKAchievement(identifier: id.rawValue)
        achievement.percentComplete = 100
        achievement.showsCompletionBanner = true
        GKAchievement.report([achievement]) { _ in }
    }

    func dismissLatestUnlock() {
        if queuedUnlocks.isEmpty {
            latestUnlock = nil
        } else {
            latestUnlock = queuedUnlocks.removeFirst()
            unlockRevision += 1
        }
    }

    /// Streak milestones from any game's best streak.
    func reportStreak(_ bestStreak: Int) {
        if bestStreak >= 7 { report(.streak7) }
        if bestStreak >= 30 { report(.streak30) }
        if bestStreak >= 100 { report(.streak100) }
    }
}
