import BattleCore
import SwiftUI

struct HarborView: View {
    @EnvironmentObject private var battle: BattleManager
    @EnvironmentObject private var wallet: Wallet
    @State private var showShop = false
    @State private var showHowTo = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    WalletBar()
                    if let attrs = battle.attributes, let state = battle.state {
                        BattleCard(attrs: attrs, state: state)
                    } else {
                        RankCard()
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
                ToolbarItem(placement: .topBarLeading) {
                    Button { showHowTo = true } label: { Label("How to play", systemImage: "questionmark.circle") }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showShop = true } label: { Label("Shop", systemImage: "cart.fill") }
                }
            }
            .sheet(isPresented: $showShop) { ShopView() }
            .sheet(isPresented: $showHowTo) { HowToPlayView() }
            .alert(item: $battle.lastResult) { result in
                let sign = result.ratingChange >= 0 ? "+" : ""
                return Alert(title: Text(result.outcome == .victory ? "🏆 Victory!" : "☠️ Defeat"),
                             message: Text("vs \(result.enemyName)\nRating \(sign)\(result.ratingChange) → \(result.newRating)\n+\(result.gold) gold"),
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
        }
        .font(.headline.monospacedDigit())
    }
}

private struct RankCard: View {
    @EnvironmentObject private var wallet: Wallet
    var body: some View {
        let league = wallet.league
        let next = League.allCases.first { $0 > league }
        Card {
            HStack(alignment: .firstTextBaseline) {
                Text("\(league.emoji) \(league.rawValue)").font(.title.bold())
                Spacer()
                Text(verbatim: "\(wallet.rating)").font(.title2.monospacedDigit().bold()).foregroundStyle(.orange)
            }
            if let next {
                let span = next.floor - league.floor
                ProgressView(value: Double(wallet.rating) - league.floor, total: span).tint(.orange)
                Text("\(Int(next.floor) - wallet.rating) to \(next.emoji) \(next.rawValue)")
                    .font(.caption).foregroundStyle(.secondary)
            } else {
                Text("Top league. Defend it.").font(.caption).foregroundStyle(.secondary)
            }
            Text(verbatim: "Record \(wallet.wins)W – \(wallet.losses)L · Best \(wallet.bestRating)")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct RaidCard: View {
    @EnvironmentObject private var battle: BattleManager
    var body: some View {
        Card {
            Text("Ranked raid").font(.title2.bold())
            Text("You'll face a fleet near your rating. The battle runs in your Dynamic Island: brace before each volley, then fire while they reload.")
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
    let attrs: BattleAttributes
    let state: BattleState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { timeline in
            let now = timeline.date
            var s = state
            let _ = s.advance(to: now)
            let skin = HullSkin(rawValue: attrs.hullSkin)?.color ?? .cyan
            let untilVolley = max(0, s.nextVolleyAt.timeIntervalSince(now))
            Card {
                HStack {
                    Text("⚓ \(attrs.myFleetName)").bold()
                    Spacer()
                    Text("vs \(s.enemy.name) · \(Int(s.enemy.rating))").bold().foregroundStyle(.red)
                }
                hullRow(label: "Your hull", hp: s.myHP, max: s.maxHP, tint: skin)
                hullRow(label: "Enemy hull", hp: s.enemyHP, max: s.maxHP, tint: .red)

                HStack {
                    if s.isExposed(at: now) {
                        Text("🎯 Enemy reloading — FIRE!").bold().foregroundStyle(.orange)
                    } else {
                        Text("Next volley in \(Int(untilVolley.rounded(.up)))s")
                            .foregroundStyle(untilVolley <= Tuning.braceWindow ? .red : .primary)
                            .bold(untilVolley <= Tuning.braceWindow)
                    }
                    Spacer()
                    if s.isBracing(at: now) { Text("🛡️ Braced").foregroundStyle(.blue) }
                }
                .font(.callout.monospacedDigit())

                VStack(alignment: .leading, spacing: 4) {
                    Text("Broadside charge \(Int(s.charge(at: now) * 100))%").font(.caption)
                    ProgressView(value: s.charge(at: now)).tint(.orange)
                }
                Text(s.lastEvent).font(.callout)

                HStack {
                    Button { Task { await battle.fire() } } label: {
                        let reload = Tuning.reload - now.timeIntervalSince(s.lastShotAt)
                        Label(reload > 0 ? "\(Int(reload.rounded(.up)))s" : "Fire", systemImage: "flame.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.orange)
                    Button { Task { await battle.brace() } } label: {
                        let cooldown = s.braceReadyAt.timeIntervalSince(now)
                        Label(cooldown > 0 ? "\(Int(cooldown.rounded(.up)))s" : "Brace", systemImage: "shield.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.blue)
                    Button { Task { await battle.repair() } } label: {
                        Label("\(s.repairsLeft)", systemImage: "wrench.and.screwdriver.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .tint(.green)
                    .disabled(s.repairsLeft == 0)
                }
                .buttonStyle(.borderedProminent)
                .font(.subheadline.bold())
                Text("Lock your phone or swipe home — keep fighting from the Dynamic Island.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func hullRow(label: String, hp: Double, max: Double, tint: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label).font(.caption)
                Spacer()
                Text(verbatim: "\(Int(hp.rounded())) / \(Int(max))").font(.caption.monospacedDigit())
            }
            ProgressView(value: hp, total: max).tint(tint)
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
                    Text("Cannons level \(wallet.cannonLevel)/\(Tuning.maxCannonLevel)")
                    Text("Hull: \(wallet.hullSkin.rawValue)").foregroundStyle(wallet.hullSkin.color)
                }
                Spacer()
                if wallet.cannonsMaxed {
                    Text("Maxed").foregroundStyle(.secondary)
                } else {
                    Button("Upgrade · \(wallet.cannonUpgradeCost)g") { _ = wallet.upgradeCannons() }
                        .buttonStyle(.bordered)
                        .disabled(wallet.gold < wallet.cannonUpgradeCost)
                }
            }
            Text("Upgrades are small (+\(Int(Tuning.upgradeBonusPerLevel * 100))% per level) — skill wins battles.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

private struct LeaderboardCard: View {
    @EnvironmentObject private var wallet: Wallet
    var body: some View {
        // Prototype: rating-adjacent bot captains. Real players arrive with Game Center.
        let rivals = EnemyProfile.names.prefix(8).enumerated().map { i, name in
            (name, max(Int(Rating.floor), wallet.rating + 140 - i * 40))
        }
        let rows = (rivals + [("You", wallet.rating)]).sorted { $0.1 > $1.1 }
        Card {
            Text("\(wallet.league.emoji) \(wallet.league.rawValue) leaderboard").font(.title3.bold())
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                HStack {
                    Text("\(index + 1).").monospacedDigit().frame(width: 28, alignment: .leading)
                    Text(row.0).fontWeight(row.0 == "You" ? .bold : .regular)
                    Spacer()
                    Text(verbatim: "\(row.1)").font(.callout.monospacedDigit())
                }
                .foregroundStyle(row.0 == "You" ? .orange : .primary)
            }
        }
    }
}

private struct HowToPlayView: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            List {
                Label("Enemy volleys are telegraphed by a countdown. Tap **Brace** in the last \(Int(Tuning.braceWindow))s to absorb \(Int(Tuning.braceReduction * 100))% of the damage.", systemImage: "shield.fill")
                Label("Right after a volley the enemy reloads for \(Int(Tuning.exposedWindow))s. Broadsides fired then hit \(String(format: "%.1f", Tuning.exposedMultiplier))× harder and can't be braced.", systemImage: "scope")
                Label("Broadsides charge for \(Int(Tuning.fullCharge))s. A full charge hits far harder than spamming.", systemImage: "flame.fill")
                Label("You can use up to \(Tuning.repairsPerBattle) repair kits per battle.", systemImage: "wrench.and.screwdriver.fill")
                Label("Win to climb: Bronze → Silver → Gold → Platinum → Legend. Opponents are matched to your rating.", systemImage: "trophy.fill")
            }
            .navigationTitle("How to play")
            .toolbar { Button("Got it") { dismiss() } }
        }
    }
}
