import ActivityKit
import Foundation

struct BattleResult: Identifiable {
    let id = UUID()
    let outcome: BattleOutcome
    let enemyName: String
    let gold: Int
    let trophies: Int
}

/// Owns the running battle and keeps the Live Activity in sync.
/// Orders from the Dynamic Island arrive via App Intents that run in the app process.
@MainActor
final class BattleManager: ObservableObject {
    static let shared = BattleManager()

    @Published private(set) var attributes: BattleAttributes?
    @Published private(set) var state: BattleAttributes.ContentState?
    @Published var lastResult: BattleResult?

    private var activity: Activity<BattleAttributes>? {
        Activity<BattleAttributes>.activities.first { $0.activityState == .active }
    }

    private init() { restore() }

    /// Picks up a battle that is still live in the Dynamic Island (e.g. after a relaunch).
    func restore() {
        guard state == nil, let activity else { return }
        attributes = activity.attributes
        state = activity.content.state
    }

    func startRaid() {
        guard state == nil else { return }
        let wallet = Wallet.shared
        let now = Date()
        let attrs = BattleAttributes(myFleetName: wallet.fleetName,
                                     enemyName: Rivals.names.randomElement()!,
                                     hullSkin: wallet.hullSkin.rawValue)
        let initial = BattleAttributes.ContentState(
            maxHP: Tuning.maxHP, myHP: Tuning.maxHP, enemyHP: Tuning.maxHP, asOf: now,
            myDPS: wallet.cannonDPS, enemyDPS: wallet.enemyDPS, cannonReadyAt: now,
            repairKits: wallet.repairKits, lastEvent: "⚓ Battle stations!")
        attributes = attrs
        state = initial
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: attrs,
                                      content: .init(state: initial, staleDate: initial.decidedAt),
                                      pushType: nil)
        }
    }

    func fire() async { await apply { $0.fireBroadside(at: .now) } }
    func repair() async { await apply { $0.repairHull(at: .now) } }

    func addRepairKits(_ count: Int) async {
        await apply { $0.repairKits += count; $0.lastEvent = "🧰 +\(count) repair kits" }
    }

    /// Called every second while the app is open; settles finished battles.
    func tick() async {
        restore()
        if let state, state.outcome(at: .now) != nil { await finish() }
    }

    private func apply(_ change: (inout BattleAttributes.ContentState) -> Void) async {
        restore()
        guard var updated = state else { return }
        change(&updated)
        state = updated
        if updated.outcome(at: .now) != nil {
            await finish()
        } else {
            await activity?.update(.init(state: updated, staleDate: updated.decidedAt))
        }
    }

    private func finish() async {
        guard let current = state, let attrs = attributes,
              let outcome = current.outcome(at: .now) else { return }
        var final = current
        final.advance(to: .now)
        final.lastEvent = outcome == .victory ? "🏆 Victory! Enemy fleet sunk" : "☠️ Your fleet was sunk"
        state = nil
        attributes = nil

        let reward = Wallet.shared.applyResult(outcome, kitsLeft: final.repairKits)
        lastResult = BattleResult(outcome: outcome, enemyName: attrs.enemyName,
                                  gold: reward.gold, trophies: reward.trophies)

        for activity in Activity<BattleAttributes>.activities {
            await activity.end(.init(state: final, staleDate: nil),
                               dismissalPolicy: .after(.now.addingTimeInterval(10 * 60)))
        }
    }
}
