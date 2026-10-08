import ActivityKit
import BattleCore
import SwiftUI
import WidgetKit

@main
struct IslandWarsWidgetBundle: WidgetBundle {
    var body: some Widget {
        BattleLiveActivity()
    }
}

struct BattleLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: BattleAttributes.self) { context in
            LockScreenBattleView(context: context)
                .activityBackgroundTint(Color(red: 0.03, green: 0.09, blue: 0.18).opacity(0.9))
                .activitySystemActionForegroundColor(.white)
                .widgetURL(URL(string: "islandwars://battle"))
        } dynamicIsland: { context in
            let s = context.state
            let skin = HullSkin(rawValue: context.attributes.hullSkin)?.color ?? .cyan
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    FleetColumn(title: "You", hp: s.myHP, maxHP: s.maxHP, asOf: s.asOf,
                                drain: s.enemy.chipDPS, tint: skin, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FleetColumn(title: s.enemy.name, hp: s.enemyHP, maxHP: s.maxHP, asOf: s.asOf,
                                drain: s.fleet.chipDPS, tint: .red, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    StatusLine(state: s, isStale: context.isStale)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        ChargeBar(lastShotAt: s.lastShotAt)
                        OrderButtons(state: s, compact: true)
                    }
                }
            } compactLeading: {
                HullBar(hp: s.myHP, maxHP: s.maxHP, asOf: s.asOf, drainPerSecond: s.enemy.chipDPS,
                        tint: skin, circular: true)
            } compactTrailing: {
                VolleyCountdown(state: s, isStale: context.isStale)
                    .font(.caption2.monospacedDigit().bold())
                    .frame(maxWidth: 40)
            } minimal: {
                HullBar(hp: s.myHP, maxHP: s.maxHP, asOf: s.asOf, drainPerSecond: s.enemy.chipDPS,
                        tint: skin, circular: true)
            }
            .keylineTint(skin)
            .widgetURL(URL(string: "islandwars://battle"))
        }
    }
}

/// Telegraph: time until the next enemy volley (the moment to Brace).
private struct VolleyCountdown: View {
    let state: BattleState
    let isStale: Bool

    var body: some View {
        if isStale || state.nextVolleyAt <= .now {
            Text("FIRE").foregroundStyle(.orange)
        } else {
            Text(timerInterval: Date.now...state.nextVolleyAt, countsDown: true)
                .foregroundStyle(.red)
                .multilineTextAlignment(.trailing)
        }
    }
}

/// What the player should be thinking about right now.
private struct StatusLine: View {
    let state: BattleState
    let isStale: Bool

    var body: some View {
        Group {
            if isStale || state.nextVolleyAt <= .now {
                Text("💥 Volley landed — enemy reloading, fire now!")
            } else {
                HStack(spacing: 4) {
                    Text("Volley in")
                    Text(timerInterval: Date.now...state.nextVolleyAt, countsDown: true)
                        .monospacedDigit().bold().foregroundStyle(.red)
                        .frame(width: 34)
                    Text("· \(state.lastEvent)").lineLimit(1)
                }
            }
        }
        .font(.caption2)
        .lineLimit(1)
    }
}

private struct FleetColumn: View {
    let title: String
    let hp: Double, maxHP: Double, asOf: Date, drain: Double
    let tint: Color
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title).font(.caption2.bold()).lineLimit(1)
            HullBar(hp: hp, maxHP: maxHP, asOf: asOf, drainPerSecond: drain, tint: tint)
        }
        .padding(.horizontal, 4)
    }
}

private struct LockScreenBattleView: View {
    let context: ActivityViewContext<BattleAttributes>

    var body: some View {
        let s = context.state
        let skin = HullSkin(rawValue: context.attributes.hullSkin)?.color ?? .cyan
        let league = League.from(rating: Double(context.attributes.playerRating))
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("\(league.emoji) You").font(.subheadline.bold())
                Spacer()
                Text("vs \(s.enemy.name) · \(Int(s.enemy.rating))").font(.subheadline.bold()).foregroundStyle(.red)
            }
            HullBar(hp: s.myHP, maxHP: s.maxHP, asOf: s.asOf, drainPerSecond: s.enemy.chipDPS, tint: skin)
            HullBar(hp: s.enemyHP, maxHP: s.maxHP, asOf: s.asOf, drainPerSecond: s.fleet.chipDPS, tint: .red)
            HStack(spacing: 6) {
                Text("Charge").font(.caption2)
                ChargeBar(lastShotAt: s.lastShotAt)
            }
            StatusLine(state: s, isStale: context.isStale)
            OrderButtons(state: s, compact: false)
        }
        .padding()
        .foregroundStyle(.white)
    }
}

private struct OrderButtons: View {
    let state: BattleState
    let compact: Bool

    var body: some View {
        HStack(spacing: 6) {
            Button(intent: FireBroadsideIntent()) {
                Label("Fire", systemImage: "flame.fill").frame(maxWidth: .infinity)
            }
            .tint(.orange)
            Button(intent: BraceIntent()) {
                Label("Brace", systemImage: "shield.fill").frame(maxWidth: .infinity)
            }
            .tint(.blue)
            Button(intent: RepairHullIntent()) {
                Label(compact ? "\(state.repairsLeft)" : "Repair (\(state.repairsLeft))",
                      systemImage: "wrench.and.screwdriver.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.green)
        }
        .buttonStyle(.borderedProminent)
        .font(.caption.bold())
    }
}
