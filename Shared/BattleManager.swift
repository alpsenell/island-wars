import ActivityKit
import BattleCore
import Foundation

struct BattleResult: Identifiable {
    let id = UUID()
    let outcome: BattleOutcome
    let enemyName: String
    let gold: Int
    let ratingChange: Int
    let newRating: Int
}

/// Owns the running battle and keeps the Live Activity in sync.
/// Orders from the Dynamic Island arrive via App Intents that run in the app process.
@MainActor
final class BattleManager: ObservableObject {
    static let shared = BattleManager()

    @Published private(set) var attributes: BattleAttributes?
    @Published private(set) var state: BattleState?
    @Published var lastResult: BattleResult?

    private var pushedVolleyCount = 0

    private var activity: Activity<BattleAttributes>? {
        Activity<BattleAttributes>.activities.first { $0.activityState == .active }
    }

    private init() { restore() }

    /// Picks up a battle that is still live in the Dynamic Island (e.g. after a relaunch).
    func restore() {
        guard state == nil, let activity else { return }
        attributes = activity.attributes
        state = activity.content.state
        pushedVolleyCount = activity.content.state.volleyCount
    }

    func startRaid() {
        guard state == nil else { return }
        let wallet = Wallet.shared
        let now = Date()
        let opponentRating = Rating.matchOpponent(for: Double(wallet.rating), roll: .random(in: 0...1))
        let enemy = EnemyProfile.bot(rating: opponentRating, name: EnemyProfile.names.randomElement()!)
        let initial = BattleState(seed: .random(in: 0...UInt64.max), start: now,
                                  fleet: FleetStats(cannonLevel: wallet.cannonLevel),
                                  enemy: enemy, repairKits: wallet.repairKits)
        let attrs = BattleAttributes(myFleetName: wallet.fleetName, hullSkin: wallet.hullSkin.rawValue,
                                     playerRating: wallet.rating)
        attributes = attrs
        state = initial
        pushedVolleyCount = 0
        if ActivityAuthorizationInfo().areActivitiesEnabled {
            _ = try? Activity.request(attributes: attrs,
                                      content: .init(state: initial, staleDate: initial.staleDate),
                                      pushType: nil)
        }
    }

    func fire() async { await apply { $0.fire(at: .now) } }
    func brace() async { await apply { $0.brace(at: .now) } }
    func repair() async { await apply { $0.repair(at: .now) } }

    func addRepairKits(_ count: Int) async {
        await apply { $0.repairKits = min(Tuning.repairsPerBattle, $0.repairKits + count) }
    }

    /// Called every second while the app is open: replays the battle to now,
    /// settles finished battles and refreshes the Live Activity after each volley.
    func tick() async {
        restore()
        guard var current = state else { return }
        current.advance(to: .now)
        state = current
        if current.isOver {
            await finish()
        } else if current.volleyCount != pushedVolleyCount {
            await push(current)
        }
    }

    private func apply(_ change: (inout BattleState) -> Void) async {
        restore()
        guard var updated = state else { return }
        change(&updated)
        state = updated
        if updated.isOver {
            await finish()
        } else {
            await push(updated)
        }
    }

    private func push(_ s: BattleState) async {
        pushedVolleyCount = s.volleyCount
        await activity?.update(.init(state: s, staleDate: s.staleDate))
    }

    private func finish() async {
        guard let final = state, let outcome = final.outcome else { return }
        state = nil
        attributes = nil

        let wallet = Wallet.shared
        let reward = wallet.applyResult(outcome, opponentRating: final.enemy.rating, repairsUsed: final.repairsUsed)
        lastResult = BattleResult(outcome: outcome, enemyName: final.enemy.name, gold: reward.gold,
                                  ratingChange: reward.rating, newRating: wallet.rating)

        for activity in Activity<BattleAttributes>.activities {
            await activity.end(.init(state: final, staleDate: nil),
                               dismissalPolicy: .after(.now.addingTimeInterval(10 * 60)))
        }
    }
}
