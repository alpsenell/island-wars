import SwiftUI

struct ShopView: View {
    @EnvironmentObject private var wallet: Wallet
    @EnvironmentObject private var battle: BattleManager
    @Environment(\.dismiss) private var dismiss
    @State private var pendingPack: PearlPack?

    struct PearlPack: Identifiable {
        let id = UUID()
        let pearls: Int
        let price: String
        let tag: String?
    }

    private let packs = [
        PearlPack(pearls: 80, price: "$0.99", tag: "Starter deal"),
        PearlPack(pearls: 500, price: "$4.99", tag: nil),
        PearlPack(pearls: 1200, price: "$9.99", tag: "Best value"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Pearls") {
                    ForEach(packs) { pack in
                        HStack {
                            Label("\(pack.pearls) pearls", systemImage: "circle.hexagongrid.fill")
                                .foregroundStyle(.mint)
                            if let tag = pack.tag {
                                Text(tag).font(.caption2.bold()).padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.orange.opacity(0.3), in: Capsule())
                            }
                            Spacer()
                            Button(pack.price) { pendingPack = pack }.buttonStyle(.borderedProminent)
                        }
                    }
                }
                Section("Supplies") {
                    HStack {
                        Label("3 repair kits", systemImage: "wrench.and.screwdriver.fill")
                        Spacer()
                        Button("25 pearls") {
                            if wallet.buyRepairKits(count: 3, pearlCost: 25) {
                                Task { await battle.addRepairKits(3) }
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(wallet.pearls < 25)
                    }
                }
                Section("Hull skins (cosmetic)") {
                    ForEach(HullSkin.allCases) { skin in
                        HStack {
                            Circle().fill(skin.color).frame(width: 18, height: 18)
                            Text(skin.rawValue)
                            Spacer()
                            if wallet.hullSkin == skin {
                                Text("Equipped").foregroundStyle(.secondary)
                            } else if wallet.ownedSkins.contains(skin.rawValue) {
                                Button("Equip") { _ = wallet.buyOrEquip(skin) }.buttonStyle(.bordered)
                            } else {
                                Button("\(skin.pearlPrice) pearls") { _ = wallet.buyOrEquip(skin) }
                                    .buttonStyle(.bordered)
                                    .disabled(wallet.pearls < skin.pearlPrice)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Shop · \(wallet.pearls) pearls")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { Button("Done") { dismiss() } }
            .alert("Simulated purchase", isPresented: .init(get: { pendingPack != nil },
                                                             set: { if !$0 { pendingPack = nil } })) {
                Button("Buy") {
                    if let pack = pendingPack { wallet.simulatePearlPurchase(pack.pearls) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Prototype only. No real money is charged. The shipping build will use StoreKit 2 In-App Purchase.")
            }
        }
    }
}
