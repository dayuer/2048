import XCTest
@testable import Game2048

/// 谈判桌台词的生成式覆盖：Store 包装层给引擎新增的 npcText 打场景标签，
/// 投递时按标签选提示词板块；真相层台词与算分全程不动。
@MainActor
final class NegotiationChatSceneTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("nego-chat-test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    /// 拉起一场谈判：返回 (store, npcID)。开局必有 offered 项目单。
    private func makeStoreInNegotiation() -> (RainmakerStore, String) {
        let store = RainmakerStore(fileURL: fileURL)
        guard let deal = store.state.deals.first(where: { $0.status == .offered }) else {
            XCTFail("开局应有项目单")
            fatalError()
        }
        XCTAssertTrue(store.startNegotiation(dealID: deal.id))
        return (store, deal.npcID)
    }

    func testOpenLineIsTaggedAndEnrichedWithNegotiationIntent() async {
        let (store, npcID) = makeStoreInNegotiation()
        store.personaChat = MockPersonaChatClient()
        await store.awaitDelivery(npcID: npcID)

        let last = store.visibleEvents(npcID: npcID).last!
        XCTAssertTrue(
            store.displayText(for: last).contains("·谈判】应战"),
            "谈判开场白应走 negotiationOpen 场景，实际：\(store.displayText(for: last))"
        )
    }

    func testPlayedCardLineCarriesSceneAndCardContext() async {
        let (store, npcID) = makeStoreInNegotiation()
        store.personaChat = MockPersonaChatClient()

        guard let cardID = store.state.activeNegotiation?.hand.first,
              let outcome = store.play(cardID: cardID) else {
            return XCTFail("手牌应可打出")
        }
        await store.awaitDelivery(npcID: npcID)

        let texts = store.visibleEvents(npcID: npcID).map { store.displayText(for: $0) }
        if outcome.invalid {
            XCTAssertTrue(texts.contains { $0.contains("·谈判】嘲讽") }, "无效牌 → taunt 场景")
        } else {
            XCTAssertTrue(texts.contains { $0.contains("·谈判】被【") }, "有效命中 → hurt 场景 + 牌名")
        }
    }

    func testTruthLayerStaysDeterministicUnderEnrichment() async {
        let (store, npcID) = makeStoreInNegotiation()
        store.personaChat = MockPersonaChatClient()
        await store.awaitDelivery(npcID: npcID)

        // 真相层：开场白仍是台词池/共享默认，不被 LLM 污染
        guard case let .npcText(_, truthText, _) = store.state.threads
            .first(where: { $0.id == npcID })!.events.last! else {
            return XCTFail("最后一条应是 NPC 应战台词")
        }
        let scriptOpen = NPCCatalog.profile(id: npcID)?.negotiationScript.open
        XCTAssertTrue(
            truthText == scriptOpen || truthText == "可以谈，但我的底线在那儿摆着。",
            "真相层必须来自确定性脚本"
        )
    }

    func testRestartClearsSceneTags() {
        let (store, _) = makeStoreInNegotiation()
        XCTAssertFalse(store.negotiationSceneTags.isEmpty, "开场应已打标")
        store.restart()
        XCTAssertTrue(store.negotiationSceneTags.isEmpty, "重开局要清场景标签")
    }
}
