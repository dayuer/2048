import Foundation

/// 市场气候：世界观种子。影响项目估值/佣金区间；世界事件可挪动它。
/// 世界引擎离线确定性推进——这是「世界会自己变」的第一根宏观变量。
enum MarketClimate: String, Codable, Sendable, CaseIterable {
    case hot
    case neutral
    case cold

    /// 估值/佣金随气候缩放：热钱多则水涨船高，寒冬则普遍让利。
    var dealMultiplier: Double {
        switch self {
        case .hot: 1.2
        case .neutral: 1.0
        case .cold: 0.8
        }
    }

    var label: String {
        switch self {
        case .hot: "募资火热"
        case .neutral: "行情平稳"
        case .cold: "资本寒冬"
        }
    }

    /// 气候切换时小何播报的市场头条（日后接知识库）。
    var headline: String {
        switch self {
        case .hot: "热钱涌入，估值水涨船高——出手要快。"
        case .neutral: "投资人回归观望，节奏趋于理性。"
        case .cold: "机构收紧钱袋，好项目也得让利。"
        }
    }
}

/// 一条世界事件：确定性、离线、可回放。世界引擎按 tick 滚一批、逐个 apply。
/// 今天的「发单」只是其中一种；泛化后世界能自驱动地发生各种事，
/// 产出的 npcText 自动被 LLM 叙事层（显示层覆盖）增强。
enum WorldEvent: Equatable, Sendable {
    case dealOffer(npcID: String)        // NPC 发来项目单（含寒暄）
    case npcNudge(npcID: String)         // NPC 无由头来撩你一句
    case marketShift(to: MarketClimate)  // 市场气候变动 + 小何头条
    case marketNews(MarketNews)          // 市场新闻：价格×÷/白给货（原版 gameMessages）
    case streetIncident(StreetIncident)  // 街头事件：伤身/敲诈（原版 random_event/steal_event）
}

/// 世界事件调度器：负责「滚事件」（planning，确定性）与「应用事件」（execution）。
/// 与 RainmakerEngine 共用注入 RNG——同种子同结果，可回放。
enum WorldEventScheduler {
    /// 开局：只发项目单，干净起手（气候默认中性）。
    static func rollOpening(dealCount: Int, using rng: inout some RandomNumberGenerator) -> [WorldEvent] {
        NPCCatalog.contacts.shuffled(using: &rng).prefix(dealCount).map { .dealOffer(npcID: $0.id) }
    }

    /// 新的一天：有概率的市场气候变动 → 项目单 → 有概率的 NPC 主动撩。
    /// 气候先于发单应用，故当天新单即反映新行情。
    static func rollDay(state: RainmakerState, using rng: inout some RandomNumberGenerator) -> [WorldEvent] {
        var events: [WorldEvent] = []

        // 市场气候：约 1/3 概率变天，换一个不同的气候
        if rng.next() % 3 == 0 {
            let candidates = MarketClimate.allCases.filter { $0 != state.climate }
            if let next = candidates.shuffled(using: &rng).first {
                events.append(.marketShift(to: next))
            }
        }

        // 项目单：1–2 张（沿用原每日发单数）
        let dealCount = 1 + Int(rng.next() % 2)
        for npc in NPCCatalog.contacts.shuffled(using: &rng).prefix(dealCount) {
            events.append(.dealOffer(npcID: npc.id))
        }

        // NPC 主动撩：约 1/2 概率，尽量挑不发单的那位
        if rng.next() % 2 == 0 {
            let dealNPCs = Set(events.compactMap { event -> String? in
                if case let .dealOffer(id) = event { return id }
                return nil
            })
            let pool = NPCCatalog.contacts.filter { !dealNPCs.contains($0.id) }
            if let npc = (pool.isEmpty ? NPCCatalog.contacts : pool).shuffled(using: &rng).first {
                events.append(.npcNudge(npcID: npc.id))
            }
        }

        // 市场新闻：逐条独立判定（原版 rand(950) % freq == 0），同日可多发
        for news in StreetEventCatalog.newsPool
        where StreetEventCatalog.fires(freq: news.freq, bound: 950, using: &rng) {
            events.append(.marketNews(news))
        }

        // 街头事件：伤身/敲诈各至多一件（原版首中即 break）
        for incident in StreetEventCatalog.healthIncidents
        where StreetEventCatalog.fires(freq: incident.freq, bound: 1000, using: &rng) {
            events.append(.streetIncident(incident))
            break
        }
        for incident in StreetEventCatalog.stealIncidents
        where StreetEventCatalog.fires(freq: incident.freq, bound: 1000, using: &rng) {
            events.append(.streetIncident(incident))
            break
        }

        return events
    }

    /// 应用一条世界事件：改状态 + 往 thread 追加 RainmakerEvent。
    static func apply(
        _ event: WorldEvent, to state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) {
        switch event {
        case let .marketShift(climate):
            state.marketClimate = climate
            RainmakerEngine.append(
                .systemNotice(
                    id: RainmakerEngine.uuid(using: &rng),
                    text: "【市场】\(climate.label)：\(climate.headline)",
                    at: now
                ),
                to: RainmakerEngine.assistantNPCID, in: &state
            )

        case let .dealOffer(npcID):
            guard let npc = NPCCatalog.profile(id: npcID),
                  let template = npc.dealTemplates.randomElement(using: &rng) else { return }
            let mult = state.climate.dealMultiplier
            let deal = DealOffer(
                id: RainmakerEngine.uuid(using: &rng),
                npcID: npc.id,
                title: template.title,
                valuation: scaled(Int.random(in: template.valuationRange, using: &rng), by: mult),
                commission: scaled(Int.random(in: template.commissionRange, using: &rng), by: mult),
                apCost: RainmakerBalance.dealAPCost,
                status: .offered
            )
            state.deals.append(deal)
            RainmakerEngine.append(
                .npcText(id: RainmakerEngine.uuid(using: &rng), text: npc.greetings.randomElement(using: &rng)!, at: now),
                to: npc.id, in: &state
            )
            RainmakerEngine.append(
                .dealOffer(id: RainmakerEngine.uuid(using: &rng), dealID: deal.id, at: now),
                to: npc.id, in: &state
            )

        case let .npcNudge(npcID):
            guard let npc = NPCCatalog.profile(id: npcID),
                  let line = npc.smallTalk.randomElement(using: &rng) else { return }
            RainmakerEngine.append(
                .npcText(id: RainmakerEngine.uuid(using: &rng), text: line, at: now),
                to: npc.id, in: &state
            )

        case let .marketNews(news):
            applyMarketNews(news, to: &state, using: &rng, now: now)

        case let .streetIncident(incident):
            applyStreetIncident(incident, to: &state, using: &rng, now: now)
        }
    }

    /// 市场新闻：涨跌只作用于当日有货的资产（原版 price==0 则跳过）；白给货受容量 clamp。
    private static func applyMarketNews(
        _ news: MarketNews, to state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) {
        switch news.effect {
        case let .surge(times):
            guard let price = state.assetPrices?[news.assetID] else { return }
            state.assetPrices?[news.assetID] = price * times
        case let .crash(divisor):
            guard let price = state.assetPrices?[news.assetID] else { return }
            state.assetPrices?[news.assetID] = max(1, price / divisor)
        case let .gift(count):
            let granted = grantGoods(assetID: news.assetID, count: count, state: &state)
            guard granted > 0 else {
                RainmakerEngine.append(
                    .systemNotice(id: RainmakerEngine.uuid(using: &rng),
                                  text: "可惜!你的托管账户太小，只能放 \(state.currentCapacity) 手。", at: now),
                    to: RainmakerEngine.assistantNPCID, in: &state
                )
                return
            }
        case let .debtGift(count, debtCost):
            // 村长硬卖：记账加债（原版 MyDebt += 2500），货照收（容量不够就少收）
            state.debt = state.currentDebt + debtCost
            _ = grantGoods(assetID: news.assetID, count: count, state: &state)
        }
        RainmakerEngine.append(
            .systemNotice(id: RainmakerEngine.uuid(using: &rng),
                          text: "【新闻】\(news.headline)", at: now),
            to: RainmakerEngine.assistantNPCID, in: &state
        )
    }

    /// 街头事件：伤身扣健康（死亡判定在次日结算），敲诈按比例抽现金。
    private static func applyStreetIncident(
        _ incident: StreetIncident, to state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) {
        let suffix: String
        switch incident.effect {
        case let .healthDamage(points):
            state.health = max(0, state.currentHealth - points)
            suffix = "你的健康减少了 \(points) 点。"
        case let .cashLossPercent(percent):
            let loss = state.cash * percent / 100
            state.cash -= loss
            suffix = "你损失了 \(loss) 万。"
        }
        RainmakerEngine.append(
            .systemNotice(id: RainmakerEngine.uuid(using: &rng),
                          text: incident.text + suffix, at: now),
            to: RainmakerEngine.assistantNPCID, in: &state
        )
    }

    /// 白给货入库（容量 clamp，原版 addcount 语义）。返回实收手数。
    private static func grantGoods(assetID: String, count: Int, state: inout RainmakerState) -> Int {
        let space = state.currentCapacity - state.usedCapacity
        let granted = min(count, max(0, space))
        guard granted > 0 else { return 0 }
        var holdings = state.currentHoldings
        holdings[assetID, default: 0] += granted
        state.holdings = holdings
        return granted
    }

    /// 气候缩放，至少 1（估值/佣金单位是万，恒为正）。
    private static func scaled(_ base: Int, by mult: Double) -> Int {
        max(1, Int((Double(base) * mult).rounded()))
    }
}
