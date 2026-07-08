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

    // MARK: 生成式对话（显示层覆盖，不持久化）

    /// 生成式对话接入。nil = 不接入 → 走确定性台词池（默认）。
    var personaChat: PersonaChatClient?
    /// 事件 id → LLM 生成文本。真相层永不变，UI 经 displayText 覆盖显示。
    private(set) var generatedText: [UUID: String] = [:]
    /// 该线程可增强的最近 N 轮历史（喂给生成式做记忆连续）。
    private let historyWindow = 8

    init(fileURL: URL = RainmakerStore.defaultFileURL) {
        self.fileURL = fileURL
        if let data = try? Data(contentsOf: fileURL),
           let loaded = try? JSONDecoder().decode(RainmakerState.self, from: data) {
            self.state = loaded
        } else {
            var rng = SystemRandomNumberGenerator()
            self.state = RainmakerEngine.newRun(using: &rng, now: .now)
        }
        // 启动不重播历史：全部标记已送达
        for thread in state.threads {
            revealedCounts[thread.id] = thread.events.count
        }
        persist()
    }

    nonisolated static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("rainmaker-run.json")
    }

    // MARK: - 动作

    @discardableResult
    func startNegotiation(dealID: UUID) -> Bool {
        let started = NegotiationEngine.start(dealID: dealID, state: &state, using: &rng, now: .now)
        if started { commit() }
        return started
    }

    @discardableResult
    func play(cardID: String) -> NegotiationEngine.PlayOutcome? {
        let outcome = NegotiationEngine.play(cardID: cardID, state: &state, using: &rng, now: .now)
        if outcome != nil { commit() }
        return outcome
    }

    @discardableResult
    func sign() -> Int? {
        let payout = NegotiationEngine.sign(state: &state, using: &rng, now: .now)
        if payout != nil { commit() }
        return payout
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
                    case let .npcText(_, text, _), let .playerText(_, text, _), let .systemNotice(_, text, _):
                        text.localizedCaseInsensitiveContains(trimmed)
                    case .dealOffer:
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

    // MARK: - 私有

    /// 引擎改动后统一出口：落盘 + 调度投递。
    private func commit() {
        persist()
        scheduleDelivery()
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
            deliveryTasks[npcID] = nil
            typingNPCIDs.remove(npcID)
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

    /// 为第 index 条联系人 npcText 组请求：意图由邻居推断，历史取最近 N 轮。
    /// 返回 nil 表示不增强（assistant 线程 / 非 npcText / 越界）。
    private func personaChatRequest(npcID: String, index: Int) -> PersonaChatRequest? {
        guard npcID != RainmakerEngine.assistantNPCID,
              let profile = NPCCatalog.profile(id: npcID),
              let events = state.threads.first(where: { $0.id == npcID })?.events,
              index < events.count,
              case .npcText = events[index] else { return nil }

        let intent: PersonaChatRequest.Intent
        var playerMessage: String?
        var deal: PersonaChatRequest.DealContext?
        if index > 0, case let .playerText(_, text, _) = events[index - 1] {
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
            playerMessage: playerMessage
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
