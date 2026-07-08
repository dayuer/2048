import Foundation

/// 《顶级掮客》数值表。资金单位：万元。
/// 浮生记融合后开局对齐原版：现金 2000 / 欠债 5000。
enum RainmakerBalance {
    static let startCash = 2000
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

    // MARK: 浮生记线（数值锚定原版：2000/5000/日息10%/容量100/40天）

    /// 欠衡颂资本沈墨的过桥资金（万）。
    static let startDebt = 5000
    /// 债务日息（每天结算时滚入本金）。
    static let debtDailyRate = 0.10
    /// 银行存款日息。
    static let bankDailyRate = 0.01
    /// 大限：40 天内见分晓。
    static let deadlineDay = 40
    /// 开局健康值；归零 = 牺牲在北京街头。
    static let startHealth = 100
    /// 托管账户初始容量（手）。
    static let startCapacity = 100
    /// 扩容一次的价格（万）与增量（手）。原版 20000 元 1:1 搬来会变 2 亿（贫困陷阱），
    /// 按本作「万元」经济与 burnRate 8/天 校准为 200 万——仍是笔正经投资，但可达。
    static let capacityUpgradeCost = 200
    static let capacityUpgradeGain = 10
    /// 私立医院回血价：每点健康（万）。原版 3500 元 1:1 搬来会变 3500 万/点（治不起），
    /// 校准为 2 万/点（回满 100 点 = 200 万），健康仍是有代价的生存资源。
    static let healCostPerPoint = 2
    /// 卖出涉灰资产每笔扣的信誉。
    static let greySellRepPenalty = 1
    /// 债务逾期（后期未清）时资方保全+连番质询的健康伤害。
    static let overdueBeatingDamage = 25
}

/// 终局方式：浮生记式结算。
enum RunOutcome: String, Codable, Sendable {
    case bankrupt        // 现金归零（原有破产）
    case beaten          // 健康归零，牺牲在北京街头
    case debtUnpaid      // 40 天到期债没还清，上被执行人名单 + 限高
    case victory         // 40 天到期且无债——上岸，按净资产登榜
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

/// 一条系统旁白（世界事件 / 每日结算 / 谈判记分 / 复盘报告）。
/// 不进聊天线程——UI 以应用内通知横幅即时弹出，并落「系统通知」中心可回看。
struct SystemNotice: Codable, Equatable, Identifiable, Sendable {
    let id: UUID
    let text: String
    let at: Date
}

/// NPC 线程里的一条事件。Phase 1 四态；Phase 2 牌局在此扩展。
/// systemNotice 已废弃不再产生（旁白改走 SystemNotice 通知），保留 case 以解码旧存档。
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
    /// 系统通知日志（旧→新追加在尾部）。Optional 兼容旧存档，读取走 noticeLog。
    var notices: [SystemNotice]?
    /// 已读通知数（通知中心角标 = 总数 − 已读数）。
    var noticesReadCount: Int?

    /// 当前气候，缺省中性。
    var climate: MarketClimate { marketClimate ?? .neutral }

    // MARK: 浮生记线（全部 Optional 兼容旧存档，读取走带默认值的访问器）

    /// 欠沈墨的债（万），每日滚息。
    var debt: Int?
    /// 当前所在圈子 id。
    var venueID: String?
    /// 健康值，归零出局。
    var health: Int?
    /// 银行存款（万），日息生息。
    var bankDeposit: Int?
    /// 托管容量（手）。
    var capacity: Int?
    /// 持仓：资产 id → 手数。
    var holdings: [String: Int]?
    /// 当日当地行情：资产 id → 单价（万）。缺席的资产 = 今日无货。
    var assetPrices: [String: Int]?
    /// 终局方式（isGameOver 时有值；victory 也置 isGameOver 终止操作）。
    var outcome: RunOutcome?

    var currentDebt: Int { debt ?? 0 }
    var currentVenueID: String { venueID ?? TradeCatalog.startVenueID }
    var currentHealth: Int { health ?? RainmakerBalance.startHealth }
    var currentBankDeposit: Int { bankDeposit ?? 0 }
    var currentCapacity: Int { capacity ?? RainmakerBalance.startCapacity }
    var currentHoldings: [String: Int] { holdings ?? [:] }
    /// 已占用的托管手数。
    var usedCapacity: Int { currentHoldings.values.reduce(0, +) }
    /// 净资产 = 现金 + 存款 + 持仓市价 - 债务（登榜分数）。
    var netWorth: Int {
        let stockValue = currentHoldings.reduce(0) { sum, entry in
            sum + (assetPrices?[entry.key] ?? TradeCatalog.asset(id: entry.key)?.basePrice ?? 0) * entry.value
        }
        return cash + currentBankDeposit + stockValue - currentDebt
    }

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

    // MARK: 系统通知

    var noticeLog: [SystemNotice] { notices ?? [] }
    var unreadNoticeCount: Int { max(0, noticeLog.count - (noticesReadCount ?? 0)) }

    /// 打开通知中心即全部已读。
    mutating func markNoticesRead() {
        noticesReadCount = noticeLog.count
    }

    /// 旧存档迁移：债主换角「赵村长」(cunzhang) → 「沈墨」(shen)，线程与已读游标一起搬。
    mutating func migrateCreditorIDIfNeeded() {
        let oldID = "cunzhang"
        guard let index = threads.firstIndex(where: { $0.id == oldID }) else { return }
        threads[index] = NPCThread(id: NPCCatalog.creditor.id, events: threads[index].events)
        if var counts = readCounts, let read = counts.removeValue(forKey: oldID) {
            counts[NPCCatalog.creditor.id] = read
            readCounts = counts
        }
    }

    /// 旧存档迁移：聊天线程里的 systemNotice 全部搬进通知日志（记为已读，不补弹横幅）。
    mutating func migrateThreadNoticesIfNeeded() {
        var migrated: [SystemNotice] = []
        for index in threads.indices {
            threads[index].events.removeAll { event in
                guard case let .systemNotice(id, text, at) = event else { return false }
                migrated.append(SystemNotice(id: id, text: text, at: at))
                return true
            }
        }
        guard !migrated.isEmpty else { return }
        notices = (noticeLog + migrated).sorted { $0.at < $1.at }
        noticesReadCount = (noticesReadCount ?? 0) + migrated.count
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
