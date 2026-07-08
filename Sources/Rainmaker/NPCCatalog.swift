import Foundation

/// 一位可谈生意的 NPC。icon 为 SF Symbol，UI 层配色。
struct NPCProfile: Identifiable, Sendable {
    let id: String
    let name: String
    let role: String
    let icon: String
    /// 发项目单前的寒暄台词池。
    let greetings: [String]
    /// 项目单模板池。
    let dealTemplates: [DealTemplate]
}

/// 项目单模板：估值/佣金在区间内随机，保证同种子同结果。
struct DealTemplate: Sendable {
    let title: String
    let valuationRange: ClosedRange<Int>   // 万
    let commissionRange: ClosedRange<Int>  // 万
}

/// 静态 NPC 名录。assistant 是系统秘书线程，不发项目单。
enum NPCCatalog {
    static let assistant = NPCProfile(
        id: "assistant",
        name: "小何（助理）",
        role: "你的助理",
        icon: "person.text.rectangle",
        greetings: [],
        dealTemplates: []
    )

    /// 会发项目单的商界联系人。
    static let contacts: [NPCProfile] = [
        NPCProfile(
            id: "chen",
            name: "陈总",
            role: "SaaS 创始人",
            icon: "laptopcomputer",
            greetings: [
                "老朋友，最近手头有点紧，融资的事还得靠你。",
                "在吗？我们数据涨得不错，是时候推下一轮了。",
            ],
            dealTemplates: [
                DealTemplate(title: "SaaS A 轮找领投", valuationRange: 8000...15000, commissionRange: 18...30),
                DealTemplate(title: "老股转让找接盘方", valuationRange: 5000...9000, commissionRange: 12...20),
            ]
        ),
        NPCProfile(
            id: "zhou",
            name: "周老板",
            role: "连锁餐饮",
            icon: "fork.knife",
            greetings: [
                "兄弟，我这三十家店想再开五十家，帮我找钱。",
                "有个同行想卖盘子，你看看能不能撮合。",
            ],
            dealTemplates: [
                DealTemplate(title: "连锁餐饮扩张融资", valuationRange: 3000...6000, commissionRange: 10...18),
                DealTemplate(title: "区域品牌并购撮合", valuationRange: 4000...8000, commissionRange: 14...24),
            ]
        ),
        NPCProfile(
            id: "ma",
            name: "马姐",
            role: "基金合伙人",
            icon: "chart.line.uptrend.xyaxis",
            greetings: [
                "我们二期基金要出手了，帮我筛几个好项目。",
                "有个 LP 想退，帮我找份额买家，费用好说。",
            ],
            dealTemplates: [
                DealTemplate(title: "基金份额转让撮合", valuationRange: 10000...20000, commissionRange: 22...40),
                DealTemplate(title: "项目库尽调外包", valuationRange: 2000...4000, commissionRange: 8...14),
            ]
        ),
        NPCProfile(
            id: "liu",
            name: "大刘",
            role: "产业园招商",
            icon: "building.2",
            greetings: [
                "园区给的返税政策批下来了，帮我拉两家企业过来。",
                "有家制造业想搬迁，撮合成了给你介绍费。",
            ],
            dealTemplates: [
                DealTemplate(title: "企业落地招商返佣", valuationRange: 2000...5000, commissionRange: 10...16),
                DealTemplate(title: "厂房资产盘活交易", valuationRange: 6000...12000, commissionRange: 16...28),
            ]
        ),
    ]

    static func profile(id: String) -> NPCProfile? {
        if id == assistant.id { return assistant }
        return contacts.first { $0.id == id }
    }
}
