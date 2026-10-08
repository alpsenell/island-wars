import ActivityKit
import BattleCore
import Foundation
import SwiftUI

/// Live Activity payload. The whole deterministic battle state travels with it,
/// so the Dynamic Island can render countdowns and draining hulls without updates.
struct BattleAttributes: ActivityAttributes {
    typealias ContentState = BattleState

    var myFleetName: String
    var hullSkin: String
    var playerRating: Int
}

extension BattleState {
    /// Re-render the Live Activity when the next volley lands (it may have changed hull values).
    var staleDate: Date { min(nextVolleyAt, projectedEnd()) }
}

enum HullSkin: String, CaseIterable, Identifiable {
    case oak = "Oak", obsidian = "Obsidian", gilded = "Gilded", coral = "Coral"
    var id: String { rawValue }
    var color: Color {
        switch self {
        case .oak: .cyan
        case .obsidian: .purple
        case .gilded: .yellow
        case .coral: .pink
        }
    }
    var pearlPrice: Int { self == .oak ? 0 : 120 }
}

/// Hull bar that drains on its own using a timer-driven ProgressView (no updates needed).
struct HullBar: View {
    let hp: Double
    let maxHP: Double
    let asOf: Date
    let drainPerSecond: Double
    let tint: Color
    var circular = false

    var body: some View {
        Group {
            if hp <= 0 {
                ProgressView(value: 0)
            } else {
                let empty = asOf.addingTimeInterval(hp / drainPerSecond)
                let start = empty.addingTimeInterval(-maxHP / drainPerSecond)
                ProgressView(timerInterval: start...empty, countsDown: true,
                             label: { EmptyView() }, currentValueLabel: { EmptyView() })
            }
        }
        .tint(tint)
        .modifier(CircularIf(circular: circular))
    }
}

/// Broadside charge meter that fills on its own after each shot.
struct ChargeBar: View {
    let lastShotAt: Date

    var body: some View {
        let start = lastShotAt.addingTimeInterval(Tuning.reload)
        let full = lastShotAt.addingTimeInterval(Tuning.fullCharge)
        ProgressView(timerInterval: start...full, countsDown: false,
                     label: { EmptyView() }, currentValueLabel: { EmptyView() })
            .tint(.orange)
    }
}

private struct CircularIf: ViewModifier {
    let circular: Bool
    func body(content: Content) -> some View {
        if circular { content.progressViewStyle(.circular) } else { content }
    }
}
