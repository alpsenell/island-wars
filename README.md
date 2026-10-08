# Island Wars

A competitive iOS naval strategy game where battles run live in the **Dynamic Island** and on the **Lock Screen** (Live Activities). Launch a raid, then fire broadsides and patch your hull from any app.

## Run

Open `IslandWars.xcodeproj` in Xcode 26+, pick an iPhone 15 Pro or newer simulator (Dynamic Island), and Run.
The project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen): `xcodegen generate`.

## Layout

- `Shared/BattleModel.swift` — battle math (closed-form over time) and `Tuning` knobs
- `Shared/BattleManager.swift` — runs the battle, keeps the Live Activity in sync
- `Shared/BattleIntents.swift` — `LiveActivityIntent`s behind the Dynamic Island buttons
- `Shared/Wallet.swift` — Gold (soft) / Pearls (hard) economy, upgrades, rewards
- `Widget/` — Dynamic Island + Lock Screen UI
- `App/` — harbor, battle, leaderboard and shop screens

## Status

Prototype. AI opponents, 5-minute battles, and simulated purchases — real money must go through StoreKit 2 In-App Purchase before release.
