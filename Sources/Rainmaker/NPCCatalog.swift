import Foundation

/// NPC 人设：survival「Agent 人设」在 Rainmaker 的落地。
/// 生成式对话时组 system-prompt 用；离线/未配置时不影响任何逻辑（仅台词池生效）。
struct NPCPersona: Codable, Sendable {
    /// 背景与身份底色。
    let background: String
    /// 说话声线/语气（一致性来源）。
    let voice: String
    /// 在意什么、看重什么（价值观驱动回应）。
    let values: String
    /// 口头禅 / 小癖好（拟真细节）。
    let quirks: String
    /// 谈判立场倾向（叙事用，不参与算分）。
    let negotiationStance: String
}

/// 一位可谈生意的 NPC。icon 为 SF Symbol，UI 层配色。
struct NPCProfile: Identifiable, Sendable {
    let id: String
    let name: String
    let role: String
    let icon: String
    /// 对手类型：决定哪些策略包对其无效（知识教学矩阵）。
    let traits: [NPCTrait]
    /// 人设：生成式对话组 prompt 用。
    let persona: NPCPersona
    /// 发项目单前的寒暄台词池。
    let greetings: [String]
    /// 闲聊回复池（玩家主动发消息时抽一句）。
    let smallTalk: [String]
    /// 项目单模板池。
    let dealTemplates: [DealTemplate]

    init(
        id: String, name: String, role: String, icon: String,
        traits: [NPCTrait] = [], persona: NPCPersona, greetings: [String],
        smallTalk: [String], dealTemplates: [DealTemplate]
    ) {
        self.id = id
        self.name = name
        self.role = role
        self.icon = icon
        self.traits = traits
        self.persona = persona
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
        persona: NPCPersona(
            background: "你的贴身助理，管日程、盯开销、提醒规则，不掺和具体谈判。",
            voice: "简短、体贴、带点唠叨的关切，管你叫「老板」。",
            values: "把老板的时间和现金流看得最重，见不得工时和钱被浪费。",
            quirks: "爱用「放心」「提醒一句」开头，说完事就收。",
            negotiationStance: "不谈判，只在旁边递情报和提醒。"
        ),
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
            persona: NPCPersona(
                background: "连续创业者，做 SaaS，账上现金常年吃紧，靠增长故事融资续命。",
                voice: "热络、急切、爱套近乎，动不动就「老朋友」「靠你了」。",
                values: "只信增长曲线和月活，把估值当信心投票，讨厌被人拿市盈率压。",
                quirks: "开口先报数据涨幅，焦虑时反复提「账上撑不了几个月」。",
                negotiationStance: "先画大饼冲高估值，被戳穿数据后才肯谈实的。"
            ),
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
            persona: NPCPersona(
                background: "白手起家的连锁餐饮老板，三十家店起底，认现金流和坪效。",
                voice: "江湖气、豪爽，爱叫「兄弟」，谈事先请你吃饭。",
                values: "只认翻台率、坪效、看得见摸得着的生意，把互联网黑话当虚的。",
                quirks: "口头禅「生意是长跑」，动不动招呼你「来店里吃」。",
                negotiationStance: "钱的事不急，重人情，但账算得比谁都精。"
            ),
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
            persona: NPCPersona(
                background: "老牌基金合伙人，看过上千个项目，IC 会节奏紧，时间就是钱。",
                voice: "冷静、犀利、惜字如金，说话直击要害，不留情面。",
                values: "只看基本面和确定性，PPT 大饼一眼看穿，尊重讲真话的人。",
                quirks: "爱说「有事说重点」「行业冷才看得出谁在裸泳」。",
                negotiationStance: "老兵不吃唬，条款抠得细，但认专业、认数据。"
            ),
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
            persona: NPCPersona(
                background: "产业园招商负责人，手握返税政策和厂房资源，靠拉企业落地拿绩效。",
                voice: "热情、场面话足、爱张罗饭局，官腔和江湖气混着来。",
                values: "看重政策窗口和落地速度，讲究关系、返佣、把事办成。",
                quirks: "口头禅「政策窗口就这几个月」，爱招呼「晚上喝酒，把张主任也叫上」。",
                negotiationStance: "以政策和介绍费开路，撮合成了才算数。"
            ),
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
