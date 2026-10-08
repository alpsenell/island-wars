# Goal: Island Wars is competitive enough to play

"Competitive" is measurable here. Every criterion below is an automated simulation test in
`Packages/BattleCore/Tests/BattleCoreTests/CompetitiveGoalTests.swift`, run with:

```bash
cd Packages/BattleCore && swift test
swift run balance-report   # prints the scoreboard below
```

The simulator pits scripted player **policies** against rating-matched bot fleets, thousands of times:

| Policy  | Plays like |
|---------|------------|
| idle    | Launches a raid and never touches it again |
| masher  | Hits every button the moment it is available, no timing |
| skilled | Reads the telegraphs: braces just before enemy volleys, fires charged broadsides into the enemy's reload window, repairs when low |
| whale   | Masher with maxed paid/earned upgrades and full repair kits |

## Criteria

| # | Criterion | Why it matters | Target |
|---|-----------|----------------|--------|
| C1 | **Doing nothing loses.** Idle vs a Bronze bot | The Dynamic Island has to be worth glancing at | idle wins ≤ 5% |
| C2 | **Skill beats button-mashing.** Skilled vs masher, same Gold-rated bot | Timing decisions, not tap speed, decide matches | skilled − masher ≥ 30 pp |
| C3 | **Skilled play is rewarded, not guaranteed.** Skilled vs a Gold-rated bot | Wins feel earned | 65–90% win |
| C4 | **Money can't buy rank.** Skilled free player vs whale, same bot | Fair ladder → players trust it → they keep playing (and buy cosmetics) | skilled ≥ whale + 15 pp |
| C5 | **Matches stay tense.** Median hull left for the winner, skilled vs Gold bot | Close fights are what people come back for | ≤ 45% hull |
| C6 | **The ladder sorts players by skill.** 300 ranked battles each, Elo matchmaking | Rank must mean something | skilled league > masher league > idle league |
| C7 | **The whole match is playable from the Dynamic Island.** | Core promise of the game | every order (Fire, Brace, Repair) is a Live Activity button; the next enemy volley is telegraphed with a countdown |
| C8 | **No pay-to-win items.** | Fairness + App Store trust | Pearls buy only cosmetics/convenience; repairs capped per battle; cannon upgrades capped and earned with Gold |

## Iteration plan

1. **Measure.** Extract the battle engine into a testable package, build the simulator, record a baseline.
2. **Skill mechanics.** Telegraphed enemy volleys + Brace, charge-up broadsides, a punishable enemy reload window, bot AI that braces and repairs.
3. **Fairness.** Per-battle repair cap, capped upgrades, Pearls cosmetic-only.
4. **Ranked ladder.** Elo rating, leagues (Bronze → Legend), rating-matched bots.
5. **Tune** until every criterion passes; wire the app + Dynamic Island to the new engine.

## Scoreboard

_Filled in by each iteration — see the bottom of this file._

### Iteration 1 — baseline (original prototype)
Only Fire (on cooldown) and Repair (unlimited, bought with Pearls). No timing decisions, so skilled play
≈ button-mashing (C2 ✗), and Pearls buy unlimited repairs (C4 ✗, C8 ✗). No ladder (C6 ✗).

### Iteration 2–5 — current (`swift run -c release balance-report`)

```
policy        900    1000    1100    1200    1300    1400    1500    1600    1700    1800
idle         0.0%    0.0%    0.0%    0.0%    0.0%    0.0%    0.0%    0.0%    0.0%    0.0%
masher     100.0%  100.0%   96.2%   38.5%    1.9%    0.0%    0.0%    0.0%    0.0%    0.0%
skilled    100.0%  100.0%   99.8%   98.7%   93.3%   70.3%   19.2%    0.0%    0.0%    0.0%
whale      100.0%  100.0%  100.0%   82.7%   17.5%    0.6%    0.0%    0.0%    0.0%    0.0%

Skilled vs Gold bot: median winner hull 13.1%, median length 266s
Ranked ladder: idle 800 Bronze · masher 1179 Silver · whale 1243 Silver · skilled 1467 Gold
```

| # | Target | Result | |
|---|--------|--------|---|
| C1 | idle wins ≤ 5% | 0% | ✅ |
| C2 | skilled − masher ≥ 30 pp | 70 pp | ✅ |
| C3 | skilled 65–90% vs Gold | 70% | ✅ |
| C4 | skilled ≥ whale + 15 pp | +70 pp | ✅ |
| C5 | winner hull ≤ 45% | 13% | ✅ |
| C6 | skilled > masher > idle league | Gold > Silver > Bronze | ✅ |
| C7 | all orders + telegraph in Dynamic Island | Fire / Brace / Repair buttons with cooldown timers, volley countdown in compact trailing, charge meter | ✅ verified in iPhone 17 Pro simulator |
| C8 | no pay-to-win | 2 repairs/battle cap, cannons capped at +12%, Pearls cosmetic/convenience | ✅ |

### Iteration 6 — simulator playtest fixes
Playing on the iPhone 17 Pro simulator surfaced issues the simulation couldn't:
- Tapping an order on cooldown overwrote the volley report ("Crew still recovering"), hiding what just
  happened. Orders on cooldown are now silent no-ops; Fire/Brace buttons show live cooldown timers instead.
- **Rage-quit dodge:** dismissing the Live Activity + force-quitting made a losing battle vanish with no
  rating loss. Battles are now persisted and always resolve; a restored battle returns to the Dynamic Island.
- Bronze progress bar measured from 0 instead of the 800 floor; ratings rendered with locale grouping (1.000).

### Known gaps (next milestone)
- Opponents are rating-matched bots; real async PvP needs Game Center or a server.
- The Live Activity can't redraw the instant a volley lands while the app is closed (no push server yet);
  it goes stale at the volley and tells the player to fire, then corrects on the next order.
- Purchases are simulated; StoreKit 2 must be wired before release.
