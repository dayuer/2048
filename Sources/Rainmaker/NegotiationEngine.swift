import Foundation

/// 一场进行中的条款谈判。手牌存卡 id（卡面数据在 CardCatalog 静态表）。
struct NegotiationSession: Codable, Equatable, Sendable {
    let dealID: UUID
    let npcID: String
    /// 对方底线估值（防线）。
    let defenseMax: Int
    var defense: Int
    var hand: [String]
    /// 复盘素材：打错对象的无效牌。
    var playedInvalid: [String]
    var playedCount: Int
    /// 对赌协议已打出——爆仓信誉翻倍扣。
    var vamPlayed: Bool
    /// 优先清算权已打出——任何时候可按保底签约。
    var floorUnlocked: Bool
    let repStake: Int
}

/// 谈判内核：开始尽调 / 出牌算分（chips × mult）/ 见好就收 / 交易流产。
/// 无效矩阵是教学核心：卡牌类型 × 对手类型错配 = 0 分 + 嘲讽。
enum NegotiationEngine {
    /// 出牌结果（UI 动效与测试断言用）。
    struct PlayOutcome: Equatable {
        let damage: Int
        let invalid: Bool
        let busted: Bool
        let broke: Bool
    }

    // MARK: - 开始尽调

    /// 入场：扣尽调工时 + 抵押信誉，发手牌。同一时间只允许一场。
    @discardableResult
    static func start(
        dealID: UUID, state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) -> Bool {
        guard !state.isGameOver,
              state.activeNegotiation == nil,
              let index = state.deals.firstIndex(where: { $0.id == dealID }),
              state.deals[index].status == .offered,
              state.ap >= state.deals[index].apCost,
              state.reputation >= RainmakerBalance.negotiationRepStake
        else { return false }

        let deal = state.deals[index]
        state.ap -= deal.apCost
        state.reputation -= RainmakerBalance.negotiationRepStake
        state.deals[index].status = .negotiating

        let defense = min(
            max(deal.valuation / 100, RainmakerBalance.defenseRange.lowerBound),
            RainmakerBalance.defenseRange.upperBound
        )
        var hand = CardCatalog.rookiePool
            .shuffled(using: &rng)
            .prefix(RainmakerBalance.handSize)
            .map(\.id)
        // 沙盘顿悟的库存卡：最多带 inventoryHandBonus 张，开局即消耗（一次性）
        var inventory = state.cardInventory ?? []
        let carried = inventory.prefix(RainmakerBalance.inventoryHandBonus)
        if !carried.isEmpty {
            hand.append(contentsOf: carried)
            inventory.removeFirst(carried.count)
            state.cardInventory = inventory
        }
        state.activeNegotiation = NegotiationSession(
            dealID: deal.id, npcID: deal.npcID,
            defenseMax: defense, defense: defense,
            hand: hand, playedInvalid: [], playedCount: 0,
            vamPlayed: false, floorUnlocked: false,
            repStake: RainmakerBalance.negotiationRepStake
        )

        RainmakerEngine.append(
            .playerText(id: RainmakerEngine.uuid(using: &rng),
                        text: "关于「\(deal.title)」，条款我们当面聊清楚。", at: now),
            to: deal.npcID, in: &state
        )
        RainmakerEngine.append(
            .npcText(id: RainmakerEngine.uuid(using: &rng),
                     text: "可以谈，但我的底线在那儿摆着。", at: now),
            to: deal.npcID, in: &state
        )
        RainmakerEngine.notify(
            "尽调谈判开始：抵押信誉 \(RainmakerBalance.negotiationRepStake)，对方底线估值 \(defense)。",
            in: &state, using: &rng, at: now
        )
        return true
    }

    // MARK: - 出牌

    private static let hurtLines = [
        "……这个数字有点扎心。",
        "你是做过功课的，行。",
        "别逼太紧，大家都要脸。",
        "好刀法。继续，我听着。",
    ]

    @discardableResult
    static func play(
        cardID: String, state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) -> PlayOutcome? {
        guard var session = state.activeNegotiation,
              let handIndex = session.hand.firstIndex(of: cardID),
              let card = CardCatalog.card(id: cardID),
              let npc = NPCCatalog.profile(id: session.npcID)
        else { return nil }

        session.hand.remove(at: handIndex)
        session.playedCount += 1

        RainmakerEngine.append(
            .playerText(id: RainmakerEngine.uuid(using: &rng),
                        text: "（亮出【\(card.name)】）", at: now),
            to: session.npcID, in: &state
        )

        // 无效矩阵：错配 = 0 分 + 嘲讽（交互式教程）
        if let trait = card.invalidAgainst, npc.traits.contains(trait) {
            session.playedInvalid.append(card.id)
            state.activeNegotiation = session
            RainmakerEngine.append(
                .npcText(id: RainmakerEngine.uuid(using: &rng),
                         text: card.tauntWhenInvalid ?? "这套对我没用。", at: now),
                to: session.npcID, in: &state
            )
            RainmakerEngine.notify(
                "【\(card.name)】无效命中：0 分。\(card.knowledge)",
                in: &state, using: &rng, at: now
            )
            return finishPlayStep(session: &session, state: &state, damage: 0, invalid: true, using: &rng, now: now)
        }

        // 有效命中：chips × mult
        let damage = Int(Double(card.chips) * card.mult)
        let before = session.defense
        session.defense = max(0, session.defense - damage)
        switch card.effect {
        case .vamHighRisk: session.vamPlayed = true
        case .payoutFloor: session.floorUnlocked = true
        case nil: break
        }
        state.activeNegotiation = session
        RainmakerEngine.notify(
            "【\(card.name)】命中：\(card.chips) × \(String(format: "%.1f", card.mult)) = \(damage)，底线 \(before) → \(session.defense)。",
            in: &state, using: &rng, at: now
        )
        RainmakerEngine.append(
            .npcText(id: RainmakerEngine.uuid(using: &rng),
                     text: hurtLines.randomElement(using: &rng)!, at: now),
            to: session.npcID, in: &state
        )
        return finishPlayStep(session: &session, state: &state, damage: damage, invalid: false, using: &rng, now: now)
    }

    /// 出牌后的终局判定：击破 → 全额成交；手牌打空未破线 → 交易流产。
    private static func finishPlayStep(
        session: inout NegotiationSession, state: inout RainmakerState,
        damage: Int, invalid: Bool,
        using rng: inout some RandomNumberGenerator, now: Date
    ) -> PlayOutcome {
        if session.defense == 0 {
            settleWin(session: session, fullBreak: true, state: &state, using: &rng, now: now)
            return PlayOutcome(damage: damage, invalid: invalid, busted: false, broke: true)
        }
        if session.hand.isEmpty {
            settleBust(session: session, reason: "手里的筹码打光了，对方底线还没松动。",
                       state: &state, using: &rng, now: now)
            return PlayOutcome(damage: damage, invalid: invalid, busted: true, broke: false)
        }
        return PlayOutcome(damage: damage, invalid: invalid, busted: false, broke: false)
    }

    // MARK: - 见好就收

    /// 签约解锁：防线压到阈值以下，或优先清算权在手（保本条款）。
    static func canSign(state: RainmakerState) -> Bool {
        guard let session = state.activeNegotiation else { return false }
        if session.floorUnlocked { return true }
        return Double(session.defense) / Double(session.defenseMax) <= RainmakerBalance.signUnlockRatio
    }

    /// 按当前让步签约：佣金与压价深度成正比；清算权保底。
    @discardableResult
    static func sign(
        state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) -> Int? {
        guard canSign(state: state),
              let session = state.activeNegotiation,
              let deal = state.deals.first(where: { $0.id == session.dealID })
        else { return nil }
        let amount = payout(for: session, commission: deal.commission, fullBreak: false)
        settleWin(session: session, fullBreak: false, state: &state, using: &rng, now: now)
        return amount
    }

    /// 预计签约佣金（UI 展示用）。
    static func estimatedPayout(state: RainmakerState) -> Int? {
        guard let session = state.activeNegotiation,
              let deal = state.deals.first(where: { $0.id == session.dealID })
        else { return nil }
        return payout(for: session, commission: deal.commission, fullBreak: session.defense == 0)
    }

    // MARK: - 结算

    private static func payout(for session: NegotiationSession, commission: Int, fullBreak: Bool) -> Int {
        if fullBreak { return commission }
        let ratio = 1 - Double(session.defense) / Double(session.defenseMax)
        var amount = Int(Double(commission) * ratio)
        if session.floorUnlocked {
            amount = max(amount, Int(Double(commission) * RainmakerBalance.payoutFloorRatio))
        }
        return amount
    }

    private static func settleWin(
        session: NegotiationSession, fullBreak: Bool, state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) {
        guard let index = state.deals.firstIndex(where: { $0.id == session.dealID }) else { return }
        let commission = state.deals[index].commission
        let amount = payout(for: session, commission: commission, fullBreak: fullBreak)
        let remaining = Int(Double(session.defense) / Double(session.defenseMax) * 100)
        state.deals[index].status = .won
        state.cash += amount
        state.reputation += session.repStake + RainmakerBalance.dealReputationReward
        state.activeNegotiation = nil

        RainmakerEngine.append(
            .npcText(id: RainmakerEngine.uuid(using: &rng),
                     text: fullBreak ? "……行，你赢了，全按你说的办。" : "就按这个条件，签吧。", at: now),
            to: session.npcID, in: &state
        )
        RainmakerEngine.notify(
            fullBreak
                ? "完胜：击破对方底线，拿满佣金上限 +\(amount) 万，信誉 +\(RainmakerBalance.dealReputationReward)（抵押退还）。"
                : "签约成交：佣金 +\(amount) 万（上限 \(commission)，对方底线还剩 \(remaining)%，故未拿满）。信誉 +\(RainmakerBalance.dealReputationReward)（抵押退还）。",
            in: &state, using: &rng, at: now
        )
    }

    /// 交易流产：抵押没收（对赌翻倍），生成谈判复盘报告（培训闭环核心）。
    static func settleBust(
        session: NegotiationSession, reason: String, state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) {
        guard let index = state.deals.firstIndex(where: { $0.id == session.dealID }) else { return }
        state.deals[index].status = .busted
        if session.vamPlayed {
            state.reputation = max(0, state.reputation - session.repStake)
        }
        state.activeNegotiation = nil

        RainmakerEngine.append(
            .npcText(id: RainmakerEngine.uuid(using: &rng),
                     text: "你太贪了。这单不谈了，别再联系我。", at: now),
            to: session.npcID, in: &state
        )
        RainmakerEngine.notify(
            postMortem(session: session, reason: reason),
            in: &state, using: &rng, at: now
        )
    }

    /// 失败复盘报告：点名错牌 + 知识点（不是冷冰冰的“失败”）。
    private static func postMortem(session: NegotiationSession, reason: String) -> String {
        var lines = ["📋 谈判复盘报告", reason]
        let remaining = Int(Double(session.defense) / Double(session.defenseMax) * 100)
        lines.append("共出牌 \(session.playedCount) 轮，对方底线仍剩 \(remaining)%。")
        for id in session.playedInvalid {
            if let card = CardCatalog.card(id: id) {
                lines.append("❌【\(card.name)】打错了对象——\(card.knowledge)")
            }
        }
        if session.vamPlayed {
            lines.append("⚠️ 对赌协议未兑现，信誉反噬翻倍（-\(session.repStake * 2)）。")
        } else {
            lines.append("抵押信誉 \(session.repStake) 点没收。")
        }
        lines.append("建议：先看清对手类型（早期/传统/机构），再选策略包。")
        return lines.joined(separator: "\n")
    }
}
