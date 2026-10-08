# Island Wars

A competitive iOS naval strategy game where battles run live in the **Dynamic Island** and on the **Lock Screen** (Live Activities). Launch a raid, then fire broadsides and patch your hull from any app.

## Run

Open `IslandWars.xcodeproj` in Xcode 26+, pick an iPhone 15 Pro or newer simulator (Dynamic Island), and Run.
The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate`.

## How to play

Enemy volleys are telegraphed by a countdown in the Dynamic Island. **Brace** just before impact, then
**Fire** a charged broadside while the enemy reloads. Win to climb Bronze → Silver → Gold → Platinum → Legend.

## Competitive goal

See [GOAL.md](GOAL.md): measurable criteria (skill beats mashing, money can't buy rank, tense matches, a ladder
that sorts by skill) enforced by simulation tests:

```bash
cd Packages/BattleCore && swift test && swift run -c release balance-report
```

## Layout

- `Packages/BattleCore` — deterministic battle engine, Elo/leagues, bots, balance simulator + goal tests

- `Shared/BattleModel.swift` — Live Activity attributes and shared timer-driven views
- `Shared/BattleManager.swift` — runs the battle, keeps the Live Activity in sync
- `Shared/BattleIntents.swift` — `LiveActivityIntent`s behind the Dynamic Island buttons
- `Shared/Wallet.swift` — Gold (soft) / Pearls (hard) economy, upgrades, rewards
- `Widget/` — Dynamic Island + Lock Screen UI
- `App/` — harbor, battle, leaderboard and shop screens

## Status

Prototype. Rating-matched AI opponents, ~4-minute battles, and simulated purchases — real money must go through StoreKit 2 In-App Purchase before release.
