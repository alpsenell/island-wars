import Foundation

/// Player economy. Gold = soft currency (earned), Pearls = hard currency (bought).
@MainActor
final class Wallet: ObservableObject {
    static let shared = Wallet()
    private let defaults = UserDefaults.standard

    @Published var gold: Int { didSet { defaults.set(gold, forKey: "gold") } }
    @Published var pearls: Int { didSet { defaults.set(pearls, forKey: "pearls") } }
    @Published var repairKits: Int { didSet { defaults.set(repairKits, forKey: "repairKits") } }
    @Published var cannonLevel: Int { didSet { defaults.set(cannonLevel, forKey: "cannonLevel") } }
    @Published var trophies: Int { didSet { defaults.set(trophies, forKey: "trophies") } }
    @Published var hullSkin: HullSkin { didSet { defaults.set(hullSkin.rawValue, forKey: "hullSkin") } }
    @Published var ownedSkins: Set<String> { didSet { defaults.set(Array(ownedSkins), forKey: "ownedSkins") } }

    let fleetName = "Your Armada"

    private init() {
        defaults.register(defaults: [
            "gold": 150, "pearls": 40, "repairKits": 3, "cannonLevel": 1, "trophies": 0,
            "hullSkin": HullSkin.oak.rawValue, "ownedSkins": [HullSkin.oak.rawValue],
        ])
        gold = defaults.integer(forKey: "gold")
        pearls = defaults.integer(forKey: "pearls")
        repairKits = defaults.integer(forKey: "repairKits")
        cannonLevel = defaults.integer(forKey: "cannonLevel")
        trophies = defaults.integer(forKey: "trophies")
        hullSkin = HullSkin(rawValue: defaults.string(forKey: "hullSkin") ?? "") ?? .oak
        ownedSkins = Set(defaults.stringArray(forKey: "ownedSkins") ?? [HullSkin.oak.rawValue])
    }

    // MARK: Combat stats

    var cannonDPS: Double { Tuning.baseDPS * (1 + 0.12 * Double(cannonLevel - 1)) }
    /// Opponents get tougher as you climb, and start slightly stronger than you so idle players lose.
    var enemyDPS: Double { Tuning.baseDPS * 1.11 * (1 + Double(trophies) / 400) }

    // MARK: Spending

    var cannonUpgradeCost: Int { 100 * cannonLevel }

    func upgradeCannons() -> Bool {
        guard gold >= cannonUpgradeCost else { return false }
        gold -= cannonUpgradeCost
        cannonLevel += 1
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

    func applyResult(_ outcome: BattleOutcome, kitsLeft: Int) -> (gold: Int, trophies: Int) {
        repairKits = kitsLeft
        let reward = outcome == .victory ? (gold: 100, trophies: 8) : (gold: 20, trophies: -5)
        gold += reward.gold
        trophies = max(0, trophies + reward.trophies)
        return reward
    }
}

enum Rivals {
    static let names = ["Captain Brine", "The Kraken Club", "Salt & Steel", "Red Tide",
                        "Mara the Bold", "Driftwood Gang", "Admiral Nox", "Sea Wolves"]

    static func leaderboard(playerTrophies: Int) -> [(name: String, trophies: Int)] {
        names.enumerated().map { i, name in (name, max(0, playerTrophies + 60 - i * 17)) }
    }
}
