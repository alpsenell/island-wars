import BattleCore
import Foundation

/// Player economy. Gold = soft currency (earned), Pearls = hard currency (bought).
/// Pearls never buy power: only cosmetics and convenience (repair kits are also sold for Gold,
/// and at most `Tuning.repairsPerBattle` can be used per battle).
@MainActor
final class Wallet: ObservableObject {
    static let shared = Wallet()
    private let defaults = UserDefaults.standard

    @Published var gold: Int { didSet { defaults.set(gold, forKey: "gold") } }
    @Published var pearls: Int { didSet { defaults.set(pearls, forKey: "pearls") } }
    @Published var repairKits: Int { didSet { defaults.set(repairKits, forKey: "repairKits") } }
    @Published var cannonLevel: Int { didSet { defaults.set(cannonLevel, forKey: "cannonLevel") } }
    @Published var rating: Int { didSet { defaults.set(rating, forKey: "rating") } }
    @Published var bestRating: Int { didSet { defaults.set(bestRating, forKey: "bestRating") } }
    @Published var wins: Int { didSet { defaults.set(wins, forKey: "wins") } }
    @Published var losses: Int { didSet { defaults.set(losses, forKey: "losses") } }
    @Published var hullSkin: HullSkin { didSet { defaults.set(hullSkin.rawValue, forKey: "hullSkin") } }
    @Published var ownedSkins: Set<String> { didSet { defaults.set(Array(ownedSkins), forKey: "ownedSkins") } }

    let fleetName = "Your Armada"

    private init() {
        defaults.register(defaults: [
            "gold": 150, "pearls": 40, "repairKits": 3, "cannonLevel": 1,
            "rating": Int(Rating.start), "bestRating": Int(Rating.start), "wins": 0, "losses": 0,
            "hullSkin": HullSkin.oak.rawValue, "ownedSkins": [HullSkin.oak.rawValue],
        ])
        gold = defaults.integer(forKey: "gold")
        pearls = defaults.integer(forKey: "pearls")
        repairKits = defaults.integer(forKey: "repairKits")
        cannonLevel = defaults.integer(forKey: "cannonLevel")
        rating = defaults.integer(forKey: "rating")
        bestRating = defaults.integer(forKey: "bestRating")
        wins = defaults.integer(forKey: "wins")
        losses = defaults.integer(forKey: "losses")
        hullSkin = HullSkin(rawValue: defaults.string(forKey: "hullSkin") ?? "") ?? .oak
        ownedSkins = Set(defaults.stringArray(forKey: "ownedSkins") ?? [HullSkin.oak.rawValue])
    }

    var league: League { League.from(rating: Double(rating)) }

    // MARK: Spending

    var cannonsMaxed: Bool { cannonLevel >= Tuning.maxCannonLevel }
    var cannonUpgradeCost: Int { 100 * cannonLevel }

    func upgradeCannons() -> Bool {
        guard !cannonsMaxed, gold >= cannonUpgradeCost else { return false }
        gold -= cannonUpgradeCost
        cannonLevel += 1
        return true
    }

    static let kitGoldPrice = 40

    func buyRepairKitWithGold() -> Bool {
        guard gold >= Self.kitGoldPrice else { return false }
        gold -= Self.kitGoldPrice
        repairKits += 1
        return true
    }

    func buyRepairKits(count: Int, pearlCost: Int) -> Bool {
        guard pearls >= pearlCost else { return false }
        pearls -= pearlCost
        repairKits += count
        return true
    }

    func buyOrEquip(_ skin: HullSkin) -> Bool {
        if ownedSkins.contains(skin.rawValue) { hullSkin = skin; return true }
        guard pearls >= skin.pearlPrice else { return false }
        pearls -= skin.pearlPrice
        ownedSkins.insert(skin.rawValue)
        hullSkin = skin
        return true
    }

    /// Placeholder for StoreKit 2 — the real build must route this through In-App Purchase.
    func simulatePearlPurchase(_ amount: Int) { pearls += amount }

    func applyResult(_ outcome: BattleOutcome, opponentRating: Double, repairsUsed: Int) -> (gold: Int, rating: Int) {
        repairKits = max(0, repairKits - repairsUsed)
        let delta = Int(Rating.delta(player: Double(rating), opponent: opponentRating, outcome: outcome))
        rating += delta
        bestRating = max(bestRating, rating)
        // Higher leagues pay more, so climbing is its own reward.
        let goldReward = outcome == .victory ? 60 + 15 * League.allCases.firstIndex(of: league)! : 15
        gold += goldReward
        if outcome == .victory { wins += 1 } else { losses += 1 }
        return (goldReward, delta)
    }
}
