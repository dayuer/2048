import XCTest
@testable import Game2048

/// 谈判内核（Phase 2）：开始尽调 → 打策略包（筹码×倍率）→ 见好就收/击破/交易流产。
/// 知识教学核心：错配卡牌对特定对手无效（0 分 + 嘲讽），复盘报告点出错在哪。
final class NegotiationTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 0)

    /// 造一个可控的谈判局面：指定 NPC 与固定手牌。
    private func makeNegotiatingState(
        npcID: String = "chen",
        valuation: Int = 8000,
        commission: Int = 30,
        hand: [String]
    ) -> (RainmakerState, UUID) {
        var rng = SeededGenerator(seed: 7)
        var state = RainmakerEngine.newRun(using: &rng, now: day0)
        let deal = DealOffer(
            id: UUID(), npcID: npcID, title: "测试项目", valuation: valuation,
            commission: commission, apCost: 1, status: .offered
        )
        state.deals.append(deal)
        XCTAssertTrue(NegotiationEngine.start(dealID: deal.id, state: &state, using: &rng, now: day0))
        state.activeNegotiation?.hand = hand
        return (state, deal.id)
    }

    private func card(_ id: String) -> TalkCard {
        guard let card = CardCatalog.card(id: id) else {
            XCTFail("卡池缺少 \(id)")
            fatalError()
        }
        return card
    }

    // MARK: - 开始尽调

    func testStartConsumesAPAndStakesReputation() {
        var rng = SeededGenerator(seed: 7)
        var state = RainmakerEngine.newRun(using: &rng, now: day0)
        guard let deal = state.deals.first(where: { $0.status == .offered }) else {
            return XCTFail("开局应有项目")
        }
        let apBefore = state.ap
        let repBefore = state.reputation

        XCTAssertTrue(NegotiationEngine.start(dealID: deal.id, state: &state, using: &rng, now: day0))

        XCTAssertEqual(state.ap, apBefore - deal.apCost)
        XCTAssertEqual(state.reputation, repBefore - RainmakerBalance.negotiationRepStake)
        XCTAssertEqual(state.deals.first { $0.id == deal.id }?.status, .negotiating)
        XCTAssertEqual(state.activeNegotiation?.dealID, deal.id)
        XCTAssertEqual(state.activeNegotiation?.hand.count, RainmakerBalance.handSize)
    }

    func testStartFailsWithoutAPOrRepOrWhenBusy() {
        var rng = SeededGenerator(seed: 7)
        var state = RainmakerEngine.newRun(using: &rng, now: day0)
        let deals = state.deals.filter { $0.status == .offered }
        XCTAssertGreaterThanOrEqual(deals.count, 2, "该种子开局应有两单")

        // 无工时
        var noAP = state
        noAP.ap = 0
        XCTAssertFalse(NegotiationEngine.start(dealID: deals[0].id, state: &noAP, using: &rng, now: day0))

        // 信誉不够抵押
        var noRep = state
        noRep.reputation = RainmakerBalance.negotiationRepStake - 1
        XCTAssertFalse(NegotiationEngine.start(dealID: deals[0].id, state: &noRep, using: &rng, now: day0))

        // 已有进行中的谈判
        XCTAssertTrue(NegotiationEngine.start(dealID: deals[0].id, state: &state, using: &rng, now: day0))
        XCTAssertFalse(NegotiationEngine.start(dealID: deals[1].id, state: &state, using: &rng, now: day0))
    }

    // MARK: - 出牌算分

    func testPlayValidCardDealsChipsTimesMult() {
        var (state, _) = makeNegotiatingState(hand: ["finance-hole", "team-halo"])
        let defenseBefore = state.activeNegotiation!.defense
        let played = card("finance-hole")

        var rng = SeededGenerator(seed: 1)
        let outcome = NegotiationEngine.play(cardID: "finance-hole", state: &state, using: &rng, now: day0)

        let expected = Int(Double(played.chips) * played.mult)
        XCTAssertEqual(outcome?.damage, expected)
        XCTAssertEqual(outcome?.invalid, false)
        XCTAssertEqual(state.activeNegotiation?.defense, max(0, defenseBefore - expected))
        XCTAssertEqual(state.activeNegotiation?.hand, ["team-halo"], "打出的牌应离手")
    }

    /// 知识教学核心：对早期无利润公司打市盈率 = 0 分 + 记入复盘。
    func testInvalidCardScoresZeroAgainstMismatchedNPC() {
        // chen 是 preRevenue（SaaS 早期），市盈率质疑对其无效
        var (state, _) = makeNegotiatingState(npcID: "chen", hand: ["pe-ratio", "team-halo"])
        let defenseBefore = state.activeNegotiation!.defense

        var rng = SeededGenerator(seed: 1)
        let outcome = NegotiationEngine.play(cardID: "pe-ratio", state: &state, using: &rng, now: day0)

        XCTAssertEqual(outcome?.damage, 0)
        XCTAssertEqual(outcome?.invalid, true)
        XCTAssertEqual(state.activeNegotiation?.defense, defenseBefore, "无效出牌不掉防线")
        XCTAssertEqual(state.activeNegotiation?.playedInvalid, ["pe-ratio"], "复盘要点名错牌")
    }

    func testSameCardValidAgainstDifferentNPC() {
        // zhou 是 traditional（盈利餐饮），市盈率质疑对其有效
        var (state, _) = makeNegotiatingState(npcID: "zhou", hand: ["pe-ratio", "team-halo"])
        var rng = SeededGenerator(seed: 1)
        let outcome = NegotiationEngine.play(cardID: "pe-ratio", state: &state, using: &rng, now: day0)
        XCTAssertEqual(outcome?.invalid, false)
        XCTAssertGreaterThan(outcome?.damage ?? 0, 0)
    }

    // MARK: - 见好就收 / 击破

    func testSignLockedUntilThreshold() {
        let (state, _) = makeNegotiatingState(valuation: 8000, hand: ["team-halo"])
        // 开局防线满，不能签
        XCTAssertFalse(NegotiationEngine.canSign(state: state))
    }

    func testSignPaysProportionalCommissionAndReturnsStake() {
        var (state, dealID) = makeNegotiatingState(valuation: 8000, commission: 30, hand: ["team-halo"])
        let session = state.activeNegotiation!
        // 手动压到恰好过签约线
        let signable = Int(Double(session.defenseMax) * RainmakerBalance.signUnlockRatio)
        state.activeNegotiation!.defense = signable
        XCTAssertTrue(NegotiationEngine.canSign(state: state))

        let cashBefore = state.cash
        let repBefore = state.reputation
        var rng = SeededGenerator(seed: 1)
        let payout = NegotiationEngine.sign(state: &state, using: &rng, now: day0)

        let expected = Int(Double(30) * (1 - Double(signable) / Double(session.defenseMax)))
        XCTAssertEqual(payout, expected)
        XCTAssertEqual(state.cash, cashBefore + expected)
        XCTAssertEqual(
            state.reputation,
            repBefore + RainmakerBalance.negotiationRepStake + RainmakerBalance.dealReputationReward,
            "签约退还抵押 + 信誉奖励"
        )
        XCTAssertEqual(state.deals.first { $0.id == dealID }?.status, .won)
        XCTAssertNil(state.activeNegotiation)
    }

    func testBreakingDefensePaysFullCommission() {
        var (state, dealID) = makeNegotiatingState(valuation: 3000, commission: 30, hand: ["finance-hole"])
        state.activeNegotiation!.defense = 1  // 一击必破
        let cashBefore = state.cash

        var rng = SeededGenerator(seed: 1)
        let outcome = NegotiationEngine.play(cardID: "finance-hole", state: &state, using: &rng, now: day0)

        XCTAssertEqual(outcome?.broke, true)
        XCTAssertEqual(state.cash, cashBefore + 30, "击破拿全额佣金")
        XCTAssertEqual(state.deals.first { $0.id == dealID }?.status, .won)
        XCTAssertNil(state.activeNegotiation)
    }

    // MARK: - 交易流产（爆仓）

    func testBustWhenHandEmptiesBeforeThreshold() {
        var (state, dealID) = makeNegotiatingState(valuation: 15000, hand: ["team-halo"])
        let repBefore = state.reputation

        var rng = SeededGenerator(seed: 1)
        let outcome = NegotiationEngine.play(cardID: "team-halo", state: &state, using: &rng, now: day0)

        XCTAssertEqual(outcome?.busted, true)
        XCTAssertEqual(state.deals.first { $0.id == dealID }?.status, .busted)
        XCTAssertEqual(state.reputation, repBefore, "抵押已在入场扣除，爆仓不退")
        XCTAssertNil(state.activeNegotiation)
    }

    /// 对赌协议：高倍率，但爆仓时信誉反噬翻倍。
    func testVAMDoublesReputationLossOnBust() {
        var (state, _) = makeNegotiatingState(valuation: 15000, hand: ["vam", "team-halo"])
        let repBefore = state.reputation

        var rng = SeededGenerator(seed: 1)
        _ = NegotiationEngine.play(cardID: "vam", state: &state, using: &rng, now: day0)
        let outcome = NegotiationEngine.play(cardID: "team-halo", state: &state, using: &rng, now: day0)

        XCTAssertEqual(outcome?.busted, true)
        XCTAssertEqual(
            state.reputation,
            repBefore - RainmakerBalance.negotiationRepStake,
            "对赌爆仓：抵押之外再扣一份"
        )
    }

    /// 优先清算权：保本条款——任何时候可签，且佣金保底 40%。
    func testLiquidationPreferenceUnlocksSignWithFloor() {
        var (state, _) = makeNegotiatingState(valuation: 8000, commission: 30, hand: ["liq-pref", "team-halo"])
        var rng = SeededGenerator(seed: 1)
        _ = NegotiationEngine.play(cardID: "liq-pref", state: &state, using: &rng, now: day0)

        XCTAssertTrue(NegotiationEngine.canSign(state: state), "清算权在手，防线未到阈值也可签")
        let cashBefore = state.cash
        let payout = NegotiationEngine.sign(state: &state, using: &rng, now: day0)
        let floor = Int(Double(30) * RainmakerBalance.payoutFloorRatio)
        XCTAssertGreaterThanOrEqual(payout ?? 0, floor)
        XCTAssertEqual(state.cash, cashBefore + (payout ?? 0))
    }

    // MARK: - 与日结算的联动

    func testEndDayForcesBustOnActiveNegotiation() {
        var (state, dealID) = makeNegotiatingState(hand: ["team-halo", "finance-hole"])
        var rng = SeededGenerator(seed: 1)
        RainmakerEngine.endDay(state: &state, using: &rng, now: day0)

        XCTAssertNil(state.activeNegotiation, "拖过今晚，对方撤单")
        XCTAssertEqual(state.deals.first { $0.id == dealID }?.status, .busted)
    }

    // MARK: - 存档

    func testCodableRoundTripWithActiveSession() throws {
        let (state, _) = makeNegotiatingState(hand: ["team-halo", "vam"])
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(RainmakerState.self, from: data)
        XCTAssertEqual(decoded, state)
    }
}
