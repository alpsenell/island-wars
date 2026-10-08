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
