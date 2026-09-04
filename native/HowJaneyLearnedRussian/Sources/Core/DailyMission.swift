import Foundation

struct DailyMission: Identifiable, Hashable {
    enum Kind: String, Hashable {
        case rounds
        case words
        case variety
    }

    let kind: Kind
    let title: String
    let detail: String
    let symbol: String
    let current: Int
    let goal: Int

    var id: Kind { kind }
    var isComplete: Bool { current >= goal }
    var progressText: String { "\(min(current, goal))/\(goal)" }

    static func today(from progress: StatsService.TodayProgress, collectedWords: Int) -> [DailyMission] {
        [
            DailyMission(
                kind: .rounds,
                title: "Open the notebook",
                detail: "Play a round to begin today’s expedition.",
                symbol: "book.closed.fill",
                current: progress.rounds,
                goal: 1
            ),
            DailyMission(
                kind: .words,
                title: "Word collector",
                detail: "Bring eight different words safely into your journal.",
                symbol: "leaf.fill",
                current: collectedWords,
                goal: 8
            ),
            DailyMission(
                kind: .variety,
                title: "Try a new route",
                detail: "Visit three different game stations today.",
                symbol: "signpost.right.and.left.fill",
                current: progress.distinctGames,
                goal: 3
            ),
        ]
    }
}
