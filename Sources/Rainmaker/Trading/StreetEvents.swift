import Foundation

/// 市场新闻事件：驱动资产价格暴涨暴跌/白给货（原版 gameMessages 18 条全量移植）。
/// freq 为**反频率**（原版 `rand(950) % freq == 0`，越小越常见）；同日可多发。
struct MarketNews: Equatable, Sendable {
    enum Effect: Equatable, Sendable {
        case surge(Int)                   // 价格 × n
        case crash(Int)                   // 价格 ÷ n
        case gift(Int)                    // 白给 n 手（受托管容量 clamp）
        case debtGift(Int, debtCost: Int) // 村长硬卖：白给 n 手 + 记账加债
    }

    let freq: Int
    let assetID: String
    let headline: String
    let effect: Effect
}

/// 街头人身事件（原版 random_event 12 条 + random_steal_event 7 条全量移植）。
/// 伤身/敲诈各自每日至多一件（原版 break 语义）。sound 为原版 wav 名，接 SoundPlayer。
struct StreetIncident: Equatable, Sendable {
    enum Effect: Equatable, Sendable {
        case healthDamage(Int)       // 伤身 n 点
        case cashLossPercent(Int)    // 现金 × (1 - n/100)
    }

    let freq: Int
    let text: String
    let effect: Effect
    let sound: String?
}

/// 静态事件目录：文案保留原版「俺」味，仅商品名创投化（资产映射与价格区间一一对应原版）。
/// 原版对照：香烟→尾轮跟投 / 汽车→独角兽老股 / VCD→天使轮原始股 / 白酒→壳公司牌照 /
/// 小宝贝→突击入股额度 / 玩具→算力租赁券 / 手机→水货美元基金 / 化妆品→刷量数据包
enum StreetEventCatalog {
    // MARK: 市场新闻（原版 gameMessages，freq/倍率逐条对齐）

    static let newsPool: [MarketNews] = [
        MarketNews(freq: 170, assetID: "compute-voucher",
                   headline: "专家提议提高大学生「动手素质」，算力租赁券颇受欢迎!", effect: .surge(2)),
        MarketNews(freq: 139, assetID: "shell-license",
                   headline: "有人自豪地说：上市不用排队审核，借壳就可以!", effect: .surge(3)),
        MarketNews(freq: 100, assetID: "pre-ipo",
                   headline: "机构的秘密报告：「突击入股回报甚过对冲基金」!", effect: .surge(5)),
        MarketNews(freq: 41, assetID: "angel-stock",
                   headline: "大V说：「2026年诺贝尔经济学奖？呸！不如天使轮原始股。」", effect: .surge(4)),
        MarketNews(freq: 37, assetID: "unicorn-stake",
                   headline: "《北京经济小报》社论：「老股流转大力推进创投消费!」", effect: .surge(3)),
        MarketNews(freq: 23, assetID: "traffic-pack",
                   headline: "《北京真理报》社论：「提倡增长，落到实处」，刷量数据包大受欢迎!", effect: .surge(4)),
        MarketNews(freq: 37, assetID: "pre-ipo",
                   headline: "持牌交易所都不敢挂的额度，黑市一份可卖天价!", effect: .surge(8)),
        MarketNews(freq: 15, assetID: "traffic-pack",
                   headline: "顶流在晚会上说：「我酷!我买量!」，刷量数据包供不应求!", effect: .surge(7)),
        MarketNews(freq: 40, assetID: "shell-license",
                   headline: "北京有人疯狂囤壳，壳公司牌照可以卖出天价!", effect: .surge(7)),
        MarketNews(freq: 29, assetID: "usd-fund",
                   headline: "北京的大学生们开始留学潮，水货美元基金大受欢迎！!", effect: .surge(7)),
        MarketNews(freq: 35, assetID: "unicorn-stake",
                   headline: "北京的富人疯狂地购买独角兽老股！价格狂升!", effect: .surge(8)),
        MarketNews(freq: 17, assetID: "tail-round",
                   headline: "市场上充斥着来路不明的尾轮跟投份额!", effect: .crash(8)),
        MarketNews(freq: 24, assetID: "compute-voucher",
                   headline: "云厂商集体大降价，算力租赁券没人愿意买。", effect: .crash(5)),
        MarketNews(freq: 18, assetID: "angel-stock",
                   headline: "原始股骗局曝光，「中国硅谷」——中关村全是抛售的散户!", effect: .crash(8)),
        MarketNews(freq: 160, assetID: "unicorn-stake",
                   headline: "厦门的老同学资助俺两手独角兽老股！发了！！", effect: .gift(2)),
        MarketNews(freq: 45, assetID: "tail-round",
                   headline: "专项检查扫荡后，俺在黑暗角落里发现了老乡丢失的尾轮份额。", effect: .gift(6)),
        MarketNews(freq: 35, assetID: "shell-license",
                   headline: "俺老乡回家前把几张壳公司牌照给俺!", effect: .gift(4)),
        MarketNews(freq: 140, assetID: "usd-fund",
                   headline: "村长得知美元基金出事的消息，托人把他手里的水货份额硬卖给您，记账 2500 万。",
                   effect: .debtGift(1, debtCost: 2500)),
    ]

    // MARK: 街头事件（原版 random_event 伤身 12 条，音效名对齐原版 wav）

    static let healthIncidents: [StreetIncident] = [
        StreetIncident(freq: 117, text: "大街上两个流氓打了俺!", effect: .healthDamage(3), sound: "kill"),
        StreetIncident(freq: 157, text: "俺在过街地道被人打了蒙棍!", effect: .healthDamage(20), sound: "death"),
        StreetIncident(freq: 21, text: "检查组的追俺超过三个胡同。", effect: .healthDamage(1), sound: "dog"),
        StreetIncident(freq: 100, text: "北京拥挤的交通让俺心焦!", effect: .healthDamage(1), sound: "harley"),
        StreetIncident(freq: 35, text: "开小巴的打俺一耳光!", effect: .healthDamage(1), sound: "hit"),
        StreetIncident(freq: 313, text: "一群被爆雷项目坑过的维权群众打了俺!", effect: .healthDamage(10), sound: "flee"),
        StreetIncident(freq: 120, text: "附近胡同的一个小青年砸俺一砖头!", effect: .healthDamage(5), sound: "death"),
        StreetIncident(freq: 29, text: "附近写字楼一个假保安用电棍电击俺!", effect: .healthDamage(3), sound: "el"),
        StreetIncident(freq: 43, text: "北京臭黑的小河熏着我了!", effect: .healthDamage(1), sound: "vomit"),
        StreetIncident(freq: 45, text: "守自行车的王大婶嘲笑俺没北京户口!", effect: .healthDamage(1), sound: "level"),
        StreetIncident(freq: 48, text: "北京高温40度!俺热...", effect: .healthDamage(1), sound: "lan"),
        StreetIncident(freq: 33, text: "申奥添了新风景，北京又来沙尘暴!", effect: .healthDamage(1), sound: "breath"),
    ]

    // MARK: 街头事件（原版 random_steal_event 敲诈 7 条，比例对齐）

    static let stealIncidents: [StreetIncident] = [
        StreetIncident(freq: 60, text: "俺怜悯地铁口扮演成乞丐的老太太。", effect: .cashLossPercent(10), sound: nil),
        StreetIncident(freq: 125, text: "一个汉子在街头拦住俺：「哥们，给点钱用!」。", effect: .cashLossPercent(10), sound: nil),
        StreetIncident(freq: 100, text: "一个大个子碰了俺一下，说：「别挤了!」。", effect: .cashLossPercent(40), sound: nil),
        StreetIncident(freq: 65, text: "三个带红袖章的老太太揪住俺：「你是外地人?罚款!」", effect: .cashLossPercent(20), sound: nil),
        StreetIncident(freq: 35, text: "两个猛男揪住俺：「交尽调费、通道费。」", effect: .cashLossPercent(15), sound: nil),
        StreetIncident(freq: 27, text: "副主任说：「办牌照?晚上不要去我家给我送钱哦。」", effect: .cashLossPercent(10), sound: nil),
        StreetIncident(freq: 40, text: "北京空气污染得厉害,俺去氧吧吸氧...", effect: .cashLossPercent(5), sound: nil),
    ]

    /// 原版触发判定：`RandomNum(bound) % freq == 0`。
    static func fires(freq: Int, bound: Int, using rng: inout some RandomNumberGenerator) -> Bool {
        Int(rng.next() % UInt64(bound)) % freq == 0
    }
}
