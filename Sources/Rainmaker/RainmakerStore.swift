import Foundation
import Observation

/// 存档仓库 + UI 单一真相源：每次改动整档 JSON 落盘（局面小，整存整取足够）。
/// 引擎逻辑全在 RainmakerEngine/NegotiationEngine；这里叠一层「投递表现层」——
/// 引擎同步写真相，收到的消息逐条延迟送达（WhatsApp 式「正在输入…」节奏）。
@MainActor
@Observable
final class RainmakerStore {
    private(set) var state: RainmakerState
    private let fileURL: URL
    private var rng = SystemRandomNumberGenerator()

    // MARK: 投递表现层（不持久化）

    /// 每根线程已「送达」的事件数；真相层多出的部分由投递任务逐条揭示。
    private(set) var revealedCounts: [String: Int] = [:]
    /// 正在输入…的 NPC（可多线程同时投递）。
    private(set) var typingNPCIDs: Set<String> = []
    /// 测试开关：跳过延迟即时投递。
    var instantDelivery = false
    private var deliveryTasks: [String: Task<Void, Never>] = [:]

    // MARK: 应用内通知横幅（表现层，不持久化）

    /// 当前应弹出的横幅（只弹最新一条，其余靠通知中心角标兜底）。
    private(set) var activeBanner: SystemNotice?
    /// 已经弹过横幅的通知数（启动不重播历史）。
    private var bannerBaseline = 0

    // MARK: 生成式对话（显示层覆盖，不持久化）

    /// 生成式对话接入。nil = 不接入 → 走确定性台词池（默认）。
    var personaChat: PersonaChatClient?
    /// 事件 id → LLM 生成文本。真相层永不变，UI 经 displayText 覆盖显示。
    private(set) var generatedText: [UUID: String] = [:]
    /// 该线程可增强的最近 N 轮历史（喂给生成式做记忆连续）。
    private let historyWindow = 8

    /// 谈判台词的场景标签（显示层，不持久化）：出牌结果在包装层零成本打标，
    /// 生成式据此选对提示词板块。重启后标签消失无妨——旧局台词启动即标已送达，不会重新生成。
    struct NegotiationSceneTag {
        let intent: PersonaChatRequest.Intent
        let context: PersonaChatRequest.NegotiationContext
    }
    private(set) var negotiationSceneTags: [UUID: NegotiationSceneTag] = [:]

    init(fileURL: URL = RainmakerStore.defaultFileURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(RainmakerState.self, from: data) {
            self.state = loaded
        } else {
            var rng = SystemRandomNumberGenerator()
            self.state = RainmakerEngine.newRun(using: &rng, now: .now)
        }
        // 旧存档：债主换角 + 聊天线程里的系统旁白搬进通知日志
        state.migrateCreditorIDIfNeeded()
        state.migrateThreadNoticesIfNeeded()
        // 启动不重播历史：全部标记已送达 / 已弹横幅
        for thread in state.threads {
            revealedCounts[thread.id] = thread.events.count
        }
        bannerBaseline = state.noticeLog.count
        persist()
    }

    nonisolated static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("rainmaker-run.json")
    }

    // MARK: - 动作

    @discardableResult
    func startNegotiation(dealID: UUID) -> Bool {
        let deal = state.deals.first { $0.id == dealID }
        let baseline = eventCount(npcID: deal?.npcID)
        let started = NegotiationEngine.start(dealID: dealID, state: &state, using: &rng, now: .now)
        if started {
            if let deal {
                tagNegotiationLines(
                    npcID: deal.npcID, after: baseline, intents: [.negotiationOpen],
                    context: .init(dealTitle: deal.title, cardName: nil, cardKnowledge: nil,
                                   damage: nil, defenseRemainingPercent: 100)
                )
            }
            commit()
        }
        return started
    }

    @discardableResult
    func play(cardID: String) -> NegotiationEngine.PlayOutcome? {
        let session = state.activeNegotiation
        let card = CardCatalog.card(id: cardID)
        let dealTitle = state.deals.first { $0.id == session?.dealID }?.title
        let baseline = eventCount(npcID: session?.npcID)
        let outcome = NegotiationEngine.play(cardID: cardID, state: &state, using: &rng, now: .now)
        if let outcome {
            if let session, let card {
                // 场景序列与引擎追加顺序一一对应：受痛/嘲讽在前，终局台词（击穿/谈崩）随后。
                var intents: [PersonaChatRequest.Intent] = [outcome.invalid ? .negotiationTaunt : .negotiationHurt]
                if outcome.broke { intents.append(.negotiationBreak) }
                if outcome.busted { intents.append(.negotiationBust) }
                let remaining = max(0, session.defense - outcome.damage)
                tagNegotiationLines(
                    npcID: session.npcID, after: baseline, intents: intents,
                    context: .init(
                        dealTitle: dealTitle ?? "这单生意",
                        cardName: card.name,
                        cardKnowledge: outcome.invalid ? card.knowledge : nil,
                        damage: outcome.invalid ? nil : outcome.damage,
                        defenseRemainingPercent: Int(Double(remaining) / Double(session.defenseMax) * 100)
                    )
                )
            }
            commit()
        }
        return outcome
    }

    @discardableResult
    func sign() -> Int? {
        let session = state.activeNegotiation
        let dealTitle = state.deals.first { $0.id == session?.dealID }?.title
        let baseline = eventCount(npcID: session?.npcID)
        let payout = NegotiationEngine.sign(state: &state, using: &rng, now: .now)
        if payout != nil {
            if let session {
                tagNegotiationLines(
                    npcID: session.npcID, after: baseline, intents: [.negotiationSign],
                    context: .init(
                        dealTitle: dealTitle ?? "这单生意",
                        cardName: nil, cardKnowledge: nil, damage: nil,
                        defenseRemainingPercent: Int(Double(session.defense) / Double(session.defenseMax) * 100)
                    )
                )
            }
            commit()
        }
        return payout
    }

    private func eventCount(npcID: String?) -> Int {
        guard let npcID else { return 0 }
        return state.threads.first { $0.id == npcID }?.events.count ?? 0
    }

    /// 引擎调用后给新增的 npcText 逐条打场景标签（按追加顺序与 intents 对齐）。
    private func tagNegotiationLines(
        npcID: String, after baseline: Int,
        intents: [PersonaChatRequest.Intent],
        context: PersonaChatRequest.NegotiationContext
    ) {
        guard let events = state.threads.first(where: { $0.id == npcID })?.events,
              baseline < events.count else { return }
        let newNPCTextIDs: [UUID] = events[baseline...].compactMap {
            if case let .npcText(id, _, _) = $0 { id } else { nil }
        }
        for (id, intent) in zip(newNPCTextIDs, intents) {
            negotiationSceneTags[id] = NegotiationSceneTag(intent: intent, context: context)
        }
    }

    func sendMessage(_ text: String, to npcID: String) {
        RainmakerEngine.sendMessage(text, to: npcID, state: &state, using: &rng, now: .now)
        commit()
    }

    func endDay() {
        RainmakerEngine.endDay(state: &state, using: &rng, now: .now)
        playOutcomeSoundIfNeeded()
        commit()
    }

    // MARK: - 浮生记交易动作（音效为表现层，引擎保持纯净）

    @discardableResult
    func buy(assetID: String, quantity: Int) -> Bool {
        let ok = TradeEngine.buy(assetID: assetID, quantity: quantity, state: &state)
        if ok {
            SoundPlayer.play("buy")
            commit()
        }
        return ok
    }

    @discardableResult
    func sell(assetID: String, quantity: Int) -> Bool {
        let ok = TradeEngine.sell(assetID: assetID, quantity: quantity, state: &state)
        if ok {
            SoundPlayer.play("money")
            commit()
        }
        return ok
    }

    @discardableResult
    func repayDebt(amount: Int) -> Int {
        let paid = TradeEngine.repayDebt(amount: amount, state: &state, using: &rng, now: .now)
        if paid > 0 {
            SoundPlayer.play("money")
            commit()
        }
        return paid
    }

    @discardableResult
    func deposit(amount: Int) -> Bool {
        let ok = TradeEngine.deposit(amount: amount, state: &state)
        if ok { commit() }
        return ok
    }

    @discardableResult
    func withdraw(amount: Int) -> Bool {
        let ok = TradeEngine.withdraw(amount: amount, state: &state)
        if ok { commit() }
        return ok
    }

    @discardableResult
    func heal() -> Int {
        let cost = TradeEngine.heal(state: &state)
        if cost > 0 {
            SoundPlayer.play("opendoor")
            commit()
        }
        return cost
    }

    @discardableResult
    func upgradeCapacity() -> Bool {
        let ok = TradeEngine.upgradeCapacity(state: &state)
        if ok {
            SoundPlayer.play("level")
            commit()
        }
        return ok
    }

    /// 跑一个圈子 = 过一天。
    func travel(to venueID: String) {
        TradeEngine.travel(to: venueID, state: &state, using: &rng, now: .now)
        playOutcomeSoundIfNeeded()
        commit()
    }

    /// 终局音：上岸奏 level，其余奏 death（原版语义）。
    private func playOutcomeSoundIfNeeded() {
        guard state.isGameOver else { return }
        SoundPlayer.play(state.outcome == .victory ? "level" : "death")
    }

    /// 沙盘顿悟：里程碑 → 掉卡/档案/属性（由沙盘承载页转发）。
    @discardableResult
    func recordMilestone(_ value: Int) -> EpiphanyReward? {
        let reward = EpiphanyEngine.recordMilestone(value, state: &state, using: &rng, now: .now)
        if reward != nil { commit() }
        return reward
    }

    /// 破产重开 / 手动重开：整局重置，开场消息按投递节奏逐条进来。
    func restart() {
        for task in deliveryTasks.values { task.cancel() }
        deliveryTasks = [:]
        typingNPCIDs = []
        revealedCounts = [:]
        generatedText = [:]
        negotiationSceneTags = [:]
        activeBanner = nil
        bannerBaseline = 0
        state = RainmakerEngine.newRun(using: &rng, now: .now)
        commit()
    }

    // MARK: - 列表筛选与搜索（WhatsApp 式列表页）

    enum ThreadFilter: String, CaseIterable {
        case all = "全部"
        case unread = "未读"
        case deals = "项目"
    }

    /// 列表数据源：筛选 + 搜索 + 按最后送达消息时间降序。
    /// 搜索命中 NPC 名字或任意已送达的文字消息；只看已送达（投递中不剧透）。
    func filteredThreads(query: String, filter: ThreadFilter) -> [NPCThread] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return state.threads
            .filter { thread in
                switch filter {
                case .all: true
                case .unread: unreadCount(npcID: thread.id) > 0
                case .deals: state.deals.contains {
                    $0.npcID == thread.id && ($0.status == .offered || $0.status == .negotiating)
                }
                }
            }
            .filter { thread in
                guard !trimmed.isEmpty else { return true }
                if let name = NPCCatalog.profile(id: thread.id)?.name, name.localizedCaseInsensitiveContains(trimmed) {
                    return true
                }
                return visibleEvents(npcID: thread.id).contains { event in
                    switch event {
                    case let .npcText(_, text, _), let .playerText(_, text, _):
                        text.localizedCaseInsensitiveContains(trimmed)
                    case .dealOffer, .systemNotice:
                        false
                    }
                }
            }
            .sorted { a, b in
                let lastA = visibleEvents(npcID: a.id).last?.at ?? .distantPast
                let lastB = visibleEvents(npcID: b.id).last?.at ?? .distantPast
                return lastA > lastB
            }
    }

    // MARK: - 已读 / 可见

    /// 已送达的事件（UI 只渲染这些）。
    func visibleEvents(npcID: String) -> [RainmakerEvent] {
        guard let events = state.threads.first(where: { $0.id == npcID })?.events else { return [] }
        return Array(events.prefix(revealedCounts[npcID] ?? 0))
    }

    /// UI 展示文本：npcText 若有生成式覆盖则用之，否则用真相层原文；其余事件用原文。
    func displayText(for event: RainmakerEvent) -> String {
        switch event {
        case let .npcText(id, text, _):
            return generatedText[id] ?? text
        case let .playerText(_, text, _), let .systemNotice(_, text, _):
            return text
        case .dealOffer:
            return ""
        }
    }

    /// 未读 = 已读游标之后、已送达的非我方事件数（没送达的不算，角标随送达增长）。
    func unreadCount(npcID: String) -> Int {
        let visible = visibleEvents(npcID: npcID)
        let read = min(state.readCounts?[npcID] ?? 0, visible.count)
        return visible[read...].filter { !$0.isMine }.count
    }

    func markRead(npcID: String) {
        state.markRead(npcID: npcID)
        persist()
    }

    // MARK: - 系统通知

    /// 打开通知中心：全部已读。
    func markNoticesRead() {
        state.markNoticesRead()
        persist()
    }

    /// 横幅到时自动收起 / 用户上滑关闭。
    func dismissBanner() {
        activeBanner = nil
    }

    /// 引擎新写入的通知里，弹最新一条做横幅（其余靠通知中心角标）。
    private func publishBanner() {
        let log = state.noticeLog
        guard log.count > bannerBaseline else { return }
        bannerBaseline = log.count
        activeBanner = log.last
    }

    // MARK: - 私有

    /// 引擎改动后统一出口：落盘 + 调度投递 + 弹通知横幅。
    private func commit() {
        persist()
        scheduleDelivery()
        publishBanner()
    }

    private func scheduleDelivery() {
        for thread in state.threads {
            let target = thread.events.count
            let current = revealedCounts[thread.id] ?? 0
            guard target > current else { continue }
            if instantDelivery {
                revealedCounts[thread.id] = target
                continue
            }
            guard deliveryTasks[thread.id] == nil else { continue }
            let npcID = thread.id
            deliveryTasks[npcID] = Task { [weak self] in
                await self?.deliver(npcID: npcID)
            }
        }
    }

    /// 逐条送达：我方消息即时；NPC 文字先「正在输入…」再到；通知/卡片短暂停顿。
    /// 联系人 NPC 文字若接入了生成式，await 期间即「正在输入…」——网络延迟天然充当「先想后说」节奏；
    /// 失败/未接入则回退固定 900ms + 真相层台词池文本。
    private func deliver(npcID: String) async {
        defer {
            // 被取消（restart 已重置 deliveryTasks/typingNPCIDs）时不清理，
            // 否则挂起点唤醒后的旧任务会抹掉新局面刚建的同名投递任务。
            if !Task.isCancelled {
                deliveryTasks[npcID] = nil
                typingNPCIDs.remove(npcID)
            }
        }
        while !Task.isCancelled,
              let events = state.threads.first(where: { $0.id == npcID })?.events,
              (revealedCounts[npcID] ?? 0) < events.count {
            let index = revealedCounts[npcID] ?? 0
            let event = events[index]
            if event.isMine {
                revealedCounts[npcID] = index + 1
                continue
            }
            if case let .npcText(eventID, _, _) = event {
                typingNPCIDs.insert(npcID)
                if let client = personaChat, let request = personaChatRequest(npcID: npcID, index: index) {
                    if let text = try? await client.reply(for: request) {
                        generatedText[eventID] = text
                    }
                    // 生成失败：直接揭示台词池原文（不再补睡）
                } else {
                    try? await Task.sleep(for: .milliseconds(900))
                }
                typingNPCIDs.remove(npcID)
            } else {
                try? await Task.sleep(for: .milliseconds(400))
            }
            if Task.isCancelled { return }
            revealedCounts[npcID] = index + 1
        }
    }

    /// 为第 index 条联系人 npcText 组请求：谈判台词按场景标签直取，
    /// 其余意图由邻居推断，历史取最近 N 轮。
    /// 返回 nil 表示不增强（assistant 线程 / 非 npcText / 越界）。
    private func personaChatRequest(npcID: String, index: Int) -> PersonaChatRequest? {
        guard npcID != RainmakerEngine.assistantNPCID,
              let profile = NPCCatalog.profile(id: npcID),
              let events = state.threads.first(where: { $0.id == npcID })?.events,
              index < events.count,
              case let .npcText(eventID, _, _) = events[index] else { return nil }

        let intent: PersonaChatRequest.Intent
        var playerMessage: String?
        var deal: PersonaChatRequest.DealContext?
        var negotiation: PersonaChatRequest.NegotiationContext?
        if let tag = negotiationSceneTags[eventID] {
            intent = tag.intent
            negotiation = tag.context
        } else if index > 0, case let .playerText(_, text, _) = events[index - 1] {
            intent = .reply
            playerMessage = text
        } else if index + 1 < events.count, case let .dealOffer(_, dealID, _) = events[index + 1] {
            intent = .dealIntro
            if let offer = state.deals.first(where: { $0.id == dealID }) {
                deal = .init(title: offer.title, valuation: offer.valuation, commission: offer.commission)
            }
        } else {
            intent = .greeting
        }

        let priorTurns: [PersonaChatRequest.Turn] = events.prefix(index).compactMap { event in
            switch event {
            case .npcText:
                return .init(role: .npc, text: displayText(for: event))
            case let .playerText(_, text, _):
                return .init(role: .player, text: text)
            default:
                return nil
            }
        }

        return PersonaChatRequest(
            npc: .init(id: profile.id, name: profile.name, role: profile.role, persona: profile.persona),
            history: Array(priorTurns.suffix(historyWindow)),
            intent: intent,
            deal: deal,
            playerMessage: playerMessage,
            negotiation: negotiation
        )
    }

    /// 测试辅助：等待某线程当前投递任务跑完（含生成式增强）。
    func awaitDelivery(npcID: String) async {
        await deliveryTasks[npcID]?.value
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
