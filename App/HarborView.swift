import SwiftUI

struct HarborView: View {
    @EnvironmentObject private var battle: BattleManager
    @EnvironmentObject private var wallet: Wallet
    @State private var showShop = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WalletBar()
                    if let attrs = battle.attributes, let state = battle.state {
                        BattleCard(attrs: attrs, state: state)
                    } else {
                        RaidCard()
                    }
                    FleetCard()
                    LeaderboardCard()
                }
                .padding()
            }
            .background(
                LinearGradient(colors: [Color(red: 0.02, green: 0.08, blue: 0.2), .black],
                               startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            )
            .navigationTitle("Island Wars")
            .toolbar {
                Button { showShop = true } label: { Label("Shop", systemImage: "cart.fill") }
            }
            .sheet(isPresented: $showShop) { ShopView() }
            .alert(item: $battle.lastResult) { result in
                Alert(title: Text(result.outcome == .victory ? "🏆 Victory!" : "☠️ Defeat"),
                      message: Text("vs \(result.enemyName)\n+\(result.gold) gold, \(result.trophies >= 0 ? "+" : "")\(result.trophies) trophies"),
                      dismissButton: .default(Text("Back to harbor")))
            }
        }
        .task {
            while !Task.isCancelled {
                await battle.tick()
                try? await Task.sleep(for: .seconds(1))
            }
        }
    }
}

private struct Card<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
    }
}

private struct WalletBar: View {
    @EnvironmentObject private var wallet: Wallet
    var body: some View {
        HStack {
            Label("\(wallet.gold)", systemImage: "dollarsign.circle.fill").foregroundStyle(.yellow)
            Spacer()
            Label("\(wallet.pearls)", systemImage: "circle.hexagongrid.fill").foregroundStyle(.mint)
            Spacer()
            Label("\(wallet.repairKits)", systemImage: "wrench.and.screwdriver.fill").foregroundStyle(.green)
            Spacer()
            Label("\(wallet.trophies)", systemImage: "trophy.fill").foregroundStyle(.orange)
        }
        .font(.headline.monospacedDigit())
    }
}

private struct RaidCard: View {
    @EnvironmentObject private var battle: BattleManager
    var body: some View {
        Card {
            Text("Set sail").font(.title2.bold())
            Text("Start a raid. The battle continues in your Dynamic Island, so you can fire broadsides and patch your hull from any app.")
                .font(.subheadline).foregroundStyle(.secondary)
            Button {
                battle.startRaid()
            } label: {
                Label("Launch Raid", systemImage: "sailboat.fill")
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
        }
    }
}

private struct BattleCard: View {
    @EnvironmentObject private var battle: BattleManager
    @EnvironmentObject private var wallet: Wallet
    let attrs: BattleAttributes
    let state: BattleAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let now = timeline.date
            let skin = HullSkin(rawValue: attrs.hullSkin)?.color ?? .cyan
            Card {
                HStack {
                    Text("⚓ \(attrs.myFleetName)").bold()
                    Spacer()
                    Text("vs \(attrs.enemyName)").bold().foregroundStyle(.red)
                }
                hullRow(label: "Your hull", hp: state.myHP(at: now), tint: skin)
                hullRow(label: "Enemy hull", hp: state.enemyHP(at: now), tint: .red)
                Text(state.lastEvent).font(.callout)
                HStack {
                    Button { Task { await battle.fire() } } label: {
                        let reload = state.cannonReadyAt.timeIntervalSince(now)
                        Label(reload > 0 ? "Reload \(Int(reload.rounded(.up)))s" : "Broadside",
                              systemImage: "flame.fill").frame(maxWidth: .infinity)
                    }
                    .tint(.orange)
                    Button { Task { await battle.repair() } } label: {
                        Label("Repair (\(state.repairKits))", systemImage: "wrench.and.screwdriver.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.green)
                }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.bold())
                Text("Tip: lock your phone or swipe home — the battle keeps going in the Dynamic Island.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func hullRow(label: String, hp: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text("\(Int(hp.rounded())) / \(Int(state.maxHP))").font(.caption.monospacedDigit())
            }
            ProgressView(value: hp, total: state.maxHP).tint(tint)
        }
    }
}

private struct FleetCard: View {
    @EnvironmentObject private var wallet: Wallet
    var body: some View {
        Card {
            Text("Your fleet").font(.title3.bold())
            HStack {
                VStack(alignment: .leading) {
                    Text("Cannons level \(wallet.cannonLevel)")
                    Text("Hull: \(wallet.hullSkin.rawValue)").foregroundStyle(wallet.hullSkin.color)
                }
                Spacer()
                Button("Upgrade · \(wallet.cannonUpgradeCost)g") { _ = wallet.upgradeCannons() }
                    .buttonStyle(.bordered)
                    .disabled(wallet.gold < wallet.cannonUpgradeCost)
            }
        }
    }
}

private struct LeaderboardCard: View {
    @EnvironmentObject private var wallet: Wallet
    var body: some View {
        let rows = (Rivals.leaderboard(playerTrophies: wallet.trophies) + [("You", wallet.trophies)])
            .sorted { $0.1 > $1.1 }
        Card {
            Text("League leaderboard").font(.title3.bold())
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text("\(index + 1).").monospacedDigit().frame(width: 28, alignment: .leading)
                    Text(row.0).fontWeight(row.0 == "You" ? .bold : .regular)
                    Spacer()
                    Label("\(row.1)", systemImage: "trophy.fill").font(.caption.monospacedDigit())
                }
                .foregroundStyle(row.0 == "You" ? .orange : .primary)
            }
        }
    }
}
