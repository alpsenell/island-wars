import Foundation

public enum League: String, CaseIterable, Comparable, Sendable {
    case bronze = "Bronze", silver = "Silver", gold = "Gold", platinum = "Platinum", legend = "Legend"

    public static func from(rating: Double) -> League {
        switch rating {
        case ..<1100: .bronze
        case ..<1300: .silver
        case ..<1500: .gold
        case ..<1700: .platinum
        default: .legend
        }
    }

    public var floor: Double {
        switch self {
        case .bronze: 0
        case .silver: 1100
        case .gold: 1300
        case .platinum: 1500
        case .legend: 1700
        }
    }

    public var emoji: String {
        switch self {
        case .bronze: "🥉"
        case .silver: "🥈"
        case .gold: "🥇"
        case .platinum: "💠"
        case .legend: "👑"
        }
    }

    private var order: Int { League.allCases.firstIndex(of: self)! }
    public static func < (a: League, b: League) -> Bool { a.order < b.order }
}

public enum Rating {
    public static let start: Double = 1000
    public static let k: Double = 32
    /// Nobody drops below this, so new players can't spiral into an empty bottom bracket.
    public static let floor: Double = 800

    public static func expected(player: Double, opponent: Double) -> Double {
        1 / (1 + pow(10, (opponent - player) / 400))
    }

    /// Rating change after a ranked battle (rounded to whole points).
    public static func delta(player: Double, opponent: Double, outcome: BattleOutcome) -> Double {
        let score: Double = outcome == .victory ? 1 : 0
        let change = (k * (score - expected(player: player, opponent: opponent))).rounded()
        return max(change, floor - player)
    }

    /// Opponents are matched within ±60 rating, never below the Bronze floor.
    public static func matchOpponent(for rating: Double, roll: Double) -> Double {
        max(800, rating + (roll * 120 - 60)).rounded()
    }
}
