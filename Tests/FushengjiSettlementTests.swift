import XCTest
@testable import Game2048

/// 浮生记结算：滚息、40 天大限四结局、逾期挨打、健康归零、市场新闻与街头事件。
final class FushengjiSettlementTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 0)

    private func newRun(seed: UInt64 = 7) -> RainmakerState {
        var rng = SeededGenerator(seed: seed)
        return RainmakerEngine.newRun(using: &rng, now: day0)
    }

    private func endDay(_ state: inout RainmakerState, seed: UInt64 = 1) {
        var rng = SeededGenerator(seed: seed)
        RainmakerEngine.endDay(state: &state, using: &rng, now: day0)
    }

    // MARK: - 滚息

    func testDebtAccruesTenPercentDaily() {
        var state = newRun()
        state.cash = 100_000  // 别破产
        endDay(&state)
        // 原版：MyDebt += MyDebt * 0.10（我们向上取整）
        XCTAssertEqual(state.currentDebt, Int((Double(RainmakerBalance.startDebt) * 1.1).rounded(.up)))
    }

    func testBankAccruesOnePercentDaily() {
        var state = newRun()
        state.cash = 100_000
        state.bankDeposit = 1000
        endDay(&state)
        XCTAssertEqual(state.currentBankDeposit, 1010, "银行日息 1%（原版 MyBank * 0.01）")
    }

    func testCreditorSendsDailyThreatWhileInDebt() {
        var state = newRun()
        state.cash = 100_000
        let before = state.threads.first { $0.id == NPCCatalog.creditor.id }?.events.count ?? 0
        endDay(&state)
        let after = state.threads.first { $0.id == NPCCatalog.creditor.id }?.events.count ?? 0
        XCTAssertGreaterThan(after, before, "欠债期间村长每天催")
    }

    // MARK: - 逾期挨打（day >= 30 且债务高于本金）

    func testOverdueBeatingHurtsHealth() {
        var state = newRun()
        state.cash = 1_000_000
        state.day = RainmakerBalance.deadlineDay * 3 / 4
        state.debt = RainmakerBalance.startDebt * 2
        let healthBefore = state.currentHealth
        endDay(&state)
        XCTAssertEqual(
            state.currentHealth, healthBefore - RainmakerBalance.overdueBeatingDamage,
            "欠钱太多，村长叫老乡揍俺（原版语义）"
        )
    }

    // MARK: - 终局

    func testHealthZeroEndsBeaten() {
        var state = newRun()
        state.cash = 100_000
        state.health = 0
        endDay(&state)
        XCTAssertTrue(state.isGameOver)
        XCTAssertEqual(state.outcome, .beaten)
    }

    func testDeadlineVictoryWhenDebtCleared() {
        var state = newRun()
        state.cash = 100_000
        state.debt = 0
        state.day = RainmakerBalance.deadlineDay
        endDay(&state)
        XCTAssertTrue(state.isGameOver)
        XCTAssertEqual(state.outcome, .victory, "四十天债清 = 上岸登榜")
    }

    func testDeadlineUnpaidDebtEndsRun() {
        var state = newRun()
        state.cash = 100_000
        state.day = RainmakerBalance.deadlineDay
        endDay(&state)
        XCTAssertTrue(state.isGameOver)
        XCTAssertEqual(state.outcome, .debtUnpaid, "债没清，老乡们来了")
    }

    func testBankruptcyOutcomeTagged() {
        var state = newRun()
        state.cash = RainmakerBalance.burnRate
        state.deals = []
        endDay(&state)
        XCTAssertTrue(state.isGameOver)
        XCTAssertEqual(state.outcome, .bankrupt)
    }

    // MARK: - 市场新闻（原版 gameMessages 语义）

    func testMarketNewsSurgeMultipliesPrice() {
        var state = newRun()
        state.assetPrices = ["pre-ipo": 5000]
        var rng = SeededGenerator(seed: 1)
        let news = MarketNews(freq: 1, assetID: "pre-ipo", headline: "测试头条", effect: .surge(8))
        WorldEventScheduler.apply(.marketNews(news), to: &state, using: &rng, now: day0)
        XCTAssertEqual(state.assetPrices?["pre-ipo"], 40000, "价格 ×8")
        let assistant = state.threads.first { $0.id == RainmakerEngine.assistantNPCID }
        guard case let .systemNotice(_, text, _)? = assistant?.events.last else {
            return XCTFail("新闻要推送")
        }
        XCTAssertTrue(text.contains("【新闻】"))
    }

    func testMarketNewsCrashSkipsAbsentAsset() {
        var state = newRun()
        state.assetPrices = [:]  // 今日无货
        var rng = SeededGenerator(seed: 1)
        let before = state.threads.first { $0.id == RainmakerEngine.assistantNPCID }?.events.count ?? 0
        let news = MarketNews(freq: 1, assetID: "pre-ipo", headline: "测试", effect: .crash(8))
        WorldEventScheduler.apply(.marketNews(news), to: &state, using: &rng, now: day0)
        let after = state.threads.first { $0.id == RainmakerEngine.assistantNPCID }?.events.count ?? 0
        XCTAssertEqual(after, before, "缺货资产的新闻不生效不推送（原版 price==0 跳过）")
    }

    func testMarketNewsGiftClampsToCapacity() {
        var state = newRun()
        state.holdings = ["unicorn-stake": state.currentCapacity - 1]
        var rng = SeededGenerator(seed: 1)
        let news = MarketNews(freq: 1, assetID: "tail-round", headline: "白给", effect: .gift(6))
        WorldEventScheduler.apply(.marketNews(news), to: &state, using: &rng, now: day0)
        XCTAssertEqual(state.currentHoldings["tail-round"], 1, "容量只剩 1，白给 6 只收 1（原版 addcount clamp）")
    }

    func testDebtGiftAddsDebtAndGoods() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        let news = MarketNews(freq: 1, assetID: "usd-fund", headline: "村长硬卖",
                              effect: .debtGift(1, debtCost: 2500))
        WorldEventScheduler.apply(.marketNews(news), to: &state, using: &rng, now: day0)
        XCTAssertEqual(state.currentDebt, RainmakerBalance.startDebt + 2500, "原版 MyDebt += 2500")
        XCTAssertEqual(state.currentHoldings["usd-fund"], 1)
    }

    // MARK: - 街头事件

    func testStreetIncidentHealthDamage() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        let incident = StreetIncident(freq: 1, text: "测试挨打", effect: .healthDamage(20), sound: "death")
        WorldEventScheduler.apply(.streetIncident(incident), to: &state, using: &rng, now: day0)
        XCTAssertEqual(state.currentHealth, RainmakerBalance.startHealth - 20)
    }

    func testStreetIncidentCashLoss() {
        var state = newRun()
        state.cash = 1000
        var rng = SeededGenerator(seed: 1)
        let incident = StreetIncident(freq: 1, text: "测试敲诈", effect: .cashLossPercent(40), sound: nil)
        WorldEventScheduler.apply(.streetIncident(incident), to: &state, using: &rng, now: day0)
        XCTAssertEqual(state.cash, 600, "原版 money *= (1 - 40%)")
    }

    // MARK: - 存档兼容

    func testFushengjiFieldsSurviveCodableRoundTrip() throws {
        var state = newRun()
        state.holdings = ["angel-stock": 3]
        state.bankDeposit = 500
        let decoded = try JSONDecoder().decode(RainmakerState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
    }
}
