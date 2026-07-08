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

/// 北京创投圈子（对标原版地铁口黑市）。每个圈子一位驻场贩子、一套当日行情。
struct TradeVenue: Identifiable, Equatable, Sendable {
    let id: String
    let name: String
    /// 驻场贩子 NPC id。
    let dealerID: String
    let icon: String
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

    // MARK: 圈子（8 个北京创投据点）

    static let venues: [TradeVenue] = [
        TradeVenue(id: "zgc", name: "中关村", dealerID: "dealer-zgc", icon: "cpu"),
        TradeVenue(id: "jrj", name: "金融街", dealerID: "dealer-jrj", icon: "building.columns"),
        TradeVenue(id: "gm", name: "国贸", dealerID: "dealer-gm", icon: "building.2.crop.circle"),
        TradeVenue(id: "wj", name: "望京", dealerID: "dealer-wj", icon: "globe.asia.australia"),
        TradeVenue(id: "wdk", name: "五道口", dealerID: "dealer-wdk", icon: "graduationcap"),
        TradeVenue(id: "hcc", name: "后厂村", dealerID: "dealer-hcc", icon: "laptopcomputer.and.iphone"),
        TradeVenue(id: "yz", name: "亦庄", dealerID: "dealer-yz", icon: "gearshape.2"),
        TradeVenue(id: "slt", name: "三里屯", dealerID: "dealer-slt", icon: "wineglass"),
    ]

    /// 开局所在圈子。
    static let startVenueID = "zgc"

    static func asset(id: String) -> TradeAsset? { assets.first { $0.id == id } }
    static func venue(id: String) -> TradeVenue? { venues.first { $0.id == id } }
    static func venueOfDealer(_ dealerID: String) -> TradeVenue? { venues.first { $0.dealerID == dealerID } }
}
