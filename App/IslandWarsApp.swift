import SwiftUI

@main
struct IslandWarsApp: App {
    @StateObject private var battle = BattleManager.shared
    @StateObject private var wallet = Wallet.shared

    var body: some Scene {
        WindowGroup {
            HarborView()
                .environmentObject(battle)
                .environmentObject(wallet)
                .preferredColorScheme(.dark)
        }
    }
}
