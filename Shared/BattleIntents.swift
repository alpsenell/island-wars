import AppIntents

/// Buttons in the Dynamic Island / Lock Screen. LiveActivityIntents run in the app process.
struct FireBroadsideIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Fire Broadside"
    init() {}

    func perform() async throws -> some IntentResult {
        await BattleManager.shared.fire()
        return .result()
    }
}

struct RepairHullIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Repair Hull"
    init() {}

    func perform() async throws -> some IntentResult {
        await BattleManager.shared.repair()
        return .result()
    }
}
