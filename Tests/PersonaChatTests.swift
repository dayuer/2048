import XCTest
@testable import Game2048

/// 生成式对话拟真层：显示层覆盖真相层，失败回退台词池，未接入等于现状。
/// 真实投递路径（非 instantDelivery）才会触发增强——这里专测那条路径。
@MainActor
final class PersonaChatTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("persona-chat-test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    /// 抛错的桩：模拟断网/服务端异常。
    private struct FailingChatClient: PersonaChatClient {
        func reply(for request: PersonaChatRequest) async throws -> String {
            throw URLError(.notConnectedToInternet)
        }
    }

    // MARK: - 覆盖显示 + 真相层不变

    func testMockClientOverridesDisplayTextWhileTruthStaysPool() async {
        let store = RainmakerStore(fileURL: fileURL)
        store.personaChat = MockPersonaChatClient()   // 非 instant：走真实投递
        store.sendMessage("你好", to: "chen")
        await store.awaitDelivery(npcID: "chen")

        let events = store.state.threads.first { $0.id == "chen" }?.events ?? []
        guard case let .npcText(_, truthText, _) = events.last else {
            return XCTFail("最后一条应是 NPC 回复")
        }
        // 真相层仍是确定性台词池
        XCTAssertTrue(
            NPCCatalog.profile(id: "chen")!.smallTalk.contains(truthText),
            "真相层文本必须来自台词池，未被 LLM 污染"
        )
        // 显示层被 mock 覆盖（intent=reply 分支）
        XCTAssertEqual(store.displayText(for: events.last!), "【陈总·人设】收到：你好")
        XCTAssertNotEqual(store.displayText(for: events.last!), truthText)
        // 全部已送达
        XCTAssertEqual(store.visibleEvents(npcID: "chen").count, events.count)
    }

    // MARK: - 请求契约：意图与人设都组进去了

    func testRequestCarriesReplyIntentAndPersona() async {
        let store = RainmakerStore(fileURL: fileURL)
        store.personaChat = MockPersonaChatClient { req in
            "intent=\(req.intent.rawValue)|player=\(req.playerMessage ?? "-")|voice=\(req.npc.persona.voice.isEmpty ? "no" : "yes")"
        }
        store.sendMessage("这单佣金必须到位", to: "chen")
        await store.awaitDelivery(npcID: "chen")

        let shown = store.displayText(for: store.visibleEvents(npcID: "chen").last!)
        XCTAssertTrue(shown.contains("intent=reply"), "回应玩家 → intent=reply")
        XCTAssertTrue(shown.contains("player=这单佣金必须到位"), "带上玩家原话")
        XCTAssertTrue(shown.contains("voice=yes"), "人设声线组进请求")
    }

    // MARK: - 失败回退

    func testFailingClientFallsBackToPoolText() async {
        let store = RainmakerStore(fileURL: fileURL)
        store.personaChat = FailingChatClient()
        store.sendMessage("在吗", to: "chen")
        await store.awaitDelivery(npcID: "chen")

        let last = store.visibleEvents(npcID: "chen").last!
        guard case let .npcText(id, truthText, _) = last else {
            return XCTFail("最后一条应是 NPC 回复")
        }
        XCTAssertEqual(store.displayText(for: last), truthText, "生成失败 → 回退台词池原文")
        XCTAssertNil(store.generatedText[id], "失败不应写入覆盖")
    }

    // MARK: - assistant 线程不增强

    func testAssistantThreadIsNotEnriched() async {
        let store = RainmakerStore(fileURL: fileURL)
        store.personaChat = MockPersonaChatClient()
        let assistantID = RainmakerEngine.assistantNPCID
        store.sendMessage("今天几个单子", to: assistantID)
        await store.awaitDelivery(npcID: assistantID)

        let last = store.visibleEvents(npcID: assistantID).last!
        XCTAssertFalse(
            store.displayText(for: last).contains("人设"),
            "小何（助理）线程走确定性，不接生成式"
        )
    }

    // MARK: - 未接入 = 现状

    func testNilClientLeavesDisplayTextEqualToTruth() {
        let store = RainmakerStore(fileURL: fileURL)
        store.instantDelivery = true            // 默认 personaChat == nil
        store.sendMessage("你好", to: "chen")

        for event in store.visibleEvents(npcID: "chen") {
            switch event {
            case let .npcText(_, text, _), let .playerText(_, text, _), let .systemNotice(_, text, _):
                XCTAssertEqual(store.displayText(for: event), text, "未接入时显示层等于真相层")
            case .dealOffer:
                break
            }
        }
        XCTAssertTrue(store.generatedText.isEmpty, "未接入不产生任何覆盖")
    }
}
