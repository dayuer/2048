import Foundation

/// 一位可谈生意的 NPC。icon 为 SF Symbol，UI 层配色。
struct NPCProfile: Identifiable, Sendable {
    let id: String
    let name: String
    let role: String
    let icon: String
    /// 对手类型：决定哪些策略包对其无效（知识教学矩阵）。
    let traits: [NPCTrait]
    /// 发项目单前的寒暄台词池。
    let greetings: [String]
    /// 闲聊回复池（玩家主动发消息时抽一句）。
    let smallTalk: [String]
    /// 项目单模板池。
    let dealTemplates: [DealTemplate]

    init(
        id: String, name: String, role: String, icon: String,
        traits: [NPCTrait] = [], greetings: [String],
        smallTalk: [String], dealTemplates: [DealTemplate]
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.icon = icon
        self.traits = traits
        self.greetings = greetings
        self.smallTalk = smallTalk
        self.dealTemplates = dealTemplates
    }
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
        smallTalk: [
            "老板放心，日程我都盯着呢。",
            "提醒一句：工时用完记得【结束今日】，开销不等人。",
            "谈判前先看清对手是早期、传统还是机构——策略包别打错对象。",
            "词典在「发现」页，谈判卡上的 ⓘ 也能直接查。",
        ],
        dealTemplates: []
    )

    /// 会发项目单的商界联系人。
    static let contacts: [NPCProfile] = [
        NPCProfile(
            id: "chen",
            name: "陈总",
            role: "SaaS 创始人",
            icon: "laptopcomputer",
            traits: [.preRevenue],   // 烧钱换增长——别跟他提市盈率
            greetings: [
                "老朋友，最近手头有点紧，融资的事还得靠你。",
                "在吗？我们数据涨得不错，是时候推下一轮了。",
            ],
            smallTalk: [
                "刚开完产品会，我们月活又涨了 30%。",
                "融资的事有眉目了吗？账上现金撑不了几个月了。",
                "改天来我们办公室，给你演示新版本。",
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
            traits: [.traditional],  // 看翻台率坪效——别跟他谈日活
            greetings: [
                "兄弟，我这三十家店想再开五十家，帮我找钱。",
                "有个同行想卖盘子，你看看能不能撮合。",
            ],
            smallTalk: [
                "今晚来店里吃，我让后厨给你留位置。",
                "这个月翻台率又创新高，扩张的事你上点心。",
                "钱的事不急，生意是长跑。",
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
            traits: [.institutional],  // 机构老兵——PPT 大饼对她无效
            greetings: [
                "我们二期基金要出手了，帮我筛几个好项目。",
                "有个 LP 想退，帮我找份额买家，费用好说。",
            ],
            smallTalk: [
                "最近看的项目十个里九个不行，你手上有好标的吗？",
                "IC 会刚结束，节奏很紧，有事说重点。",
                "行业冷的时候，才看得出谁在裸泳。",
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
            traits: [.traditional],
            greetings: [
                "园区给的返税政策批下来了，帮我拉两家企业过来。",
                "有家制造业想搬迁，撮合成了给你介绍费。",
            ],
            smallTalk: [
                "园区二期下个月封顶，来剪彩不？",
                "政策窗口就这几个月，有企业要落地抓紧说。",
                "晚上喝酒？把张主任也叫上。",
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
