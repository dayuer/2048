import XCTest
@testable import Game2048

/// 世界事件系统：确定性、离线、可回放。发单泛化成事件；市场气候是第一根世界变量。
final class WorldEventTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 0)

    /// 一个干净的空世界（清掉开局内容），可指定气候。
    private func blankWorld(climate: MarketClimate = .neutral) -> RainmakerState {
        var throwaway = SeededGenerator(seed: 0)
        var state = RainmakerEngine.newRun(using: &throwaway, now: day0)
        state.deals = []
        state.threads = []
        state.marketClimate = climate
        return state
    }

    // MARK: - 调度确定性

    func testRollOpeningIsDeterministicAndSized() {
        var a = SeededGenerator(seed: 3)
        var b = SeededGenerator(seed: 3)
        let ea = WorldEventScheduler.rollOpening(dealCount: 2, using: &a)
        let eb = WorldEventScheduler.rollOpening(dealCount: 2, using: &b)
        XCTAssertEqual(ea, eb, "同种子同事件")
        XCTAssertEqual(ea.count, 2)
        for event in ea {
            guard case .dealOffer = event else { return XCTFail("开局只发项目单") }
        }
    }

    func testRollDayIsDeterministic() {
        let state = blankWorld()
        var a = SeededGenerator(seed: 11)
        var b = SeededGenerator(seed: 11)
        XCTAssertEqual(
            WorldEventScheduler.rollDay(state: state, using: &a),
            WorldEventScheduler.rollDay(state: state, using: &b)
        )
    }

    func testRollDayAlwaysProducesAtLeastOneDeal() {
        // 扫一批种子：每天都得有可接的单，否则闭环断裂。
        for seed in UInt64(0)..<50 {
            var rng = SeededGenerator(seed: seed)
            let events = WorldEventScheduler.rollDay(state: blankWorld(), using: &rng)
            let deals = events.filter { if case .dealOffer = $0 { return true } else { return false } }
            XCTAssertFalse(deals.isEmpty, "seed \(seed) 当天无项目单")
        }
    }

    // MARK: - 市场气候影响估值

    func testClimateScalesDealValuation() {
        func valuation(under climate: MarketClimate) -> Int {
            var state = blankWorld(climate: climate)
            var rng = SeededGenerator(seed: 5)
            WorldEventScheduler.apply(.dealOffer(npcID: "chen"), to: &state, using: &rng, now: day0)
            return state.deals.last!.valuation
        }
        // 同种子 → 同基数，气候只做缩放：火热 > 平稳 > 寒冬。
        XCTAssertGreaterThan(valuation(under: .hot), valuation(under: .neutral))
        XCTAssertGreaterThan(valuation(under: .neutral), valuation(under: .cold))
    }

    // MARK: - 事件应用

    func testMarketShiftUpdatesClimateAndPostsHeadline() {
        var state = blankWorld(climate: .neutral)
        var rng = SeededGenerator(seed: 1)
        WorldEventScheduler.apply(.marketShift(to: .cold), to: &state, using: &rng, now: day0)

        XCTAssertEqual(state.climate, .cold, "气候被挪动")
        guard let notice = state.noticeLog.last else {
            return XCTFail("应在通知日志播一条市场头条")
        }
        XCTAssertTrue(notice.text.contains(MarketClimate.cold.label))
    }

    func testDealOfferAppendsGreetingAndCard() {
        var state = blankWorld()
        var rng = SeededGenerator(seed: 2)
        WorldEventScheduler.apply(.dealOffer(npcID: "ma"), to: &state, using: &rng, now: day0)

        XCTAssertEqual(state.deals.count, 1)
        let deal = state.deals[0]
        XCTAssertEqual(deal.npcID, "ma")
        let events = state.threads.first { $0.id == "ma" }?.events ?? []
        XCTAssertTrue(events.contains { if case .npcText = $0 { return true } else { return false } }, "有寒暄")
        XCTAssertTrue(events.contains {
            if case let .dealOffer(_, dealID, _) = $0 { return dealID == deal.id } else { return false }
        }, "有项目卡且挂在该 NPC 线程")
    }

    func testNpcNudgeAppendsUnpromptedText() {
        var state = blankWorld()
        var rng = SeededGenerator(seed: 4)
        WorldEventScheduler.apply(.npcNudge(npcID: "zhou"), to: &state, using: &rng, now: day0)

        let events = state.threads.first { $0.id == "zhou" }?.events ?? []
        XCTAssertEqual(events.count, 1)
        guard case let .npcText(_, text, _) = events.last else { return XCTFail("应追加一条 NPC 文字") }
        XCTAssertTrue(NPCCatalog.profile(id: "zhou")!.smallTalk.contains(text), "撩的话取自台词池，可被 LLM 增强")
        XCTAssertTrue(state.deals.isEmpty, "主动撩不带项目单")
    }

    // MARK: - 新档默认气候

    func testNewRunStartsNeutralClimate() {
        var rng = SeededGenerator(seed: 7)
        let state = RainmakerEngine.newRun(using: &rng, now: day0)
        XCTAssertEqual(state.climate, .neutral)
    }
}
