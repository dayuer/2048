import Foundation

/// 生成式对话接入的抽象 seam。
/// 真实实现走 survival OpenClaw 后端；测试/离线用 Mock；未配置则不接入（回退台词池）。
protocol PersonaChatClient: Sendable {
    /// 依据人设 + 记忆 + 意图，返回一句符合角色的中文回复。
    /// 失败即抛错——调用方（Store）据此回退到确定性台词池文本。
    func reply(for request: PersonaChatRequest) async throws -> String
}

/// 一次生成式对话请求。纯 Codable，直接作为 survival 端点的 JSON 请求体。
struct PersonaChatRequest: Codable, Sendable {
    /// 说话的 NPC 及其人设。
    struct NPCDescriptor: Codable, Sendable {
        let id: String
        let name: String
        let role: String
        let persona: NPCPersona
    }

    /// 一轮历史发言（最近 N 轮，供记忆连续）。
    struct Turn: Codable, Sendable {
        enum Role: String, Codable, Sendable {
            case npc
            case player
        }
        let role: Role
        let text: String
    }

    /// 项目铺垫时附上的项目上下文。
    struct DealContext: Codable, Sendable {
        let title: String
        let valuation: Int
        let commission: Int
    }

    /// 谈判桌台词附带的牌局上下文（谈判类意图专用）。
    struct NegotiationContext: Codable, Sendable {
        let dealTitle: String
        /// 玩家刚打出的策略牌名（open/sign 场景为 nil）。
        let cardName: String?
        /// 无效牌的教学知识点（仅 taunt 场景）。
        let cardKnowledge: String?
        /// 本轮压掉的底线点数（仅 hurt 场景）。
        let damage: Int?
        /// 对方底线剩余百分比（0-100）。
        let defenseRemainingPercent: Int
    }

    /// 本条 NPC 发言的意图（由 Store 从邻居事件零成本推断；谈判类由出牌结果打标）。
    enum Intent: String, Codable, Sendable {
        case greeting              // 每日开场寒暄
        case dealIntro = "deal_intro"  // 项目单开场铺垫
        case reply                 // 回应玩家刚发的话
        case ambient               // 无由头的闲话（本期不主动产出，契约保留）
        case negotiationOpen = "negotiation_open"    // 谈判桌：应战开场
        case negotiationHurt = "negotiation_hurt"    // 谈判桌：被有效命中，吃痛
        case negotiationTaunt = "negotiation_taunt"  // 谈判桌：无效牌，嘲讽
        case negotiationSign = "negotiation_sign"    // 谈判桌：见好就收签约
        case negotiationBreak = "negotiation_break"  // 谈判桌：底线击穿认输
        case negotiationBust = "negotiation_bust"    // 谈判桌：谈崩翻脸
    }

    let npc: NPCDescriptor
    let history: [Turn]
    let intent: Intent
    let deal: DealContext?
    let playerMessage: String?
    /// 谈判类意图的牌局上下文；其余意图为 nil。
    let negotiation: NegotiationContext?

    init(
        npc: NPCDescriptor, history: [Turn], intent: Intent,
        deal: DealContext? = nil, playerMessage: String? = nil,
        negotiation: NegotiationContext? = nil
    ) {
        self.npc = npc
        self.history = history
        self.intent = intent
        self.deal = deal
        self.playerMessage = playerMessage
        self.negotiation = negotiation
    }
}
