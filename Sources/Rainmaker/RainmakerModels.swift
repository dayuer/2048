import Foundation

/// 《顶级掮客》Phase 1 数值表。资金单位：万元。
enum RainmakerBalance {
    static let startCash = 100
    static let startReputation = 50
    static let apPerDay = 4
    /// 每日固定开销（房租/团队），结算时自动扣除。
    static let burnRate = 8
    /// 项目交割后的信誉奖励。
    static let dealReputationReward = 2
    /// Phase 1 接单统一 AP 成本。
    static let dealAPCost = 1

    // MARK: 谈判（Phase 2）

    /// 入场抵押信誉：爆仓不退，对赌爆仓翻倍扣。
    static let negotiationRepStake = 5
    /// 开局手牌数：打空即交易流产。
    static let handSize = 6
    /// 防线降到该比例以下解锁【同意签约】（见好就收）。
    static let signUnlockRatio = 0.6
    /// 优先清算权在手时的佣金保底比例。
    static let payoutFloorRatio = 0.4
    /// 底线估值 = 项目估值 / 100，夹在此区间。
    static let defenseRange = 25...150

    // MARK: 顿悟（Phase 3）

    /// 卡库容量：沙盘掉卡囤积上限。
    static let cardInventoryCap = 5
    /// 每场谈判最多从卡库带走的卡数（开局即消耗）。
    static let inventoryHandBonus = 2
}

/// NPC 发来的项目单（商业计划书卡片）。Phase 2：接单即进入条款谈判。
struct DealOffer: Codable, Equatable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case offered      // 卡片已发出，等玩家开始尽调
        case negotiating  // 谈判进行中（占用 activeNegotiation）
        case won          // 签约/击破成交，佣金已入账
        case busted       // 交易流产（爆仓/拖延），抵押信誉没收
        case expired      // 当日未接，作废
    }

    let id: UUID
    let npcID: String
    let title: String
    /// 目标估值（万），叙事字段。
    let valuation: Int
    /// 成交佣金（万）。
    let commission: Int
    let apCost: Int
    var status: Status
}

/// NPC 线程里的一条事件。Phase 1 四态；Phase 2 牌局在此扩展。
enum RainmakerEvent: Codable, Equatable, Identifiable, Sendable {
    case npcText(id: UUID, text: String, at: Date)
    case playerText(id: UUID, text: String, at: Date)
    case dealOffer(id: UUID, dealID: UUID, at: Date)
    case systemNotice(id: UUID, text: String, at: Date)

    var id: UUID {
        switch self {
        case let .npcText(id, _, _): id
        case let .playerText(id, _, _): id
        case let .dealOffer(id, _, _): id
        case let .systemNotice(id, _, _): id
        }
    }

    var at: Date {
        switch self {
        case let .npcText(_, _, at): at
        case let .playerText(_, _, at): at
        case let .dealOffer(_, _, at): at
        case let .systemNotice(_, _, at): at
        }
    }

    /// 我方发出的事件（不计未读、气泡靠右、投递不延迟）。
    var isMine: Bool {
        if case .playerText = self { return true }
        return false
    }
}

/// 一根 NPC 对话线程。id 即 NPCCatalog 里的 npcID。
struct NPCThread: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var events: [RainmakerEvent]

    var lastEventAt: Date { events.last?.at ?? .distantPast }
}

/// 整局游戏状态：资源 + 项目 + 线程 + 进行中的谈判。纯 Codable，单一存档。
struct RainmakerState: Codable, Equatable, Sendable {
    var day: Int
    var cash: Int
    var reputation: Int
    var ap: Int
    var isGameOver: Bool
    var deals: [DealOffer]
    var threads: [NPCThread]
    /// 同一时间只允许一场谈判（PRD：深度沟通独占注意力）。
    var activeNegotiation: NegotiationSession?
    /// 每根线程已读到的事件数（threadID → count）。
    /// Optional 以兼容旧存档（decodeIfPresent），一律走 unreadCount/markRead 访问。
    var readCounts: [String: Int]?
    /// 沙盘顿悟掉落的一次性话术卡（下场谈判开局消耗）。Optional 兼容旧存档。
    var cardInventory: [String]?
    /// 已解锁的商业绝密档案。Optional 兼容旧存档。
    var unlockedArchives: [String]?
    /// 市场气候（世界观宏观变量）。Optional 兼容旧存档，读取一律走 climate。
    var marketClimate: MarketClimate?

    /// 当前气候，缺省中性。
    var climate: MarketClimate { marketClimate ?? .neutral }

    init(
        day: Int, cash: Int, reputation: Int, ap: Int, isGameOver: Bool,
        deals: [DealOffer], threads: [NPCThread], activeNegotiation: NegotiationSession? = nil
    ) {
        self.day = day
        self.cash = cash
        self.reputation = reputation
        self.ap = ap
        self.isGameOver = isGameOver
        self.deals = deals
        self.threads = threads
        self.activeNegotiation = activeNegotiation
    }

    // MARK: 未读

    /// 未读 = 已读游标之后的非我方事件数。
    func unreadCount(npcID: String) -> Int {
        guard let events = threads.first(where: { $0.id == npcID })?.events else { return 0 }
        let read = min(readCounts?[npcID] ?? 0, events.count)
        return events[read...].filter { !$0.isMine }.count
    }

    /// 点开线程即已读到当前末尾。
    mutating func markRead(npcID: String) {
        guard let count = threads.first(where: { $0.id == npcID })?.events.count else { return }
        var counts = readCounts ?? [:]
        counts[npcID] = count
        readCounts = counts
    }
}
