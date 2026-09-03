import Foundation

/// Difficulty tier shared across the games that have one. Raw values match
/// every per-game difficulty enum so plans map straight onto them.
nonisolated enum MeddleyDifficulty: String, CaseIterable, Sendable {
    case easy, medium, hard

    var displayName: String {
        switch self {
        case .easy: "Easy"
        case .medium: "Medium"
        case .hard: "Hard"
        }
    }

    var symbol: String {
        switch self {
        case .easy: "leaf"
        case .medium: "shield"
        case .hard: "flame"
        }
    }

    /// Harder tiers score more per action, so par rises with them.
    var parMultiplier: Double {
        switch self {
        case .easy: 0.8
        case .medium: 1.0
        case .hard: 1.3
        }
    }
}

/// How good the player is at one game, read from their local stats.
nonisolated enum MeddleySkill: Sendable {
    case rookie, solid, master

    var label: String {
        switch self {
        case .rookie: "Rookie"
        case .solid: "Solid"
        case .master: "Master"
        }
    }

    var difficulty: MeddleyDifficulty {
        switch self {
        case .rookie: .easy
        case .solid: .medium
        case .master: .hard
        }
    }

    /// Rookie below 40% of par on average, master at par or better.
    static func estimate(averageScore: Double?, fullPar: Int) -> MeddleySkill {
        guard let averageScore, fullPar > 0 else { return .rookie }
        let ratio = averageScore / Double(fullPar)
        if ratio >= 1.0 { return .master }
        if ratio >= 0.4 { return .solid }
        return .rookie
    }
}

/// Everything decided before a level starts.
nonisolated struct MeddleyLevelPlan: Identifiable, Sendable {
    /// 1-based level number within the run.
    let index: Int
    let game: GameID
    let gameName: String
    /// nil for games without a difficulty picker.
    let difficulty: MeddleyDifficulty?
    let skill: MeddleySkill
    /// Native score worth 1000 level points.
    let par: Int

    var id: Int { index }

    /// Combo multiplier: +15% per level survived, capped at 3×.
    var multiplier: Double {
        min(3.0, 1.0 + 0.15 * Double(index - 1))
    }
}

/// A finished level: what was played and what it was worth.
nonisolated struct MeddleyLevelRecord: Identifiable, Sendable {
    let plan: MeddleyLevelPlan
    let rawScore: Int
    /// Normalized 0–1500 before the combo multiplier.
    let basePoints: Int
    /// What the run actually gained.
    let points: Int
    let words: [FoundWord]

    var id: Int { plan.index }
    var multiplier: Double { plan.multiplier }
}

/// Per-game tuning: shortened level lengths and the score that counts as par.
nonisolated enum MeddleyTuning {
    static let boggleskySeconds = 60
    static let scrambliskySeconds = 45
    static let slashskySeconds = 40.0
    static let rootskyWords = 3
    static let triviaQuestions = 5

    /// A good full-length round on medium, used to read skill from history.
    static func fullPar(for game: GameID) -> Int {
        switch game {
        case .bogglesky: 30
        case .scramblisky: 300
        case .snakesky: 150
        case .tetrisky: 150
        case .slashsky: 200
        case .rootsky, .wordsky: 20
        case .triviatsky: 40
        case .meddleysky: 3000
        }
    }

    /// Par for the shortened level shape, before the difficulty multiplier.
    static func levelPar(for game: GameID) -> Int {
        switch game {
        case .bogglesky: 15
        case .scramblisky: 150
        case .snakesky: 150
        case .tetrisky: 150
        case .slashsky: 130
        case .rootsky, .wordsky: rootskyWords * 4
        case .triviatsky: triviaQuestions * 4
        case .meddleysky: 3000
        }
    }

    static func hasDifficulty(_ game: GameID) -> Bool {
        switch game {
        case .bogglesky, .scramblisky, .snakesky, .tetrisky: true
        default: false
        }
    }

    /// Normalizes a native score to 0–1500 points (par = 1000, capped at 1.5× par).
    static func basePoints(rawScore: Int, par: Int) -> Int {
        guard rawScore > 0, par > 0 else { return 0 }
        let ratio = min(1.5, Double(rawScore) / Double(par))
        return Int((ratio * 1000).rounded())
    }
}

/// Outcome of a finished run, handed to stats + Game Center reporting.
nonisolated struct MeddleyskyResult: Sendable {
    let languageID: String
    let score: Int
    let levelsCleared: Int
    let bestMultiplier: Double
    /// Every word earned across the run (Word Book capture).
    let words: [FoundWord]
}
