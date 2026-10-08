import Foundation

public enum BattleOutcome: String, Codable, Hashable, Sendable { case victory, defeat }

/// The whole battle. Between orders it evolves deterministically (chip damage + scheduled
/// enemy volleys), so it can be stored in a Live Activity and replayed to any moment.
public struct BattleState: Codable, Hashable, Sendable {
    public var seed: UInt64
    public var maxHP: Double
    public var myHP: Double
    public var enemyHP: Double
    public var asOf: Date
    public var fleet: FleetStats
    public var enemy: EnemyProfile

    public var lastShotAt: Date
    public var shotsFired = 0
    public var braceUntil: Date
    public var braceReadyAt: Date
    public var nextVolleyAt: Date
    public var volleyCount = 0
    public var exposedUntil: Date
    public var enemyRepairsLeft: Int

    public var repairKits: Int          // usable this battle (already capped)
    public var repairsUsed = 0

    public var lastEvent: String
    public var outcome: BattleOutcome?
    public var decidedAt: Date?

    public init(seed: UInt64, start: Date, fleet: FleetStats, enemy: EnemyProfile, repairKits: Int) {
        self.seed = seed
        maxHP = Tuning.maxHP
        myHP = Tuning.maxHP
        enemyHP = Tuning.maxHP
        asOf = start
        self.fleet = fleet
        self.enemy = enemy
        // Start fully charged so the opening shot is a real choice.
        lastShotAt = start.addingTimeInterval(-Tuning.fullCharge)
        braceUntil = .distantPast
        braceReadyAt = start
        nextVolleyAt = start.addingTimeInterval(Tuning.firstVolleyDelay)
        exposedUntil = .distantPast
        enemyRepairsLeft = enemy.repairs
        self.repairKits = min(repairKits, Tuning.repairsPerBattle)
        lastEvent = "⚓ Battle stations!"
    }

    // MARK: Queries

    public var isOver: Bool { outcome != nil }
    public var repairsLeft: Int { max(0, repairKits - repairsUsed) }

    public func canFire(at t: Date) -> Bool { t.timeIntervalSince(lastShotAt) >= Tuning.reload }
    public func canBrace(at t: Date) -> Bool { t >= braceReadyAt }
    public func isExposed(at t: Date) -> Bool { t <= exposedUntil }
    public func isBracing(at t: Date) -> Bool { t <= braceUntil }

    /// 0…1 broadside charge.
    public func charge(at t: Date) -> Double {
        let since = t.timeIntervalSince(lastShotAt) - Tuning.reload
        return min(max(since / (Tuning.fullCharge - Tuning.reload), 0), 1)
    }

    public func shotDamage(at t: Date) -> Double {
        let c = charge(at: t)
        let base = Tuning.minShot + (Tuning.maxShot - Tuning.minShot) * c * c
        return maxHP * base * fleet.shotMultiplier * (isExposed(at: t) ? Tuning.exposedMultiplier : 1)
    }

    /// When the battle ends if nobody gives another order.
    public func projectedEnd() -> Date {
        if let decidedAt { return decidedAt }
        var copy = self
        copy.advance(to: asOf.addingTimeInterval(3 * 3600))
        return copy.decidedAt ?? .distantFuture
    }

    // MARK: Time

    public mutating func advance(to t: Date) {
        while outcome == nil && asOf < t {
            let segmentEnd = min(t, nextVolleyAt)
            drain(until: segmentEnd)
            if outcome == nil && segmentEnd == nextVolleyAt { resolveVolley() }
        }
        if asOf < t { asOf = t }
    }

    private mutating func drain(until end: Date) {
        let dt = end.timeIntervalSince(asOf)
        guard dt > 0 else { return }
        let myZero = myHP / enemy.chipDPS
        let enemyZero = enemyHP / fleet.chipDPS
        let step = min(dt, myZero, enemyZero)
        myHP = max(0, myHP - enemy.chipDPS * step)
        enemyHP = max(0, enemyHP - fleet.chipDPS * step)
        if step < dt {
            asOf = asOf.addingTimeInterval(step)
            settle()
        } else {
            asOf = end
        }
    }

    private mutating func resolveVolley() {
        let at = nextVolleyAt
        let braced = isBracing(at: at)
        let roll = 1 - Tuning.volleySpread + 2 * Tuning.volleySpread * unitRandom(seed, volleyCount, salt: 4)
        let damage = enemy.volleyDamage * roll * (braced ? 1 - Tuning.braceReduction : 1)
        myHP = max(0, myHP - damage)
        lastEvent = braced ? "🛡️ Braced! Volley absorbed (−\(Int(damage)))" : "💥 Enemy volley hit (−\(Int(damage)))"
        exposedUntil = at.addingTimeInterval(Tuning.exposedWindow)
        volleyCount += 1
        let jitter = 0.8 + 0.4 * unitRandom(seed, volleyCount, salt: 1)
        nextVolleyAt = at.addingTimeInterval(enemy.volleyInterval * jitter)

        if enemyHP < maxHP * Tuning.enemyRepairThreshold, enemyRepairsLeft > 0 {
            enemyRepairsLeft -= 1
            enemyHP = min(maxHP, enemyHP + maxHP * Tuning.enemyRepairAmount)
            lastEvent += " · enemy patched hull"
        }
        settle()
    }

    private mutating func settle() {
        guard outcome == nil else { return }
        if enemyHP <= 0.01 {
            enemyHP = 0
            outcome = .victory
        } else if myHP <= 0.01 {
            myHP = 0
            outcome = .defeat
        } else {
            return
        }
        decidedAt = asOf
        lastEvent = outcome == .victory ? "🏆 Victory! Enemy fleet sunk" : "☠️ Your fleet was sunk"
    }

    // MARK: Orders

    public mutating func fire(at t: Date) {
        advance(to: t)
        guard !isOver else { return }
        guard canFire(at: t) else {
            lastEvent = "🔄 Cannons reloading…"
            return
        }
        var damage = shotDamage(at: t)
        let exposed = isExposed(at: t)
        shotsFired += 1
        let enemyBraced = !exposed && unitRandom(seed, shotsFired, salt: 2) < enemy.braceChance
        if enemyBraced { damage *= Tuning.enemyBraceReduction }
        enemyHP = max(0, enemyHP - damage)
        lastShotAt = t
        lastEvent = exposed ? "🎯 Caught them reloading! −\(Int(damage))"
            : enemyBraced ? "🛡️ Enemy braced. −\(Int(damage))"
            : "💥 Broadside −\(Int(damage))"
        settle()
    }

    public mutating func brace(at t: Date) {
        advance(to: t)
        guard !isOver else { return }
        guard canBrace(at: t) else {
            lastEvent = "⏳ Crew still recovering"
            return
        }
        braceUntil = t.addingTimeInterval(Tuning.braceWindow)
        braceReadyAt = t.addingTimeInterval(Tuning.braceCooldown)
        lastEvent = "🛡️ Bracing for impact…"
    }

    public mutating func repair(at t: Date) {
        advance(to: t)
        guard !isOver else { return }
        guard repairsLeft > 0 else {
            lastEvent = "🧰 No repairs left this battle"
            return
        }
        repairsUsed += 1
        let amount = maxHP * Tuning.repairAmount
        myHP = min(maxHP, myHP + amount)
        lastEvent = "🔧 Hull patched +\(Int(amount))"
    }
}
