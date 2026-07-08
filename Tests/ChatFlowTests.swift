import XCTest
@testable import Game2048

/// 聊天流（WhatsApp 式收发）：发消息→NPC 台词池回复；未读计数；已读标记。
/// 投递节奏（正在输入…）是 Store 的表现层，真相层在这里保持同步确定性。
final class ChatFlowTests: XCTestCase {
    private let day0 = Date(timeIntervalSince1970: 0)

    private func newRun(seed: UInt64 = 7) -> RainmakerState {
        var rng = SeededGenerator(seed: seed)
        return RainmakerEngine.newRun(using: &rng, now: day0)
    }

    // MARK: - 收发消息

    func testSendMessageAppendsPlayerTextAndReply() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        let countBefore = state.threads.first { $0.id == "chen" }?.events.count ?? 0

        RainmakerEngine.sendMessage("陈总最近怎么样？", to: "chen", state: &state, using: &rng, now: day0)

        let events = state.threads.first { $0.id == "chen" }?.events ?? []
        XCTAssertEqual(events.count, countBefore + 2, "我方一条 + NPC 回复一条")
        guard case let .playerText(_, text, _) = events[events.count - 2] else {
            return XCTFail("倒数第二条应是我方消息")
        }
        XCTAssertEqual(text, "陈总最近怎么样？")
        guard case let .npcText(_, reply, _) = events[events.count - 1] else {
            return XCTFail("最后一条应是 NPC 回复")
        }
        XCTAssertFalse(reply.isEmpty)
    }

    func testSendMessageIgnoresBlankText() {
        var state = newRun()
        var rng = SeededGenerator(seed: 1)
        let before = state.threads.first { $0.id == "chen" }?.events.count ?? 0

        RainmakerEngine.sendMessage("   ", to: "chen", state: &state, using: &rng, now: day0)

        XCTAssertEqual(state.threads.first { $0.id == "chen" }?.events.count, before)
    }

    func testEveryNPCHasSmallTalkPool() {
        for npc in NPCCatalog.contacts + [NPCCatalog.assistant] {
            XCTAssertFalse(npc.smallTalk.isEmpty, "\(npc.name) 缺闲聊台词池")
        }
    }

    func testSendMessageIsDeterministicWithSeed() {
        var a = newRun(seed: 42)
        var b = newRun(seed: 42)
        var rngA = SeededGenerator(seed: 9)
        var rngB = SeededGenerator(seed: 9)
        RainmakerEngine.sendMessage("聊聊", to: "ma", state: &a, using: &rngA, now: day0)
        RainmakerEngine.sendMessage("聊聊", to: "ma", state: &b, using: &rngB, now: day0)
        XCTAssertEqual(a, b)
    }

    // MARK: - 未读

    func testUnreadCountGrowsWithIncomingAndClearsOnMarkRead() {
        var state = newRun()
        // 开局所有线程未读（还没点开过）
        let npcID = state.threads.first { $0.id != RainmakerEngine.assistantNPCID }!.id
        XCTAssertGreaterThan(state.unreadCount(npcID: npcID), 0)

        state.markRead(npcID: npcID)
        XCTAssertEqual(state.unreadCount(npcID: npcID), 0)

        // 新的一天来消息 → 未读回升
        var rng = SeededGenerator(seed: 1)
        RainmakerEngine.endDay(state: &state, using: &rng, now: day0)
        let anyUnread = state.threads.contains { state.unreadCount(npcID: $0.id) > 0 }
        XCTAssertTrue(anyUnread, "结算与新项目消息应产生未读")
    }

    func testOwnMessagesDoNotCountAsUnread() {
        var state = newRun()
        state.markRead(npcID: "chen")
        var rng = SeededGenerator(seed: 1)
        RainmakerEngine.sendMessage("在吗", to: "chen", state: &state, using: &rng, now: day0)
        // 自己发的不算未读；NPC 回复算 1 条
        XCTAssertEqual(state.unreadCount(npcID: "chen"), 1)
    }

    func testReadStateSurvivesCodableRoundTrip() throws {
        var state = newRun()
        state.markRead(npcID: "chen")
        let decoded = try JSONDecoder().decode(RainmakerState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(decoded.unreadCount(npcID: "chen"), state.unreadCount(npcID: "chen"))
        XCTAssertEqual(decoded, state)
    }
}
