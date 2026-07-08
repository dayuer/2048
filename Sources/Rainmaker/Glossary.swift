import Foundation

/// 创投百科词条。培训闭环的「查」环节：卡牌 ⓘ / 词典浏览器共用。
struct GlossaryEntry: Identifiable, Equatable, Sendable {
    enum Category: String, CaseIterable, Sendable {
        case valuation = "估值方法"
        case termSheet = "Term Sheet 条款"
        case negotiation = "谈判战术"
        case ecosystem = "行业生态"
        case greyAsset = "灰色资产"
    }

    let id: String
    let term: String
    /// 英文原词（无则空串不显示）。
    let english: String
    let category: Category
    let definition: String
    /// 知识出处（书目/领域），给想深挖的学员指路。
    let source: String
    /// 反向关联的策略包卡牌。
    let relatedCardIDs: [String]

    init(
        id: String, term: String, english: String = "", category: Category,
        definition: String, source: String, relatedCardIDs: [String] = []
    ) {
        self.id = id
        self.term = term
        self.english = english
        self.category = category
        self.definition = definition
        self.source = source
        self.relatedCardIDs = relatedCardIDs
    }
}

/// 静态词典目录。新手村先覆盖卡池涉及的概念 + 高频圈内黑话；
/// 白银/王者卡池（毒丸、白衣骑士、LBO 实战）扩池时同步扩词条。
enum Glossary {
    static let all: [GlossaryEntry] = [
        // MARK: 估值方法
        GlossaryEntry(
            id: "pe", term: "市盈率", english: "P/E Ratio", category: .valuation,
            definition: "股价（估值）÷ 每股盈利。只适用于有稳定利润的公司——对没有利润的早期项目谈 P/E 会被当场嘲笑，请改用市销率（P/S）或用户增长指标。",
            source: "《投资银行》Rosenbaum & Pearl",
            relatedCardIDs: ["pe-ratio"]
        ),
        GlossaryEntry(
            id: "ps", term: "市销率", english: "P/S Ratio", category: .valuation,
            definition: "估值 ÷ 营业收入。利润尚未转正的成长期公司的主流估值锚——收入是真金白银，比利润更早出现。",
            source: "《投资银行》Rosenbaum & Pearl"
        ),
        GlossaryEntry(
            id: "comps", term: "可比公司分析", english: "Comps", category: .valuation,
            definition: "找一篮子业务相近的上市/已融资公司，用它们的估值倍数反推目标公司价值。投行估值的第一步，也是谈判桌上最常用的锚。",
            source: "《投资银行》Rosenbaum & Pearl",
            relatedCardIDs: ["industry-data"]
        ),
        GlossaryEntry(
            id: "dcf", term: "现金流折现", english: "DCF", category: .valuation,
            definition: "把公司未来各年现金流按风险折回今天加总。理论最严谨、假设最多——每个参数都是谈判筹码。",
            source: "《投资银行》Rosenbaum & Pearl"
        ),
        GlossaryEntry(
            id: "unit-economics", term: "单位经济模型", english: "Unit Economics", category: .valuation,
            definition: "看单个用户/门店/订单赚不赚钱：互联网看 DAU、留存、获客成本；线下看坪效、翻台率。用错指标体系 = 暴露你不懂这门生意。",
            source: "增长与经营分析通识",
            relatedCardIDs: ["dau-fraud"]
        ),

        // MARK: Term Sheet 条款
        GlossaryEntry(
            id: "term-sheet", term: "投资意向书", english: "Term Sheet", category: .termSheet,
            definition: "投融资交易的条款清单：估值只是第一行，真正的博弈都在优先清算、防稀释、对赌这些「毒药条款」里。",
            source: "《风险投资交易》Brad Feld",
        ),
        GlossaryEntry(
            id: "liq-pref", term: "优先清算权", english: "Liquidation Preference", category: .termSheet,
            definition: "公司清算或出售时，投资人先按约定倍数（常见 1x）拿回本金，剩下的才轮到普通股。投资人保本的终极条款——谈判里等于一张随时可按保底价签约的底牌。",
            source: "《风险投资交易》Brad Feld",
            relatedCardIDs: ["liq-pref"]
        ),
        GlossaryEntry(
            id: "vam", term: "对赌协议", english: "VAM / Valuation Adjustment Mechanism", category: .termSheet,
            definition: "以未来业绩为条件的估值调整条款：达标则皆大欢喜，不达标则创始人赔股份甚至回购。能大幅拉升当期估值，但反噬极其致命——用它之前想清楚输得起吗。",
            source: "《风险投资交易》Brad Feld",
            relatedCardIDs: ["vam"]
        ),
        GlossaryEntry(
            id: "anti-dilution", term: "防稀释条款", english: "Anti-dilution", category: .termSheet,
            definition: "后续融资估值更低（down round）时，自动调整早期投资人的换股价格以保护其股比。加权平均是市场惯例，完全棘轮（full ratchet）是霸王条款。",
            source: "《风险投资交易》Brad Feld"
        ),
        GlossaryEntry(
            id: "drag-along", term: "领售权", english: "Drag-along", category: .termSheet,
            definition: "多数股东决定卖公司时，可强制少数股东按同等条件一起卖。防止小股东卡交易——也是创始人最容易忽视的失控点之一。",
            source: "《风险投资交易》Brad Feld"
        ),

        // MARK: 谈判战术
        GlossaryEntry(
            id: "anchoring", term: "锚定与虚假让步", english: "Anchoring", category: .negotiation,
            definition: "先抛一个极端锚点，再「痛苦地」让步到真实目标价——对方感知到的是你的让步，不是你的底价。配合校准型问题（『你们怎么得出这个数的？』）效果翻倍。",
            source: "《绝对谈判》Chris Voss",
            relatedCardIDs: ["fake-concession"]
        ),
        GlossaryEntry(
            id: "time-pressure", term: "时间压力战术", english: "Deadline Pressure", category: .negotiation,
            definition: "越接近截止时刻，对方的让步意愿越大——深夜、季度末、基金到期日都是发起总攻的窗口。前 FBI 谈判专家的看家本领。",
            source: "《绝对谈判》Chris Voss",
            relatedCardIDs: ["late-night"]
        ),
        GlossaryEntry(
            id: "tactical-empathy", term: "战术同理心", english: "Tactical Empathy", category: .negotiation,
            definition: "先标注对方的情绪（『听起来你担心的是控制权』），让对方觉得被理解，再引导其暴露底线。谈判不是说服，是让对方自己说服自己。",
            source: "《绝对谈判》Chris Voss"
        ),

        // MARK: 行业生态
        GlossaryEntry(
            id: "fa", term: "财务顾问", english: "FA / Financial Advisor", category: .ecosystem,
            definition: "撮合融资与并购交易的中间人：帮项目方找钱、帮资金方找项目，赚成交佣金（常见 2%–5%）。人脉、信息差与谈判力就是全部生产资料——也就是你在本营扮演的角色。",
            source: "行业通识"
        ),
        GlossaryEntry(
            id: "dd", term: "尽职调查", english: "Due Diligence", category: .ecosystem,
            definition: "交易前对目标公司业务、财务、法务的全面核查。查出的每一个瑕疵都是压价杠杆——尽调做得深，谈判桌上腰杆就硬。",
            source: "《投资银行》Rosenbaum & Pearl",
            relatedCardIDs: ["finance-hole"]
        ),
        GlossaryEntry(
            id: "angel-people", term: "天使轮投人", english: "Bet on People", category: .ecosystem,
            definition: "早期项目没有数据可看，投资决策的第一逻辑是团队：履历、组合、气场。这也是为什么天使轮路演一半时间在讲『我们是谁』。",
            source: "创投通识",
            relatedCardIDs: ["team-halo"]
        ),
        GlossaryEntry(
            id: "narrative", term: "叙事驱动融资", english: "Narrative-driven Fundraising", category: .ecosystem,
            definition: "用愿景故事拉高预期估值——对早期个人投资者有效，对看过一万份 BP 的机构基本免疫。故事要讲，但要配数据。",
            source: "创投通识",
            relatedCardIDs: ["ppt-vision"]
        ),
        GlossaryEntry(
            id: "lbo", term: "杠杆收购", english: "LBO / Leveraged Buyout", category: .ecosystem,
            definition: "用少量自有资金 + 大量债务收购公司，再用公司自身现金流还债。1988 年 RJR 纳贝斯克 250 亿美元世纪之战使其登峰造极——「门口的野蛮人」由此得名。",
            source: "《门口的野蛮人》Burrough & Helyar",
            relatedCardIDs: ["barbarians"]
        ),

        // MARK: 灰色资产（浮生记倒卖线——知道自己在买什么、坑在哪）
        GlossaryEntry(
            id: "asset-angel-stock", term: "天使轮原始股", english: "Pre-seed Equity", category: .greyAsset,
            definition: "未上市早期公司的股权份额。合规路径要走股转协议和工商变更；黑市上「原始股」三个字是骗局重灾区——绝大多数买家的下场是股权无法登记、公司蒸发。价格极低波动极大，正因为它可能一文不值。",
            source: "创投通识 · 反诈"
        ),
        GlossaryEntry(
            id: "asset-tail-round", term: "尾轮跟投份额", english: "Late-stage Co-invest Allocation", category: .greyAsset,
            definition: "Pre-IPO 前最后几轮的小额跟投额度，常由领投机构分销。看似稳赚，实则接盘位：估值已被前几轮推满，二级破发即亏损。判断关键是领投方是否真金加注。",
            source: "创投通识"
        ),
        GlossaryEntry(
            id: "asset-compute-voucher", term: "算力租赁券", english: "Compute Voucher", category: .greyAsset,
            definition: "预付的 GPU/云算力使用权凭证，AI 热潮中的硬通货。价格随模型军备竞赛暴涨、随云厂商降价暴跌——本质是对算力供需的杠杆敞口。",
            source: "行业观察"
        ),
        GlossaryEntry(
            id: "asset-traffic-pack", term: "刷量数据包", english: "Fake Traffic Bundle", category: .greyAsset,
            definition: "批量伪造的用户/流量数据，用于粉饰增长指标骗融资。卖它掉名声：尽调中被查出刷量，公司估值直接归零，FA 连带信誉扫地——这是创投圈的「伪劣化妆品」。",
            source: "尽调实务 · 反面教材"
        ),
        GlossaryEntry(
            id: "asset-usd-fund", term: "水货美元基金份额", english: "Grey-market USD Fund Share", category: .greyAsset,
            definition: "绕开外汇与合格投资者监管、私下转让的美元基金 LP 份额。收益挂钩汇率与基金业绩，但转让本身不受法律保护——出事时你甚至证明不了自己是 LP。",
            source: "跨境合规通识"
        ),
        GlossaryEntry(
            id: "asset-shell-license", term: "壳公司牌照", english: "Shell Company License", category: .greyAsset,
            definition: "有牌照/上市地位但无实际业务的公司壳。借壳上市回暖时价格翻番，监管严打时砸手里。识壳三看：或有负债、历史沿革、牌照续期风险。",
            source: "《企业方法》刘韧 · 并购实务"
        ),
        GlossaryEntry(
            id: "asset-pre-ipo", term: "突击入股额度", english: "Pre-IPO Placement Quota", category: .greyAsset,
            definition: "临近 IPO 突击入股的稀缺额度，黑市溢价惊人。监管明令限制上市前 12 个月新增股东——买它赌的是过会窗口，窗口一关就是烫手山芋，还可能把发行人一起拖下水。",
            source: "证券监管通识"
        ),
        GlossaryEntry(
            id: "asset-unicorn-stake", term: "独角兽老股", english: "Unicorn Secondary", category: .greyAsset,
            definition: "独角兽公司早期股东转让的存量股份（Secondary）。流动性差、信息不对称大：卖方永远比你懂公司。折价买入是常态，关键在拿到真实财务数据和优先清算条款全貌。",
            source: "《说谎者的扑克牌》Michael Lewis · 二级市场智慧"
        ),
    ]

    static func entry(id: String) -> GlossaryEntry? {
        all.first { $0.id == id }
    }

    static func entries(in category: GlossaryEntry.Category) -> [GlossaryEntry] {
        all.filter { $0.category == category }
    }
}
