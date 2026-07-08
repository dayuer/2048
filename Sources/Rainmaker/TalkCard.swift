import Foundation

/// 对手类型标签：卡牌无效矩阵的另一半。
/// 教学核心——用错估值框架，对面直接嘲讽你（0 分）。
enum NPCTrait: String, Codable, Sendable {
    case preRevenue     // 早期无利润（产品未上线/烧钱换增长）
    case traditional    // 传统盈利生意（餐饮/地产，看现金流不看日活）
    case institutional  // 机构专业玩家（对叙事免疫，只认数据）
}

/// 谈判策略包（话术卡）。伤害 = chips × mult。
/// 内容取材真实创投知识体系：Term Sheet 条款 / 估值方法 / 谈判心理学。
struct TalkCard: Identifiable, Equatable, Sendable {
    enum Effect: String, Codable, Sendable {
        /// 对赌协议：本牌高倍率，但本局爆仓时信誉损失翻倍。
        case vamHighRisk
        /// 优先清算权：保本条款——任何时候可签约，佣金保底 payoutFloorRatio。
        case payoutFloor
    }

    let id: String
    let name: String
    let chips: Int
    let mult: Double
    /// 一句话知识点：复盘报告与词典（Phase 2.5）复用。
    let knowledge: String
    /// 对这类对手无效（0 分 + 嘲讽）。nil = 通用。
    let invalidAgainst: NPCTrait?
    /// 无效时对方的嘲讽台词（交互式教程）。
    let tauntWhenInvalid: String?
    let effect: Effect?

    init(
        id: String, name: String, chips: Int, mult: Double, knowledge: String,
        invalidAgainst: NPCTrait? = nil, tauntWhenInvalid: String? = nil, effect: Effect? = nil
    ) {
        self.id = id
        self.name = name
        self.chips = chips
        self.mult = mult
        self.knowledge = knowledge
        self.invalidAgainst = invalidAgainst
        self.tauntWhenInvalid = tauntWhenInvalid
        self.effect = effect
    }
}

/// 新手村卡池（青铜 FA · 天使轮看脸阶段）。
/// 白银（Term Sheet 进阶）/ 王者（毒丸、白衣骑士、LBO）随职级解锁——后续扩展。
enum CardCatalog {
    static let rookiePool: [TalkCard] = [
        TalkCard(
            id: "team-halo", name: "团队背景耀眼", chips: 12, mult: 1.0,
            knowledge: "早期投资的第一逻辑是投人——天使轮里团队履历是最大的信用背书。"
        ),
        TalkCard(
            id: "ppt-vision", name: "PPT 画大饼", chips: 8, mult: 1.5,
            knowledge: "愿景叙事对早期个人投资者有效；机构投资人对故事免疫，只认数据。",
            invalidAgainst: .institutional,
            tauntWhenInvalid: "我一年看一万份 BP，这页饼我见过八百次。讲数据，谢谢。"
        ),
        TalkCard(
            id: "industry-data", name: "甩出行业数据", chips: 15, mult: 1.0,
            knowledge: "可比公司分析（Comps）——用行业基准锚定谈判起点，是投行估值第一步。"
        ),
        TalkCard(
            id: "finance-hole", name: "查出财务漏洞", chips: 10, mult: 2.0,
            knowledge: "尽职调查的价值所在——财务瑕疵是谈判桌上最硬的压价杠杆。"
        ),
        TalkCard(
            id: "pe-ratio", name: "市盈率质疑", chips: 20, mult: 1.5,
            knowledge: "P/E 只适用于有稳定利润的公司；早期科技项目要看市销率（P/S）或用户增长。",
            invalidAgainst: .preRevenue,
            tauntWhenInvalid: "我们产品都没上线，哪来的利润？连财报都看不懂就别提 P/E——请看用户增长率！"
        ),
        TalkCard(
            id: "dau-fraud", name: "日活注水质疑", chips: 18, mult: 1.5,
            knowledge: "指标要匹配商业模式——互联网看 DAU/留存，线下生意看坪效、翻台率。",
            invalidAgainst: .traditional,
            tauntWhenInvalid: "我开餐馆的看什么日活？翻台率、坪效了解一下。"
        ),
        TalkCard(
            id: "late-night", name: "深夜施压", chips: 5, mult: 2.5,
            knowledge: "时间压力战术——临近 deadline 对方让步意愿最大（Chris Voss《绝对谈判》）。"
        ),
        TalkCard(
            id: "fake-concession", name: "虚假让步", chips: 6, mult: 2.0,
            knowledge: "锚定与校准型问题——先抛虚高锚点，再『让步』到真实目标价。"
        ),
        TalkCard(
            id: "vam", name: "对赌协议", chips: 14, mult: 2.0,
            knowledge: "VAM 能大幅拉升当期估值，但目标未达时反噬致命——本局爆仓信誉损失翻倍。",
            effect: .vamHighRisk
        ),
        TalkCard(
            id: "liq-pref", name: "优先清算权", chips: 12, mult: 1.0,
            knowledge: "投资人保本的终极条款——清算时资金优先返还。打出后任何时候可按保底签约。",
            effect: .payoutFloor
        ),
    ]

    static func card(id: String) -> TalkCard? {
        rookiePool.first { $0.id == id }
    }
}
