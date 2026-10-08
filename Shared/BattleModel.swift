import ActivityKit
import Foundation
import SwiftUI

/// Tuning knobs. Battles are 5 minutes in the prototype; the real game targets hours.
enum Tuning {
    static let maxHP: Double = 1000
    static let baseBattleSeconds: Double = 300
    static var baseDPS: Double { maxHP / baseBattleSeconds }
    static let broadsideDamage = 0.08        // fraction of max HP
    static let broadsideCooldown: TimeInterval = 30
    static let repairAmount = 0.15           // fraction of max HP
}

struct BattleAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var maxHP: Double
        var myHP: Double          // value at `asOf`
        var enemyHP: Double       // value at `asOf`
        var asOf: Date
        var myDPS: Double         // damage per second we deal
        var enemyDPS: Double      // damage per second we take
        var cannonReadyAt: Date
        var repairKits: Int
        var lastEvent: String
    }

    var myFleetName: String
    var enemyName: String
    var hullSkin: String
}

enum BattleOutcome { case victory, defeat }

/// Battle state is a closed-form function of time, so the Live Activity can animate
/// hull bars with timer-driven views and needs an update only when an order is given.
extension BattleAttributes.ContentState {
    var mySunkAt: Date { asOf.addingTimeInterval(myHP / enemyDPS) }
    var enemySunkAt: Date { asOf.addingTimeInterval(enemyHP / myDPS) }
    var decidedAt: Date { min(mySunkAt, enemySunkAt) }

    func myHP(at date: Date) -> Double { max(0, myHP - enemyDPS * clampedElapsed(to: date)) }
    func enemyHP(at date: Date) -> Double { max(0, enemyHP - myDPS * clampedElapsed(to: date)) }

    func outcome(at date: Date) -> BattleOutcome? {
        guard date >= decidedAt else { return nil }
        return enemySunkAt <= mySunkAt ? .victory : .defeat
    }

    mutating func advance(to date: Date) {
        let newMy = myHP(at: date), newEnemy = enemyHP(at: date)
        myHP = newMy < 0.01 ? 0 : newMy
        enemyHP = newEnemy < 0.01 ? 0 : newEnemy
        asOf = date
    }

    mutating func fireBroadside(at date: Date) {
        advance(to: date)
        guard outcome(at: date) == nil else { return }
        guard date >= cannonReadyAt else {
            lastEvent = "🔄 Cannons reloading…"
            return
        }
        let damage = maxHP * Tuning.broadsideDamage
        enemyHP = max(0, enemyHP - damage)
        cannonReadyAt = date.addingTimeInterval(Tuning.broadsideCooldown)
        lastEvent = "💥 Broadside hit! −\(Int(damage))"
    }

    mutating func repairHull(at date: Date) {
        advance(to: date)
        guard outcome(at: date) == nil else { return }
        guard repairKits > 0 else {
            lastEvent = "🧰 Out of repair kits"
            return
        }
        let amount = maxHP * Tuning.repairAmount
        repairKits -= 1
        myHP = min(maxHP, myHP + amount)
        lastEvent = "🔧 Hull patched +\(Int(amount))"
    }

    private func clampedElapsed(to date: Date) -> TimeInterval {
        max(0, min(date, decidedAt).timeIntervalSince(asOf))
    }
}

enum HullSkin: String, CaseIterable, Identifiable {
    case oak = "Oak", obsidian = "Obsidian", gilded = "Gilded", coral = "Coral"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .oak: .cyan
        case .obsidian: .purple
        case .gilded: .yellow
        case .coral: .pink
        }
    }
    var pearlPrice: Int { self == .oak ? 0 : 120 }
}

/// Hull bar that drains on its own using a timer-driven ProgressView (no updates needed).
struct HullBar: View {
    let hp: Double
    let maxHP: Double
    let asOf: Date
    let drainPerSecond: Double
    let tint: Color
    var circular = false

    var body: some View {
        Group {
            if hp <= 0 {
                ProgressView(value: 0)
            } else {
                let empty = asOf.addingTimeInterval(hp / drainPerSecond)
                let start = empty.addingTimeInterval(-maxHP / drainPerSecond)
                ProgressView(timerInterval: start...empty, countsDown: true,
                             label: { EmptyView() }, currentValueLabel: { EmptyView() })
            }
        }
        .tint(tint)
        .modifier(CircularIf(circular: circular))
    }
}

private struct CircularIf: ViewModifier {
    let circular: Bool
    func body(content: Content) -> some View {
        if circular { content.progressViewStyle(.circular) } else { content }
    }
}
