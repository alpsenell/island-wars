import Foundation

public struct FleetStats: Codable, Hashable, Sendable {
    public var chipDPS: Double
    public var shotMultiplier: Double

    public init(cannonLevel: Int) {
        let level = min(max(cannonLevel, 1), Tuning.maxCannonLevel)
        let bonus = 1 + Tuning.upgradeBonusPerLevel * Double(level - 1)
        chipDPS = Tuning.chipDPS * bonus
        shotMultiplier = bonus
    }
}

/// A rating-matched AI fleet. Higher-rated bots hit harder, volley faster,
/// brace against your broadsides more often and repair more.
public struct EnemyProfile: Codable, Hashable, Sendable {
    public var name: String
    public var rating: Double
    public var chipDPS: Double
    public var volleyDamage: Double
    public var volleyInterval: TimeInterval
    public var braceChance: Double
    public var repairs: Int

    public static func bot(rating: Double, name: String) -> EnemyProfile {
        let steps = (rating - 1000) / 100
        let strength = pow(Tuning.botStrengthPer100, steps)
        return EnemyProfile(
            name: name,
            rating: rating,
            chipDPS: Tuning.chipDPS * strength,
            volleyDamage: Tuning.volleyDamage * strength,
            volleyInterval: Tuning.volleyInterval,
            braceChance: min(max(Tuning.botBraceBase + Tuning.botBracePer100 * steps, 0), Tuning.botMaxBrace),
            repairs: rating >= 1700 ? 2 : 1)
    }

    public static let names = ["Captain Brine", "The Kraken Club", "Salt & Steel", "Red Tide",
                               "Mara the Bold", "Driftwood Gang", "Admiral Nox", "Sea Wolves",
                               "Iron Gull", "The Tidebreakers", "Black Coral", "Old Man Squall"]
}

/// Deterministic per-battle randomness (seeded), so outcomes can't be rerolled by reopening the app.
func unitRandom(_ seed: UInt64, _ index: Int, salt: UInt64) -> Double {
    var z = seed &+ UInt64(truncatingIfNeeded: index) &* 0x9E37_79B9_7F4A_7C15 &+ salt
    z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
    z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
    z ^= z >> 31
    return Double(z >> 11) / Double(UInt64(1) << 53)
}
