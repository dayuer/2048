import Foundation

/// 经营内核：开局 / 接单 / 每日结算。纯函数式改写 RainmakerState，
/// RNG 注入——同种子同结果（沿用 GridGame 基本法的确定性纪律）。
enum RainmakerEngine {
    static let assistantNPCID = NPCCatalog.assistant.id

    // MARK: - 开局

    static func newRun(using rng: inout some RandomNumberGenerator, now: Date) -> RainmakerState {
        var state = RainmakerState(
            day: 1,
            cash: RainmakerBalance.startCash,
            reputation: RainmakerBalance.startReputation,
            ap: RainmakerBalance.apPerDay,
            isGameOver: false,
            deals: [],
            threads: []
        )
        append(
            .systemNotice(
                id: uuid(using: &rng),
                text: "欢迎来京。账上 \(state.cash) 万，身上背着 \(RainmakerBalance.startDebt) 万过桥资金（日息一成）——\(RainmakerBalance.deadlineDay) 天内还清债务并活下来。",
                at: now
            ),
            to: assistantNPCID, in: &state
        )
        append(
            .npcText(
                id: uuid(using: &rng),
                text: "老板，联系人都帮你约好了。接单谈判赚佣金，跑圈子倒卖赚价差——两条路都能还债。跑一个圈子算一天，工时用完记得【结束今日】。",
                at: now
            ),
            to: assistantNPCID, in: &state
        )
        // 浮生记开局：债务/健康/托管/所在圈子 + 首日行情
        state.marketClimate = .neutral
        state.debt = RainmakerBalance.startDebt
        state.venueID = TradeCatalog.startVenueID
        state.health = RainmakerBalance.startHealth
        state.bankDeposit = 0
        state.capacity = RainmakerBalance.startCapacity
        state.holdings = [:]
        append(
            .npcText(
                id: uuid(using: &rng),
                text: "娃，到北京了吧？\(RainmakerBalance.startDebt) 万可是村里人凑的，日息一成，\(RainmakerBalance.deadlineDay) 天内还清。混好了荣归故里，混不好……村里人都看着你呢。",
                at: now
            ),
            to: NPCCatalog.creditor.id, in: &state
        )
        TradeEngine.rollPrices(state: &state, using: &rng)
        appendDealerQuoteFlavor(state: &state, using: &rng, now: now)
        for event in WorldEventScheduler.rollOpening(dealCount: 2, using: &rng) {
            WorldEventScheduler.apply(event, to: &state, using: &rng, now: now)
        }
        return state
    }

    // MARK: - 闲聊收发

    /// 玩家发消息 → NPC 从台词池回一句。空白消息忽略。
    /// 真相层同步落档；「正在输入…」的投递节奏在 Store 表现层。
    static func sendMessage(
        _ text: String, to npcID: String, state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let npc = NPCCatalog.profile(id: npcID) else { return }

        append(.playerText(id: uuid(using: &rng), text: trimmed, at: now), to: npcID, in: &state)
        append(.npcText(id: uuid(using: &rng), text: poolReply(for: npc, using: &rng), at: now), to: npcID, in: &state)
    }

    /// 从台词池抽一句确定性回复。真相层与断网/未配置的回退共用此函数。
    static func poolReply(for npc: NPCProfile, using rng: inout some RandomNumberGenerator) -> String {
        npc.smallTalk.randomElement(using: &rng) ?? "回头细聊。"
    }

    // MARK: - 每日结算

    /// 结束今日：进行中谈判强制流产 → 作废未接项目 → 扣固定开销 → 破产判定 → 开新的一天。
    /// （佣金在谈判签约时即时入账，不走日结。）
    static func endDay(state: inout RainmakerState, using rng: inout some RandomNumberGenerator, now: Date) {
        guard !state.isGameOver else { return }

        // 谈判拖过今晚 = 对方撤单（PRD：AP 耗尽必须结束今日的代价）
        if let session = state.activeNegotiation {
            NegotiationEngine.settleBust(
                session: session,
                reason: "谈判拖过了今晚，对方直接撤了单。",
                state: &state, using: &rng, now: now
            )
        }

        for index in state.deals.indices where state.deals[index].status == .offered {
            state.deals[index].status = .expired
            append(.npcText(id: uuid(using: &rng), text: "你没动静，这单我找别人了。", at: now),
                   to: state.deals[index].npcID, in: &state)
        }

        state.cash -= RainmakerBalance.burnRate
        append(.systemNotice(id: uuid(using: &rng),
                             text: "第 \(state.day) 天结束：固定开销 -\(RainmakerBalance.burnRate) 万，余额 \(state.cash) 万。",
                             at: now),
               to: assistantNPCID, in: &state)

        if state.cash <= 0 {
            state.isGameOver = true
            state.outcome = .bankrupt
            append(.npcText(id: uuid(using: &rng),
                            text: "老板……账上没钱了，职场信用已破产。本期实战到此为止，复盘后重来吧。",
                            at: now),
                   to: assistantNPCID, in: &state)
            return
        }

        // 浮生记结算：滚债息/生存息/村长催债/健康判定 → 40 天大限
        if TradeEngine.dailyDebtAndHealthTick(state: &state, using: &rng, now: now) { return }
        if TradeEngine.settleDeadlineIfDue(state: &state, using: &rng, now: now) { return }

        state.day += 1
        state.ap = RainmakerBalance.apPerDay
        // 新的一天：当地行情先滚，世界事件（含资产新闻）随后修正价格
        TradeEngine.rollPrices(state: &state, using: &rng)
        appendDealerQuoteFlavor(state: &state, using: &rng, now: now)
        for event in WorldEventScheduler.rollDay(state: state, using: &rng) {
            WorldEventScheduler.apply(event, to: &state, using: &rng, now: now)
        }
    }

    // MARK: - 私有

    /// 当日驻场贩子来一句行情吆喝（正文由台词池出，联网时被人设生成覆盖）。
    private static func appendDealerQuoteFlavor(
        state: inout RainmakerState, using rng: inout some RandomNumberGenerator, now: Date
    ) {
        guard let venue = TradeCatalog.venue(id: state.currentVenueID),
              let dealer = NPCCatalog.profile(id: venue.dealerID),
              let line = dealer.smallTalk.randomElement(using: &rng) else { return }
        append(.npcText(id: uuid(using: &rng), text: line, at: now), to: dealer.id, in: &state)
    }

    /// 追加事件；线程不存在则新建。（NegotiationEngine / WorldEventScheduler 共用）
    static func append(_ event: RainmakerEvent, to npcID: String, in state: inout RainmakerState) {
        if let index = state.threads.firstIndex(where: { $0.id == npcID }) {
            state.threads[index].events.append(event)
        } else {
            state.threads.append(NPCThread(id: npcID, events: [event]))
        }
    }

    /// 由注入 RNG 生成 UUID——开局/结算/谈判路径全确定性，可回放。（NegotiationEngine 共用）
    static func uuid(using rng: inout some RandomNumberGenerator) -> UUID {
        let a = rng.next()
        let b = rng.next()
        func byte(_ value: UInt64, _ index: Int) -> UInt8 {
            UInt8((value >> (index * 8)) & 0xFF)
        }
        return UUID(uuid: (
            byte(a, 0), byte(a, 1), byte(a, 2), byte(a, 3),
            byte(a, 4), byte(a, 5), byte(a, 6), byte(a, 7),
            byte(b, 0), byte(b, 1), byte(b, 2), byte(b, 3),
            byte(b, 4), byte(b, 5), byte(b, 6), byte(b, 7)
        ))
    }
}
