import Foundation

/// 可倒卖的灰色创投资产。基准价对齐北京浮生记原版商品（单位：万/手）。
/// 每种资产挂一个 Glossary 词条——倒卖即训练（知道自己在买什么、坑在哪）。
struct TradeAsset: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// 每日价格区间（基准 ±50%，事件另乘倍率）。
    let priceRange: ClosedRange<Int>
    /// 涉灰资产：卖出掉信誉，可能被「查水表」没收。
    let isGrey: Bool
    /// 创投百科词条 id（训练点）。
    let glossaryID: String

    var basePrice: Int { (priceRange.lowerBound + priceRange.upperBound) / 2 }
}

/// 交易城市（对标原版地铁口黑市，格局放大到全球金融环线）。
/// 每座城市一位驻场贩子、一套当日行情；飞一座城市 = 一天。
struct TradeVenue: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// 驻场贩子 NPC id。
    let dealerID: String
    let icon: String
    /// 城市定位一句话（跑市场选择器里展示，把视野讲出来）。
    let tagline: String
    /// 特产资产：该城永不缺货且报产地价（偏区间下沿）——全球倒卖环线的骨架。
    let specialties: [String]
}

/// 静态交易目录：资产 × 圈子。数值锚定浮生记原版（VCD 50 → 汽车 20000）。
enum TradeCatalog {
    // MARK: 资产（8 种，创投化翻译）

    /// 价格区间逐条对齐原版 makeDrugPrices（元→万，数值不变）。
    static let assets: [TradeAsset] = [
        TradeAsset(id: "angel-stock", name: "天使轮原始股", priceRange: 5...55,
                   isGrey: true, glossaryID: "asset-angel-stock"),           // 盗版VCD 5+rand(50)
        TradeAsset(id: "traffic-pack", name: "刷量数据包", priceRange: 65...245,
                   isGrey: true, glossaryID: "asset-traffic-pack"),          // 伪劣化妆品 65+rand(180)
        TradeAsset(id: "tail-round", name: "尾轮跟投份额", priceRange: 100...450,
                   isGrey: false, glossaryID: "asset-tail-round"),           // 进口香烟 100+rand(350)
        TradeAsset(id: "compute-voucher", name: "算力租赁券", priceRange: 250...850,
                   isGrey: false, glossaryID: "asset-compute-voucher"),      // 进口玩具 250+rand(600)
        TradeAsset(id: "usd-fund", name: "水货美元基金份额", priceRange: 750...1500,
                   isGrey: false, glossaryID: "asset-usd-fund"),             // 水货手机 750+rand(750)
        TradeAsset(id: "shell-license", name: "壳公司牌照", priceRange: 1000...3500,
                   isGrey: true, glossaryID: "asset-shell-license"),         // 假白酒 1000+rand(2500)
        TradeAsset(id: "pre-ipo", name: "突击入股额度", priceRange: 5000...14000,
                   isGrey: true, glossaryID: "asset-pre-ipo"),               // 上海小宝贝 5000+rand(9000)
        TradeAsset(id: "unicorn-stake", name: "独角兽老股", priceRange: 15000...30000,
                   isGrey: false, glossaryID: "asset-unicorn-stake"),        // 进口汽车 15000+rand(15000)
    ]

    // MARK: 城市（全球金融环线：国内跑项目 → 港美上市 → 新迪苏伦管钱）

    static let venues: [TradeVenue] = [
        TradeVenue(id: "bj", name: "北京", dealerID: "dealer-bj", icon: "building.columns",
                   tagline: "政策与人脉的中心，一切故事的起点",
                   specialties: ["angel-stock"]),
        TradeVenue(id: "sh", name: "上海", dealerID: "dealer-sh", icon: "chart.line.uptrend.xyaxis",
                   tagline: "陆家嘴与科创板，境内机构的钱最讲规矩",
                   specialties: ["tail-round"]),
        TradeVenue(id: "sz", name: "深圳", dealerID: "dealer-sz", icon: "cpu",
                   tagline: "硬科技供应链前线，快鱼吃慢鱼",
                   specialties: ["compute-voucher", "traffic-pack"]),
        TradeVenue(id: "hk", name: "香港", dealerID: "dealer-hk", icon: "dollarsign.circle",
                   tagline: "港股上市窗口，亚洲资本的门户",
                   specialties: ["pre-ipo"]),
        TradeVenue(id: "sg", name: "新加坡", dealerID: "dealer-sg", icon: "leaf",
                   tagline: "家族办公室之都，老钱在这里安家",
                   specialties: ["usd-fund"]),
        TradeVenue(id: "jp", name: "东京", dealerID: "dealer-jp", icon: "yensign.circle",
                   tagline: "低息日元与商社资本，套利者的天堂",
                   specialties: ["compute-voucher"]),
        TradeVenue(id: "du", name: "迪拜", dealerID: "dealer-du", icon: "sun.max",
                   tagline: "石油美元与主权基金，钱不问来路",
                   specialties: ["shell-license"]),
        TradeVenue(id: "zh", name: "苏黎世", dealerID: "dealer-zh", icon: "lock.shield",
                   tagline: "私人银行的保密传统，避险资金的终点",
                   specialties: ["usd-fund"]),
        TradeVenue(id: "ld", name: "伦敦", dealerID: "dealer-ld", icon: "building.2.crop.circle",
                   tagline: "金融城老钱与家族信托，一切大宗的定价地",
                   specialties: ["unicorn-stake"]),
        TradeVenue(id: "us", name: "纽约", dealerID: "dealer-us", icon: "globe.americas",
                   tagline: "华尔街终局：美股 IPO、对冲基金、block trade",
                   specialties: ["unicorn-stake", "pre-ipo"]),
    ]

    /// 开局所在城市。
    static let startVenueID = "bj"

    static func asset(id: String) -> TradeAsset? { assets.first { $0.id == id } }
    static func venue(id: String) -> TradeVenue? { venues.first { $0.id == id } }
    static func venueOfDealer(_ dealerID: String) -> TradeVenue? { venues.first { $0.dealerID == dealerID } }
}
