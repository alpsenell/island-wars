import Foundation

/// Scripted players used to measure whether skill, not luck or money, decides matches.
public enum Policy: String, CaseIterable, Sendable {
    case idle, masher, skilled, whale

    public var cannonLevel: Int { self == .whale ? Tuning.maxCannonLevel : 1 }
    public var repairKits: Int { self == .whale ? 99 : Tuning.repairsPerBattle }

    /// Decides orders once per second, like a player glancing at the Dynamic Island.
    func act(on s: inout BattleState, at t: Date) {
        switch self {
        case .idle:
            return
        case .masher, .whale:
            if s.canFire(at: t) { s.fire(at: t) }
            if s.canBrace(at: t) { s.brace(at: t) }
            if s.myHP < s.maxHP * 0.5, s.repairsLeft > 0 { s.repair(at: t) }
        case .skilled:
            // Even good players look away sometimes: each volley cycle they're watching 85% of the time.
            let watching = unitRandom(s.seed, s.volleyCount, salt: 9) < 0.85
            if !watching {
                if s.canFire(at: t), s.charge(at: t) >= 1 { s.fire(at: t) }
                return
            }
            let untilVolley = s.nextVolleyAt.timeIntervalSince(t)
            if untilVolley > 0, untilVolley <= 3, s.canBrace(at: t) { s.brace(at: t) }
            if s.canFire(at: t) {
                // Punish the enemy reload window; otherwise only spend a full charge
                // when there's time to recharge before the next window.
                if s.isExposed(at: t) || (s.charge(at: t) >= 1 && untilVolley >= Tuning.fullCharge) {
                    s.fire(at: t)
                }
            }
            if s.myHP < s.maxHP * 0.4, s.repairsLeft > 0 { s.repair(at: t) }
        }
    }
}

public struct BattleSample: Sendable {
    public let outcome: BattleOutcome
    public let winnerHullLeft: Double   // fraction of max HP
    public let duration: TimeInterval
}

public enum Simulator {
    public static func battle(policy: Policy, enemyRating: Double, seed: UInt64) -> BattleSample {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let enemy = EnemyProfile.bot(rating: enemyRating, name: "Bot")
        var s = BattleState(seed: seed, start: start, fleet: FleetStats(cannonLevel: policy.cannonLevel),
                            enemy: enemy, repairKits: policy.repairKits)
        var t = start
        while !s.isOver && t.timeIntervalSince(start) < 3 * 3600 {
            t = t.addingTimeInterval(1)
            s.advance(to: t)
            if !s.isOver { policy.act(on: &s, at: t) }
        }
        let outcome = s.outcome ?? .defeat
        let hull = (outcome == .victory ? s.myHP : s.enemyHP) / s.maxHP
        return BattleSample(outcome: outcome, winnerHullLeft: hull,
                            duration: (s.decidedAt ?? t).timeIntervalSince(start))
    }

    public struct Stats: Sendable {
        public let winRate: Double
        public let medianWinnerHull: Double
        public let medianDuration: TimeInterval
    }

    public static func stats(policy: Policy, enemyRating: Double, battles: Int = 2000, seed: UInt64 = 1) -> Stats {
        let samples = (0..<battles).map { battle(policy: policy, enemyRating: enemyRating, seed: seed &+ UInt64($0) &* 7919) }
        let wins = samples.filter { $0.outcome == .victory }.count
        func median(_ xs: [Double]) -> Double { xs.isEmpty ? 0 : xs.sorted()[xs.count / 2] }
        return Stats(winRate: Double(wins) / Double(battles),
                     medianWinnerHull: median(samples.map(\.winnerHullLeft)),
                     medianDuration: median(samples.map(\.duration)))
    }

    /// Plays a ranked season with Elo matchmaking; returns the final rating.
    public static func ladder(policy: Policy, battles: Int = 300, seed: UInt64 = 42) -> Double {
        var rating = Rating.start
        for i in 0..<battles {
            let opponent = Rating.matchOpponent(for: rating, roll: unitRandom(seed, i, salt: 3))
            let result = battle(policy: policy, enemyRating: opponent, seed: seed &+ UInt64(i) &* 104_729)
            rating += Rating.delta(player: rating, opponent: opponent, outcome: result.outcome)
        }
        return rating
    }
}
