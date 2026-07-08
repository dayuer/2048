import Foundation

/// 浮生记交易内核：买卖/还债/银行/医院/扩容/跑市场。
/// 纯函数式改写 RainmakerState，注入 RNG——同种子同结果，离线可回放。
enum TradeEngine {
    // MARK: - 行情

    /// 为当前城市滚今日行情：单价均匀落在区间内，随机缺货 3 种
    /// （原版 makeDrugPrices(leaveout=3) 语义）。新闻事件在此之后乘价。
    /// 特产规则（全球倒卖环线）：本城特产永不缺货，且报产地价（八折、不破区间下沿）——
    /// 在产地进货、飞去别处出手，就是金融大鳄的环线。
    static func rollPrices(state: inout RainmakerState, using rng: inout some RandomNumberGenerator) {
        let specialties = Set(TradeCatalog.venue(id: state.currentVenueID)?.specialties ?? [])
        var prices: [String: Int] = [:]
        for asset in TradeCatalog.assets {
            var price = Int.random(in: asset.priceRange, using: &rng)
            if specialties.contains(asset.id) {
                price = max(asset.priceRange.lowerBound, Int(Double(price) * 0.8))
            }
            prices[asset.id] = price
        }
        // 缺货只从非特产里抽（特产是本城招牌，永远有量）
        let leaveoutPool = TradeCatalog.assets.filter { !specialties.contains($0.id) }
        for asset in leaveoutPool.shuffled(using: &rng).prefix(3) {
            prices.removeValue(forKey: asset.id)  // 今日无货
        }
        state.assetPrices = prices
    }

    // MARK: - 买卖

    /// 买入：现金和托管容量双门槛。成功返回 true。
    @discardableResult
    static func buy(assetID: String, quantity: Int, state: inout RainmakerState) -> Bool {
        guard !state.isGameOver, quantity > 0,
              let price = state.assetPrices?[assetID] else { return false }
        let cost = price * quantity
        guard state.cash >= cost,
              state.usedCapacity + quantity <= state.currentCapacity else { return false }
        state.cash -= cost
        var holdings = state.currentHoldings
        holdings[assetID, default: 0] += quantity
        state.holdings = holdings
        return true
    }

    /// 卖出：按当日当地价。涉灰资产每笔扣信誉（卖假货掉名声）。
    @discardableResult
    static func sell(assetID: String, quantity: Int, state: inout RainmakerState) -> Bool {
        guard !state.isGameOver, quantity > 0,
              let price = state.assetPrices?[assetID],
              let owned = state.holdings?[assetID], owned >= quantity else { return false }
        state.cash += price * quantity
        var holdings = state.currentHoldings
        if owned == quantity {
            holdings.removeValue(forKey: assetID)
        } else {
            holdings[assetID] = owned - quantity
        }
        state.holdings = holdings
        if TradeCatalog.asset(id: assetID)?.isGrey == true {
            state.reputation = max(0, state.reputation - RainmakerBalance.greySellRepPenalty)
        }
        return true
    }

    // MARK: - 还债 / 银行

    /// 给资方还钱：多还不找零（clamp 到欠款与现金）。清账时沈墨在聊天里表态。
    @discardableResult
    static func repayDebt(
        amount: Int, state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) -> Int {
        guard !state.isGameOver, amount > 0, state.currentDebt > 0 else { return 0 }
        let paid = min(amount, state.currentDebt, state.cash)
        guard paid > 0 else { return 0 }
        state.cash -= paid
        state.debt = state.currentDebt - paid
        let reply = state.currentDebt == 0
            ? "尾款到账，回购协议履行完毕。和聪明人做生意就是省心——今晚会所，香槟我开好了。圈子很小，后会有期。"
            : "到账 \(paid) 万，余额 \(state.currentDebt) 万。罚息不会等你，我也不会。"
        RainmakerEngine.append(
            .npcText(id: RainmakerEngine.uuid(using: &rng), text: reply, at: now),
            to: NPCCatalog.creditor.id, in: &state
        )
        return paid
    }

    @discardableResult
    static func deposit(amount: Int, state: inout RainmakerState) -> Bool {
        guard !state.isGameOver, amount > 0, state.cash >= amount else { return false }
        state.cash -= amount
        state.bankDeposit = state.currentBankDeposit + amount
        return true
    }

    @discardableResult
    static func withdraw(amount: Int, state: inout RainmakerState) -> Bool {
        guard !state.isGameOver, amount > 0, state.currentBankDeposit >= amount else { return false }
        state.bankDeposit = state.currentBankDeposit - amount
        state.cash += amount
        return true
    }

    // MARK: - 医院 / 扩容

    /// 私立医院：花钱回血到满，返回花费（0 = 没治/没钱治不起一点）。
    @discardableResult
    static func heal(state: inout RainmakerState) -> Int {
        guard !state.isGameOver else { return 0 }
        let missing = RainmakerBalance.startHealth - state.currentHealth
        guard missing > 0 else { return 0 }
        let affordable = min(missing, state.cash / RainmakerBalance.healCostPerPoint)
        guard affordable > 0 else { return 0 }
        let cost = affordable * RainmakerBalance.healCostPerPoint
        state.cash -= cost
        state.health = state.currentHealth + affordable
        return cost
    }

    /// 托管账户扩容：+100 手。
    @discardableResult
    static func upgradeCapacity(state: inout RainmakerState) -> Bool {
        guard !state.isGameOver, state.cash >= RainmakerBalance.capacityUpgradeCost else { return false }
        state.cash -= RainmakerBalance.capacityUpgradeCost
        state.capacity = state.currentCapacity + RainmakerBalance.capacityUpgradeGain
        return true
    }

    // MARK: - 跑市场（移动 = 结束今日）

    /// 奔走一个圈子算一天：先换地，再走每日结算（滚息/行情/事件全在 endDay）。
    static func travel(
        to venueID: String, state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) {
        guard !state.isGameOver, TradeCatalog.venue(id: venueID) != nil,
              venueID != state.currentVenueID else { return }
        state.venueID = venueID
        RainmakerEngine.endDay(state: &state, using: &rng, now: now)
    }

    // MARK: - 每日浮生记结算（由 RainmakerEngine.endDay 调用）

    /// 滚债息、生存息、资方催收、逾期保全、健康判定。返回是否已终局。
    static func dailyDebtAndHealthTick(
        state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) -> Bool {
        // 债务滚息（向上取整，资方不吃亏）
        if state.currentDebt > 0 {
            state.debt = Int((Double(state.currentDebt) * (1 + RainmakerBalance.debtDailyRate)).rounded(.up))
        }
        // 存款生息（向下取整，银行不吃亏）
        if state.currentBankDeposit > 0 {
            state.bankDeposit = Int(Double(state.currentBankDeposit) * (1 + RainmakerBalance.bankDailyRate))
        }
        // 资方催收 / 逾期保全
        if state.currentDebt > 0 {
            let overdue = state.day >= RainmakerBalance.deadlineDay * 3 / 4
                && state.currentDebt > RainmakerBalance.startDebt
            if overdue {
                state.health = max(0, state.currentHealth - RainmakerBalance.overdueBeatingDamage)
                RainmakerEngine.append(
                    .npcText(id: RainmakerEngine.uuid(using: &rng),
                             text: "宽限期到了。今早资产保全函已送达你所有合作方，你在会议室被轮番质询到凌晨——健康 -\(RainmakerBalance.overdueBeatingDamage)。欠款 \(state.currentDebt) 万，条款写得很清楚。",
                             at: now),
                    to: NPCCatalog.creditor.id, in: &state
                )
            } else {
                RainmakerEngine.append(
                    .npcText(id: RainmakerEngine.uuid(using: &rng),
                             text: NPCCatalog.creditor.smallTalk.randomElement(using: &rng)! + "（欠债 \(state.currentDebt) 万）",
                             at: now),
                    to: NPCCatalog.creditor.id, in: &state
                )
            }
        }
        // 健康归零：牺牲在北京街头
        if state.currentHealth <= 0 {
            state.isGameOver = true
            state.outcome = .beaten
            RainmakerEngine.notify(
                "你倒在了北京街头。健康归零，本期浮生到此为止。",
                in: &state, using: &rng, at: now
            )
            return true
        }
        return false
    }

    /// 40 天大限结算：债清 = 上岸登榜，没清 = 被执行人 + 限高。返回是否终局。
    static func settleDeadlineIfDue(
        state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) -> Bool {
        guard state.day >= RainmakerBalance.deadlineDay else { return false }
        state.isGameOver = true
        if state.currentDebt <= 0 {
            state.outcome = .victory
            RainmakerEngine.notify(
                "四十天期满，债务两清——你在北京活下来了。净资产 \(state.netWorth) 万，荣登浮生排行榜。",
                in: &state, using: &rng, at: now
            )
        } else {
            state.outcome = .debtUnpaid
            RainmakerEngine.append(
                .npcText(id: RainmakerEngine.uuid(using: &rng),
                         text: "四十天，还差 \(state.currentDebt) 万。强制执行申请已经递上去了，限高令下午生效——以后，高铁二等座都是奢望。别怪我，条款写得很清楚。",
                         at: now),
                to: NPCCatalog.creditor.id, in: &state
            )
        }
        return true
    }
}
