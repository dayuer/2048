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
}

/// NPC 发来的项目单（商业计划书卡片）。Phase 1 简化：接单→次日结算发佣金。
struct DealOffer: Codable, Equatable, Identifiable, Sendable {
    enum Status: String, Codable, Sendable {
        case offered    // 卡片已发出，等玩家接
        case accepted   // 已接，占用 AP，次日结算
        case paid       // 已交割，佣金已入账
        case expired    // 当日未接，作废
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
}

/// 一根 NPC 对话线程。id 即 NPCCatalog 里的 npcID。
struct NPCThread: Codable, Equatable, Identifiable, Sendable {
    let id: String
    var events: [RainmakerEvent]

    var lastEventAt: Date { events.last?.at ?? .distantPast }
}

/// 整局游戏状态：资源 + 项目 + 线程。纯 Codable，单一存档。
struct RainmakerState: Codable, Equatable, Sendable {
    var day: Int
    var cash: Int
    var reputation: Int
    var ap: Int
    var isGameOver: Bool
    var deals: [DealOffer]
    var threads: [NPCThread]
}
