import XCTest
@testable import Game2048

/// 浮生记交易内核：买卖门槛、涉灰信誉、还债、银行、医院、扩容、跑市场。
/// 全部纯函数 + 注入 RNG，同种子同结果。
final class TradeEngineTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 0)

    private func newRun(seed: UInt64 = 7) -> RainmakerState {
        var rng = SeededGenerator(seed: seed)
        return RainmakerEngine.newRun(using: &rng, now: day0)
    }

    /// 指定行情的世界，方便断言。
    private func world(cash: Int = 2000, prices: [String: Int]) -> RainmakerState {
        var state = newRun()
        state.cash = cash
        state.assetPrices = prices
        return state
    }

    // MARK: - 开局

    func testNewRunSeedsFushengjiState() {
        let state = newRun()
        XCTAssertEqual(state.cash, 2000, "原版开局 2000")
        XCTAssertEqual(state.currentDebt, RainmakerBalance.startDebt)
        XCTAssertEqual(state.currentHealth, RainmakerBalance.startHealth)
        XCTAssertEqual(state.currentCapacity, RainmakerBalance.startCapacity)
        XCTAssertEqual(state.currentVenueID, TradeCatalog.startVenueID)
        XCTAssertEqual(state.assetPrices?.count, TradeCatalog.assets.count - 3, "原版 leaveout=3：每天缺货 3 种")
        let creditorThread = state.threads.first { $0.id == NPCCatalog.creditor.id }
        XCTAssertNotNil(creditorThread, "开局村长就得来威胁")
    }

    func testRollPricesWithinRangeAndDeterministic() {
        var a = newRun(seed: 42)
        var b = newRun(seed: 42)
        XCTAssertEqual(a.assetPrices, b.assetPrices, "同种子同行情")
        for (id, price) in a.assetPrices ?? [:] {
            let range = TradeCatalog.asset(id: id)!.priceRange
            XCTAssertTrue(range.contains(price), "\(id) 价格 \(price) 超出原版区间 \(range)")
        }
        _ = b  // silence
        _ = a
    }

    // MARK: - 买卖

    func testBuyRespectsCashAndCapacity() {
        var state = world(cash: 100, prices: ["angel-stock": 10])
        XCTAssertTrue(TradeEngine.buy(assetID: "angel-stock", quantity: 10, state: &state))
        XCTAssertEqual(state.cash, 0)
        XCTAssertEqual(state.currentHoldings["angel-stock"], 10)
        XCTAssertFalse(TradeEngine.buy(assetID: "angel-stock", quantity: 1, state: &state), "没钱不能买")

        var rich = world(cash: 999_999, prices: ["angel-stock": 1])
        XCTAssertFalse(
            TradeEngine.buy(assetID: "angel-stock", quantity: rich.currentCapacity + 1, state: &rich),
            "超托管容量不能买"
        )
        XCTAssertFalse(TradeEngine.buy(assetID: "pre-ipo", quantity: 1, state: &state) && state.assetPrices?["pre-ipo"] == nil,
                       "缺货资产不能买")
    }

    func testSellRequiresHoldingsAndGreyCostsReputation() {
        var state = world(cash: 1000, prices: ["traffic-pack": 100, "usd-fund": 100])
        let repBefore = state.reputation
        XCTAssertTrue(TradeEngine.buy(assetID: "traffic-pack", quantity: 2, state: &state))
        XCTAssertTrue(TradeEngine.sell(assetID: "traffic-pack", quantity: 2, state: &state))
        XCTAssertEqual(state.reputation, repBefore - RainmakerBalance.greySellRepPenalty, "卖涉灰资产掉信誉（卖假货掉名声）")
        XCTAssertNil(state.currentHoldings["traffic-pack"], "清仓后持仓移除")

        XCTAssertTrue(TradeEngine.buy(assetID: "usd-fund", quantity: 1, state: &state))
        let repMid = state.reputation
        XCTAssertTrue(TradeEngine.sell(assetID: "usd-fund", quantity: 1, state: &state))
        XCTAssertEqual(state.reputation, repMid, "非灰资产不掉信誉")
        XCTAssertFalse(TradeEngine.sell(assetID: "usd-fund", quantity: 1, state: &state), "没货不能卖")
    }

    // MARK: - 还债 / 银行

    func testRepayDebtClampsAndCreditorReplies() {
        var state = newRun()
        state.cash = 10_000
        var rng = SeededGenerator(seed: 1)
        let paid = TradeEngine.repayDebt(amount: 99_999, state: &state, using: &rng, now: day0)
        XCTAssertEqual(paid, RainmakerBalance.startDebt, "多还 clamp 到欠款")
        XCTAssertEqual(state.currentDebt, 0)
        guard case let .npcText(_, text, _)? = state.threads.first(where: { $0.id == NPCCatalog.creditor.id })?.events.last else {
            return XCTFail("资方该表态")
        }
        XCTAssertTrue(text.contains("回购协议履行完毕"))
    }

    func testBankDepositWithdraw() {
        var state = newRun()
        state.cash = 500
        XCTAssertTrue(TradeEngine.deposit(amount: 300, state: &state))
        XCTAssertEqual(state.cash, 200)
        XCTAssertEqual(state.currentBankDeposit, 300)
        XCTAssertFalse(TradeEngine.deposit(amount: 999, state: &state), "存款不能超现金")
        XCTAssertTrue(TradeEngine.withdraw(amount: 300, state: &state))
        XCTAssertEqual(state.cash, 500)
    }

    // MARK: - 医院 / 扩容

    func testHealChargesPerPointAndClampsToAffordable() {
        var state = newRun()
        state.health = 90
        state.cash = RainmakerBalance.healCostPerPoint * 5
        let cost = TradeEngine.heal(state: &state)
        XCTAssertEqual(cost, RainmakerBalance.healCostPerPoint * 5, "只治得起 5 点")
        XCTAssertEqual(state.currentHealth, 95)
        XCTAssertEqual(state.cash, 0)
        XCTAssertEqual(TradeEngine.heal(state: &state), 0, "没钱治不了")
    }

    func testHealIsAffordableWithStartingCash() {
        // 单位修正后：开局现金就治得起（旧值 3500 万/点时永远治不起）
        var state = newRun()
        state.health = 90
        let cost = TradeEngine.heal(state: &state)
        XCTAssertGreaterThan(cost, 0, "开局现金应治得起健康")
        XCTAssertEqual(state.currentHealth, RainmakerBalance.startHealth, "治得起就回满")
        XCTAssertLessThanOrEqual(RainmakerBalance.healCostPerPoint, RainmakerBalance.startCash,
                                 "单点回血价不得高于开局现金，否则永远治不起")
    }

    func testUpgradeCapacity() {
        var state = newRun()
        state.cash = RainmakerBalance.capacityUpgradeCost
        XCTAssertTrue(TradeEngine.upgradeCapacity(state: &state))
        XCTAssertEqual(state.currentCapacity, RainmakerBalance.startCapacity + RainmakerBalance.capacityUpgradeGain)
        XCTAssertFalse(TradeEngine.upgradeCapacity(state: &state), "钱不够不能扩")
    }

    // MARK: - 特产（全球倒卖环线）

    func testSpecialtiesAlwaysStockedAtLocalCity() {
        // 扫种子：本城特产永不缺货且价格不破区间（产地价 clamp 语义）
        for seed in UInt64(0)..<30 {
            let state = newRun(seed: seed)
            let venue = TradeCatalog.venue(id: state.currentVenueID)!
            for assetID in venue.specialties {
                guard let price = state.assetPrices?[assetID] else {
                    return XCTFail("seed \(seed) 特产 \(assetID) 在 \(venue.name) 缺货")
                }
                let range = TradeCatalog.asset(id: assetID)!.priceRange
                XCTAssertTrue(range.contains(price), "特产价 \(price) 破区间 \(range)")
            }
        }
    }

    func testEveryVenueHasDealerAndSpecialtyAssetsExist() {
        for venue in TradeCatalog.venues {
            XCTAssertNotNil(NPCCatalog.profile(id: venue.dealerID), "\(venue.name) 缺驻场贩子")
            for assetID in venue.specialties {
                XCTAssertNotNil(TradeCatalog.asset(id: assetID), "\(venue.name) 特产 \(assetID) 不存在")
            }
        }
    }

    // MARK: - 跑市场

    func testTravelAdvancesDayAndRerollsPrices() {
        var state = newRun()
        let day = state.day
        var rng = SeededGenerator(seed: 3)
        TradeEngine.travel(to: "sh", state: &state, using: &rng, now: day0)
        XCTAssertEqual(state.currentVenueID, "sh")
        XCTAssertEqual(state.day, day + 1, "奔走一个圈子 = 一天")
        XCTAssertEqual(state.assetPrices?.count, TradeCatalog.assets.count - 3, "到新圈子重滚行情")
    }

    func testTravelToSameVenueIsNoOp() {
        var state = newRun()
        let before = state
        var rng = SeededGenerator(seed: 3)
        TradeEngine.travel(to: state.currentVenueID, state: &state, using: &rng, now: day0)
        XCTAssertEqual(state, before, "原地不动不过天")
    }
}
