import Foundation

/// 商业绝密档案：沙盘里程碑解锁的真实商业史图鉴（泛黄报纸观感在 UI 层）。
struct ArchiveEntry: Identifiable, Equatable, Sendable {
    let id: String
    let title: String
    let year: String
    /// 解锁条件：沙盘合成该数字。
    let milestone: Int
    let body: String
    let source: String
    /// 首次解锁附赠的传说卡。
    let rewardCardID: String?
}

enum ArchiveCatalog {
    static let all: [ArchiveEntry] = [
        ArchiveEntry(
            id: "liars-poker",
            title: "说谎者的扑克牌",
            year: "1986",
            milestone: 512,
            body: "所罗门兄弟的交易大厅里，CEO 约翰·古弗兰对首席交易员说：『一手牌，一百万美元，不许哭。』华尔街债券交易的黄金年代——贪婪、对赌与残酷淘汰，皆始于此。",
            source: "《说谎者的扑克牌》Michael Lewis",
            rewardCardID: "vam"
        ),
        ArchiveEntry(
            id: "rjr-nabisco",
            title: "门口的野蛮人",
            year: "1988",
            milestone: 1024,
            body: "RJR 纳贝斯克收购战：CEO 罗斯·约翰逊想以 75 美元/股私有化自己的公司，KKR 用垃圾债券撬动 250 亿美元应战，最终以 109 美元/股成交——史上最疯狂的杠杆收购，资本的冷血与疯狂一战封神。",
            source: "《门口的野蛮人》Burrough & Helyar",
            rewardCardID: "barbarians"
        ),
    ]

    static func entry(id: String) -> ArchiveEntry? { all.first { $0.id == id } }
    static func entry(milestone: Int) -> ArchiveEntry? { all.first { $0.milestone == milestone } }
}

/// 一次顿悟的产出（UI toast 与测试断言用）。
struct EpiphanyReward: Equatable {
    let milestone: Int
    let cardIDs: [String]
    let archiveID: String?
    let reputationBonus: Int
    let summary: String
}

/// 顿悟引擎：沙盘（2048）里程碑 → 掉卡入库 / 解锁档案 / 永久属性。
/// 沙盘模块零依赖 Rainmaker——由 UI 层把里程碑值转发进来。
enum EpiphanyEngine {
    /// 合成 2048（完美 DCF 演算）的永久信誉奖励。
    static let masterReputationBonus = 5

    /// 各里程碑的固定掉卡；128 与复访档案里程碑掉随机新手卡。
    private static let fixedDrops: [Int: String] = [256: "finance-hole"]
    private static let milestones: Set<Int> = [128, 256, 512, 1024, 2048]

    @discardableResult
    static func recordMilestone(
        _ value: Int, state: inout RainmakerState,
        using rng: inout some RandomNumberGenerator, now: Date
    ) -> EpiphanyReward? {
        guard milestones.contains(value) else { return nil }

        var cardIDs: [String] = []
        var archiveID: String?
        var reputationBonus = 0
        var summaryParts: [String] = []

        if value == 2048 {
            reputationBonus = masterReputationBonus
            state.reputation += reputationBonus
            summaryParts.append("完成一次完美的 DCF 现金流折现演算，圈内声望大涨：信誉 +\(reputationBonus)。")
        } else if let entry = ArchiveCatalog.entry(milestone: value),
                  !(state.unlockedArchives ?? []).contains(entry.id) {
            // 档案首次解锁 + 附赠传说/强力卡
            state.unlockedArchives = (state.unlockedArchives ?? []) + [entry.id]
            archiveID = entry.id
            summaryParts.append("解锁商业绝密档案《\(entry.title)》（\(entry.year)）。")
            if let reward = entry.rewardCardID {
                cardIDs.append(reward)
            }
        } else {
            // 普通掉卡 / 复访档案里程碑
            let drop = fixedDrops[value] ?? CardCatalog.rookiePool.randomElement(using: &rng)!.id
            cardIDs.append(drop)
        }

        // 入库（容量封顶，放不下的丢弃）
        var inventory = state.cardInventory ?? []
        var stored: [String] = []
        for id in cardIDs where inventory.count < RainmakerBalance.cardInventoryCap {
            inventory.append(id)
            stored.append(id)
        }
        if !cardIDs.isEmpty {
            state.cardInventory = inventory
        }
        if !stored.isEmpty {
            let names = stored.compactMap { CardCatalog.card(id: $0)?.name }.map { "【\($0)】" }.joined()
            summaryParts.append("话术\(names)已入库，下场谈判自动带上。")
        } else if !cardIDs.isEmpty {
            summaryParts.append("卡库已满（\(RainmakerBalance.cardInventoryCap) 张），这次的灵感只能作罢。")
        }

        let summary = "💡 顿悟 · 合成 \(value)：" + summaryParts.joined(separator: " ")
        RainmakerEngine.append(
            .systemNotice(id: RainmakerEngine.uuid(using: &rng), text: summary, at: now),
            to: RainmakerEngine.assistantNPCID, in: &state
        )
        return EpiphanyReward(
            milestone: value, cardIDs: stored, archiveID: archiveID,
            reputationBonus: reputationBonus, summary: summary
        )
    }
}
