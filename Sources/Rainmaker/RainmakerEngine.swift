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
                text: "欢迎入行。账上 \(state.cash) 万，每天固定开销 \(RainmakerBalance.burnRate) 万——现金归零就出局。",
                at: now
            ),
            to: assistantNPCID, in: &state
        )
        append(
            .npcText(
                id: uuid(using: &rng),
                text: "老板，联系人都帮你约好了。接单花精力（AP），精力用完记得【结束今日】结算。",
                at: now
            ),
            to: assistantNPCID, in: &state
        )
        generateDayContent(state: &state, dealCount: 2, using: &rng, now: now)
        return state
    }

    // MARK: - 接单

    /// 接单：校验 AP 与状态，成功则扣 AP 并落聊天记录。
    @discardableResult
    static func accept(dealID: UUID, in state: inout RainmakerState, now: Date) -> Bool {
        guard !state.isGameOver,
              let index = state.deals.firstIndex(where: { $0.id == dealID }),
              state.deals[index].status == .offered,
              state.ap >= state.deals[index].apCost
        else { return false }

        state.ap -= state.deals[index].apCost
        state.deals[index].status = .accepted
        let deal = state.deals[index]
        append(.playerText(id: UUID(), text: "「\(deal.title)」这单我接了，今天就去跑。", at: now),
               to: deal.npcID, in: &state)
        append(.npcText(id: UUID(), text: "爽快！办成了 \(deal.commission) 万佣金一分不少。", at: now),
               to: deal.npcID, in: &state)
        return true
    }

    // MARK: - 每日结算

    /// 结束今日：交割已接项目 → 作废未接项目 → 扣固定开销 → 破产判定 → 开新的一天。
    static func endDay(state: inout RainmakerState, using rng: inout some RandomNumberGenerator, now: Date) {
        guard !state.isGameOver else { return }

        var income = 0
        for index in state.deals.indices {
            switch state.deals[index].status {
            case .accepted:
                state.deals[index].status = .paid
                let deal = state.deals[index]
                income += deal.commission
                state.reputation += RainmakerBalance.dealReputationReward
                append(.npcText(id: uuid(using: &rng), text: "款子到位了，跟你合作就是痛快。", at: now),
                       to: deal.npcID, in: &state)
                append(.systemNotice(id: uuid(using: &rng),
                                     text: "「\(deal.title)」交割完成，佣金 +\(deal.commission) 万，信誉 +\(RainmakerBalance.dealReputationReward)。",
                                     at: now),
                       to: deal.npcID, in: &state)
            case .offered:
                state.deals[index].status = .expired
                append(.npcText(id: uuid(using: &rng), text: "你没动静，这单我找别人了。", at: now),
                       to: state.deals[index].npcID, in: &state)
            case .paid, .expired:
                break
            }
        }

        state.cash += income - RainmakerBalance.burnRate
        append(.systemNotice(id: uuid(using: &rng),
                             text: "第 \(state.day) 天结束：佣金 +\(income) 万，开销 -\(RainmakerBalance.burnRate) 万，余额 \(state.cash) 万。",
                             at: now),
               to: assistantNPCID, in: &state)

        if state.cash <= 0 {
            state.isGameOver = true
            append(.npcText(id: uuid(using: &rng),
                            text: "老板……账上没钱了，房东在楼下等你。这行，咱们出局了。",
                            at: now),
                   to: assistantNPCID, in: &state)
            return
        }

        state.day += 1
        state.ap = RainmakerBalance.apPerDay
        let dealCount = 1 + Int(rng.next() % 2)
        generateDayContent(state: &state, dealCount: dealCount, using: &rng, now: now)
    }

    // MARK: - 私有

    /// 为新的一天生成内容：随机挑 NPC 各发一句寒暄 + 一张项目卡。
    private static func generateDayContent(
        state: inout RainmakerState,
        dealCount: Int,
        using rng: inout some RandomNumberGenerator,
        now: Date
    ) {
        let senders = NPCCatalog.contacts.shuffled(using: &rng).prefix(dealCount)
        for npc in senders {
            let template = npc.dealTemplates.randomElement(using: &rng)!
            let deal = DealOffer(
                id: uuid(using: &rng),
                npcID: npc.id,
                title: template.title,
                valuation: Int.random(in: template.valuationRange, using: &rng),
                commission: Int.random(in: template.commissionRange, using: &rng),
                apCost: RainmakerBalance.dealAPCost,
                status: .offered
            )
            state.deals.append(deal)
            append(.npcText(id: uuid(using: &rng),
                            text: npc.greetings.randomElement(using: &rng)!,
                            at: now),
                   to: npc.id, in: &state)
            append(.dealOffer(id: uuid(using: &rng), dealID: deal.id, at: now),
                   to: npc.id, in: &state)
        }
    }

    /// 追加事件；线程不存在则新建。
    private static func append(_ event: RainmakerEvent, to npcID: String, in state: inout RainmakerState) {
        if let index = state.threads.firstIndex(where: { $0.id == npcID }) {
            state.threads[index].events.append(event)
        } else {
            state.threads.append(NPCThread(id: npcID, events: [event]))
        }
    }

    /// 由注入 RNG 生成 UUID——开局/结算路径全确定性，可回放。
    private static func uuid(using rng: inout some RandomNumberGenerator) -> UUID {
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
