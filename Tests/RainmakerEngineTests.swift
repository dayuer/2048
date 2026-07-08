import XCTest
@testable import Game2048

/// 《顶级掮客》Phase 1 经营内核：资源（资金/信誉/AP）、接单、每日结算、破产。
/// 纯逻辑、注入 RNG 保证同种子同结果。
final class RainmakerEngineTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 0)

    private func newRun(seed: UInt64 = 7) -> RainmakerState {
        var rng = SeededGenerator(seed: seed)
        return RainmakerEngine.newRun(using: &rng, now: day0)
    }

    private func firstOffered(_ state: RainmakerState) -> DealOffer {
        guard let deal = state.deals.first(where: { $0.status == .offered }) else {
            XCTFail("开局应至少有一张可接的项目卡")
            return DealOffer(
                id: UUID(), npcID: "", title: "", valuation: 0,
                commission: 0, apCost: 1, status: .offered
            )
        }
        return deal
    }

    // MARK: - 开局

    func testNewRunInitialResources() {
        let state = newRun()
        XCTAssertEqual(state.day, 1)
        XCTAssertEqual(state.cash, RainmakerBalance.startCash)
        XCTAssertEqual(state.reputation, RainmakerBalance.startReputation)
        XCTAssertEqual(state.ap, RainmakerBalance.apPerDay)
        XCTAssertFalse(state.isGameOver)
    }

    func testNewRunOffersDealsWithMatchingThreadEvents() {
        let state = newRun()
        let offered = state.deals.filter { $0.status == .offered }
        XCTAssertFalse(offered.isEmpty, "开局应有可接项目")
        for deal in offered {
            let thread = state.threads.first { $0.id == deal.npcID }
            XCTAssertNotNil(thread, "项目卡必须挂在对应 NPC 线程里")
            let hasCard = thread?.events.contains {
                if case let .dealOffer(_, dealID, _) = $0 { return dealID == deal.id }
                return false
            }
            XCTAssertEqual(hasCard, true)
        }
    }

    func testNewRunHasAssistantWelcome() {
        let state = newRun()
        let assistant = state.threads.first { $0.id == RainmakerEngine.assistantNPCID }
        XCTAssertNotNil(assistant, "秘书线程恒存在，承载每日结算简报")
        XCTAssertFalse(assistant?.events.isEmpty ?? true)
    }

    func testNewRunSameSeedIsDeterministic() {
        XCTAssertEqual(newRun(seed: 42), newRun(seed: 42))
    }

    // MARK: - 每日结算

    func testEndDayExpiresUnacceptedOffers() {
        var state = newRun()
        let deal = firstOffered(state)

        var rng = SeededGenerator(seed: 1)
        RainmakerEngine.endDay(state: &state, using: &rng, now: day0)

        XCTAssertEqual(state.deals.first { $0.id == deal.id }?.status, .expired)
    }

    func testEndDayAdvancesDayAndRefillsAP() {
        var state = newRun()
        state.ap = 0

        var rng = SeededGenerator(seed: 1)
        RainmakerEngine.endDay(state: &state, using: &rng, now: day0)

        XCTAssertEqual(state.day, 2)
        XCTAssertEqual(state.ap, RainmakerBalance.apPerDay)
    }

    func testEndDayGeneratesNextDayOffers() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        RainmakerEngine.endDay(state: &state, using: &rng, now: day0)

        XCTAssertFalse(
            state.deals.filter { $0.status == .offered }.isEmpty,
            "新的一天应有新项目可接，否则闭环断裂"
        )
    }

    // MARK: - 破产

    func testGameOverWhenCashDepleted() {
        var state = newRun()
        state.cash = RainmakerBalance.burnRate  // 无收入时结算后恰好归零
        state.deals = state.deals.map { deal in
            var d = deal
            d.status = .expired
            return d
        }

        var rng = SeededGenerator(seed: 1)
        RainmakerEngine.endDay(state: &state, using: &rng, now: day0)

        XCTAssertLessThanOrEqual(state.cash, 0)
        XCTAssertTrue(state.isGameOver)
    }

    func testGameOverBlocksFurtherActions() {
        var state = newRun()
        state.cash = 1
        state.deals = []
        var rng = SeededGenerator(seed: 1)
        RainmakerEngine.endDay(state: &state, using: &rng, now: day0)
        XCTAssertTrue(state.isGameOver)

        let frozen = state
        RainmakerEngine.endDay(state: &state, using: &rng, now: day0)
        XCTAssertEqual(state, frozen, "破产后 endDay 应为 no-op")

        var withDeal = frozen
        withDeal.deals = [
            DealOffer(
                id: UUID(), npcID: "chen", title: "测试",
                valuation: 100, commission: 10, apCost: 1, status: .offered
            )
        ]
        let dealID = withDeal.deals[0].id
        XCTAssertFalse(NegotiationEngine.start(dealID: dealID, state: &withDeal, using: &rng, now: day0))
    }

    // MARK: - 存档

    func testCodableRoundTrip() throws {
        let state = newRun()
        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(RainmakerState.self, from: data)
        XCTAssertEqual(decoded, state)
    }
}
