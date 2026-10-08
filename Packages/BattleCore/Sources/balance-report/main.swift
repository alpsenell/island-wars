import BattleCore
import Foundation

func pct(_ x: Double) -> String { String(format: "%5.1f%%", x * 100) }

print("Win rate by policy vs bot rating (2000 battles each)\n")
let ratings: [Double] = [900, 1000, 1100, 1200, 1300, 1400, 1500, 1600, 1700, 1800]
print("policy   " + ratings.map { String(format: "%8.0f", $0) }.joined())
for policy in Policy.allCases {
    let row = ratings.map { pct(Simulator.stats(policy: policy, enemyRating: $0).winRate) }
    print(policy.rawValue.padding(toLength: 9, withPad: " ", startingAt: 0) + row.map { "  " + $0 }.joined())
}

let gold = 1400.0
let skilled = Simulator.stats(policy: .skilled, enemyRating: gold)
print("\nSkilled vs Gold bot: median winner hull \(pct(skilled.medianWinnerHull)), median length \(Int(skilled.medianDuration))s")

print("\nRanked ladder (300 battles, Elo matchmaking)")
for policy in Policy.allCases {
    let r = Simulator.ladder(policy: policy)
    let league = League.from(rating: r)
    print("  \(policy.rawValue.padding(toLength: 8, withPad: " ", startingAt: 0)) \(Int(r))  \(league.emoji) \(league.rawValue)")
}
