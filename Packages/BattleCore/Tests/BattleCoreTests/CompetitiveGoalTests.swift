@testable import BattleCore
import XCTest

/// The criteria from GOAL.md. If one of these fails, the game is not competitive enough yet.
final class CompetitiveGoalTests: XCTestCase {
    let bronze = 1000.0
    let gold = 1400.0

    func testC1_doingNothingLoses() {
        let idle = Simulator.stats(policy: .idle, enemyRating: bronze)
        XCTAssertLessThanOrEqual(idle.winRate, 0.05)
    }

    func testC2_skillBeatsButtonMashing() {
        let skilled = Simulator.stats(policy: .skilled, enemyRating: gold).winRate
        let masher = Simulator.stats(policy: .masher, enemyRating: gold).winRate
        XCTAssertGreaterThanOrEqual(skilled - masher, 0.30, "skilled \(skilled) masher \(masher)")
    }

    func testC3_skillIsRewardedNotGuaranteed() {
        let skilled = Simulator.stats(policy: .skilled, enemyRating: gold).winRate
        XCTAssert((0.65...0.90).contains(skilled), "skilled win rate \(skilled)")
    }

    func testC4_moneyCantBuyRank() {
        let skilled = Simulator.stats(policy: .skilled, enemyRating: gold).winRate
        let whale = Simulator.stats(policy: .whale, enemyRating: gold).winRate
        XCTAssertGreaterThanOrEqual(skilled - whale, 0.15, "skilled \(skilled) whale \(whale)")
    }

    func testC5_matchesStayTense() {
        let skilled = Simulator.stats(policy: .skilled, enemyRating: gold)
        XCTAssertLessThanOrEqual(skilled.medianWinnerHull, 0.45)
    }

    func testC6_ladderSortsBySkill() {
        let skilled = League.from(rating: Simulator.ladder(policy: .skilled))
        let masher = League.from(rating: Simulator.ladder(policy: .masher))
        let idle = League.from(rating: Simulator.ladder(policy: .idle))
        XCTAssertGreaterThan(skilled, masher)
        XCTAssertGreaterThan(masher, idle)
    }

    func testC8_noPayToWin() {
        XCTAssertEqual(Tuning.repairsPerBattle, 2)
        let state = BattleState(seed: 1, start: .now, fleet: FleetStats(cannonLevel: 99),
                                enemy: .bot(rating: 1000, name: "x"), repairKits: 99)
        XCTAssertEqual(state.repairKits, Tuning.repairsPerBattle, "repairs are capped per battle")
        XCTAssertEqual(state.fleet, FleetStats(cannonLevel: Tuning.maxCannonLevel), "upgrades are capped")
    }

    // MARK: Engine sanity

    func testStateIsDeterministicAcrossReplays() {
        let a = Simulator.battle(policy: .skilled, enemyRating: gold, seed: 99)
        let b = Simulator.battle(policy: .skilled, enemyRating: gold, seed: 99)
        XCTAssertEqual(a.outcome, b.outcome)
        XCTAssertEqual(a.duration, b.duration)
    }

    func testAdvancingInOneStepMatchesManySteps() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let initial = BattleState(seed: 5, start: start, fleet: FleetStats(cannonLevel: 1),
                                  enemy: .bot(rating: 1200, name: "x"), repairKits: 0)
        var oneStep = initial
        oneStep.advance(to: start.addingTimeInterval(200))
        var manySteps = initial
        for i in 1...200 { manySteps.advance(to: start.addingTimeInterval(Double(i))) }
        XCTAssertEqual(oneStep.myHP, manySteps.myHP, accuracy: 0.001)
        XCTAssertEqual(oneStep.enemyHP, manySteps.enemyHP, accuracy: 0.001)
    }

    func testBracingAbsorbsAVolley() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        var braced = BattleState(seed: 1, start: start, fleet: FleetStats(cannonLevel: 1),
                                 enemy: .bot(rating: 1000, name: "x"), repairKits: 0)
        var open = braced
        braced.brace(at: braced.nextVolleyAt.addingTimeInterval(-2))
        let after = braced.nextVolleyAt.addingTimeInterval(1)
        braced.advance(to: after)
        open.advance(to: after)
        XCTAssertGreaterThan(braced.myHP - open.myHP, Tuning.volleyDamage * 0.7)
    }

    func testProjectedEndMatchesActualEnd() {
        let start = Date(timeIntervalSinceReferenceDate: 0)
        var s = BattleState(seed: 3, start: start, fleet: FleetStats(cannonLevel: 1),
                            enemy: .bot(rating: 1400, name: "x"), repairKits: 0)
        let projected = s.projectedEnd()
        s.advance(to: start.addingTimeInterval(7200))
        XCTAssertEqual(s.decidedAt, projected)
    }
}
