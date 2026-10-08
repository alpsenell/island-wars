import ActivityKit
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
                                drain: s.enemyDPS, tint: skin, alignment: .leading)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    FleetColumn(title: context.attributes.enemyName, hp: s.enemyHP, maxHP: s.maxHP,
                                asOf: s.asOf, drain: s.myDPS, tint: .red, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.isStale ? "Battle decided" : s.lastEvent)
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    if context.isStale {
                        Text("Open Island Wars to claim your spoils").font(.caption2)
                    } else {
                        OrderButtons(state: s)
                    }
                }
            } compactLeading: {
                HullBar(hp: s.myHP, maxHP: s.maxHP, asOf: s.asOf, drainPerSecond: s.enemyDPS,
                        tint: skin, circular: true)
            } compactTrailing: {
                HullBar(hp: s.enemyHP, maxHP: s.maxHP, asOf: s.asOf, drainPerSecond: s.myDPS,
                        tint: .red, circular: true)
            } minimal: {
                HullBar(hp: s.myHP, maxHP: s.maxHP, asOf: s.asOf, drainPerSecond: s.enemyDPS,
                        tint: skin, circular: true)
            }
            .keylineTint(skin)
            .widgetURL(URL(string: "islandwars://battle"))
        }
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
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("⚓ \(context.attributes.myFleetName)").font(.subheadline.bold())
                Spacer()
                Text("vs \(context.attributes.enemyName)").font(.subheadline.bold()).foregroundStyle(.red)
            }
            HullBar(hp: s.myHP, maxHP: s.maxHP, asOf: s.asOf, drainPerSecond: s.enemyDPS, tint: skin)
            HullBar(hp: s.enemyHP, maxHP: s.maxHP, asOf: s.asOf, drainPerSecond: s.myDPS, tint: .red)
            if context.isStale || s.decidedAt <= .now {
                Text("Battle decided — tap to claim your spoils").font(.caption)
            } else {
                HStack {
                    Text(s.lastEvent).font(.caption).lineLimit(1)
                    Spacer()
                    Text(timerInterval: Date.now...s.decidedAt, countsDown: true)
                        .font(.caption.monospacedDigit())
                        .frame(width: 50, alignment: .trailing)
                }
                OrderButtons(state: s)
            }
        }
        .padding()
        .foregroundStyle(.white)
    }
}

private struct OrderButtons: View {
    let state: BattleAttributes.ContentState

    var body: some View {
        HStack {
            Button(intent: FireBroadsideIntent()) {
                Label("Broadside", systemImage: "flame.fill").frame(maxWidth: .infinity)
            }
            .tint(.orange)
            Button(intent: RepairHullIntent()) {
                Label("Repair (\(state.repairKits))", systemImage: "wrench.and.screwdriver.fill")
                    .frame(maxWidth: .infinity)
            }
            .tint(.green)
        }
        .buttonStyle(.borderedProminent)
        .font(.caption.bold())
    }
}
