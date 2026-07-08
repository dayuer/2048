import XCTest
@testable import Game2048

/// 顿悟系统（Phase 3）：沙盘里程碑 → 掉话术卡入库 / 解锁商业绝密档案 / 永久属性。
/// 卡库在下一场谈判开局时消耗（一次性），档案全局只解锁一次。
final class EpiphanyTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 0)

    private func newRun(seed: UInt64 = 7) -> RainmakerState {
        var rng = SeededGenerator(seed: seed)
        return RainmakerEngine.newRun(using: &rng, now: day0)
    }

    // MARK: - 掉落规则

    func testMilestone128DropsOneCard() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        let reward = EpiphanyEngine.recordMilestone(128, state: &state, using: &rng, now: day0)

        XCTAssertEqual(reward?.cardIDs.count, 1)
        XCTAssertEqual(state.cardInventory ?? [], reward?.cardIDs ?? [])
        XCTAssertNotNil(CardCatalog.card(id: reward!.cardIDs[0]), "掉的必须是真卡")
    }

    func testUnknownMilestoneGivesNothing() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        XCTAssertNil(EpiphanyEngine.recordMilestone(64, state: &state, using: &rng, now: day0))
        XCTAssertNil(state.cardInventory)
    }

    func testMilestone1024UnlocksArchiveWithLegendaryOnce() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)

        let first = EpiphanyEngine.recordMilestone(1024, state: &state, using: &rng, now: day0)
        XCTAssertEqual(first?.archiveID, "rjr-nabisco")
        XCTAssertEqual(first?.cardIDs, ["barbarians"], "档案首解锁附赠传说卡")
        XCTAssertEqual(state.unlockedArchives ?? [], ["rjr-nabisco"])

        let second = EpiphanyEngine.recordMilestone(1024, state: &state, using: &rng, now: day0)
        XCTAssertNil(second?.archiveID, "档案不重复解锁")
        XCTAssertEqual(second?.cardIDs.count, 1, "复访里程碑退化为普通掉卡")
        XCTAssertEqual(state.unlockedArchives?.count, 1)
    }

    func testMilestone2048GrantsPermanentReputation() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        let repBefore = state.reputation

        let reward = EpiphanyEngine.recordMilestone(2048, state: &state, using: &rng, now: day0)

        XCTAssertEqual(reward?.reputationBonus, EpiphanyEngine.masterReputationBonus)
        XCTAssertEqual(state.reputation, repBefore + EpiphanyEngine.masterReputationBonus)
    }

    func testInventoryCapEnforced() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        for _ in 0..<10 {
            _ = EpiphanyEngine.recordMilestone(128, state: &state, using: &rng, now: day0)
        }
        XCTAssertEqual(state.cardInventory?.count, RainmakerBalance.cardInventoryCap)
    }

    func testEpiphanyLeavesNoticeInAssistantThread() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        let before = state.threads.first { $0.id == RainmakerEngine.assistantNPCID }?.events.count ?? 0
        _ = EpiphanyEngine.recordMilestone(128, state: &state, using: &rng, now: day0)
        let after = state.threads.first { $0.id == RainmakerEngine.assistantNPCID }?.events.count ?? 0
        XCTAssertGreaterThan(after, before, "顿悟要在助理线程留痕（聊天即界面）")
    }

    // MARK: - 卡库 → 谈判手牌

    func testNegotiationStartConsumesInventoryIntoHand() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        state.cardInventory = ["barbarians", "vam", "late-night"]
        guard let deal = state.deals.first(where: { $0.status == .offered }) else {
            return XCTFail("开局应有项目")
        }

        XCTAssertTrue(NegotiationEngine.start(dealID: deal.id, state: &state, using: &rng, now: day0))

        let hand = state.activeNegotiation?.hand ?? []
        XCTAssertEqual(
            hand.count,
            RainmakerBalance.handSize + RainmakerBalance.inventoryHandBonus,
            "手牌 = 常规抓牌 + 最多 \(RainmakerBalance.inventoryHandBonus) 张库存卡"
        )
        XCTAssertTrue(hand.contains("barbarians"))
        XCTAssertTrue(hand.contains("vam"))
        XCTAssertEqual(state.cardInventory, ["late-night"], "带走的库存卡即时消耗")
    }

    func testLegendaryCardResolvesInCatalogAndGlossary() {
        guard let card = CardCatalog.card(id: "barbarians") else {
            return XCTFail("传说卡【野蛮人敲门】必须可查")
        }
        XCTAssertNotNil(Glossary.entry(id: card.glossaryID))
    }

    // MARK: - 沙盘侧里程碑探测

    func testMilestoneDetectionFromResolution() {
        var resolution = Resolution<Int>()
        var beat = Beat<Int>()
        beat.transforms.append(Transform(consumed: [UUID(), UUID()], produced: UUID(),
                                         at: Coord(row: 0, col: 0), payload: 128))
        beat.transforms.append(Transform(consumed: [UUID(), UUID()], produced: UUID(),
                                         at: Coord(row: 1, col: 0), payload: 8))
        resolution.beats.append(beat)

        XCTAssertEqual(GameViewModel.newMilestones(in: resolution, reached: []), [128])
        XCTAssertEqual(GameViewModel.newMilestones(in: resolution, reached: [128]), [], "单局内不重复触发")
    }

    // MARK: - 存档

    func testInventoryAndArchivesSurviveCodable() throws {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        _ = EpiphanyEngine.recordMilestone(1024, state: &state, using: &rng, now: day0)
        let decoded = try JSONDecoder().decode(RainmakerState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded, state)
    }
}
