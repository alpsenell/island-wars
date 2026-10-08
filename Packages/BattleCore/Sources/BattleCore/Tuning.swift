import Foundation

/// Every balance number in one place. `swift run balance-report` shows the effect of a change.
public enum Tuning {
    public static let maxHP: Double = 1000

    // Constant chip damage both fleets deal (≈10 min to sink by chip alone).
    public static let chipDPS: Double = maxHP / 600

    // Player broadside: reloads, then charges. Damage grows with the square of charge,
    // so patient, well-timed shots beat spamming.
    public static let reload: TimeInterval = 10
    public static let fullCharge: TimeInterval = 40          // seconds after the last shot
    public static let minShot = 0.018                        // fraction of max HP
    public static let maxShot = 0.072
    public static let exposedMultiplier = 1.6                // hitting the enemy while it reloads
    public static let exposedWindow: TimeInterval = 10
    public static let enemyBraceReduction = 0.5

    // Enemy volleys are telegraphed; bracing in time absorbs most of the damage.
    public static let volleyDamage: Double = 90
    public static let volleySpread = 0.3                     // ±30% per volley
    public static let volleyInterval: TimeInterval = 45
    public static let firstVolleyDelay: TimeInterval = 30
    public static let braceWindow: TimeInterval = 5
    public static let braceCooldown: TimeInterval = 15
    public static let braceReduction = 0.75

    public static let repairAmount = 0.15
    public static let repairsPerBattle = 2
    public static let enemyRepairAmount = 0.12
    public static let enemyRepairThreshold = 0.35

    // Bots get 17.5% stronger (damage) per 100 rating, and brace more often.
    public static let botStrengthPer100 = 1.175
    public static let botBraceBase = 0.1
    public static let botBracePer100 = 0.05
    public static let botMaxBrace = 0.6

    // Upgrades are a small, capped sidegrade so rank reflects skill.
    public static let maxCannonLevel = 5
    public static let upgradeBonusPerLevel = 0.03
}
