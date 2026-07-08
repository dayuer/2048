import XCTest
@testable import Game2048

/// RainmakerStore：单档 JSON 持久化 + UI 单一真相源。
@MainActor
final class RainmakerStoreTests: XCTestCase {
    private var fileURL: URL!

    override func setUp() {
        super.setUp()
        fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("rainmaker-test-\(UUID().uuidString).json")
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: fileURL)
        super.tearDown()
    }

    func testFreshStoreStartsNewRun() {
        let store = RainmakerStore(fileURL: fileURL)
        XCTAssertEqual(store.state.day, 1)
        XCTAssertFalse(store.state.isGameOver)
        XCTAssertFalse(store.state.deals.isEmpty)
    }

    func testStatePersistsAcrossReload() {
        let store = RainmakerStore(fileURL: fileURL)
        guard let deal = store.state.deals.first(where: { $0.status == .offered }) else {
            return XCTFail("开局应有可接项目")
        }
        store.startNegotiation(dealID: deal.id)

        let reloaded = RainmakerStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.state, store.state)
        XCTAssertEqual(reloaded.state.deals.first { $0.id == deal.id }?.status, .negotiating)
        XCTAssertEqual(reloaded.state.activeNegotiation?.dealID, deal.id)
    }

    func testEndDayPersists() {
        let store = RainmakerStore(fileURL: fileURL)
        store.endDay()

        let reloaded = RainmakerStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.state.day, store.state.day)
    }

    // MARK: - 投递表现层

    func testLaunchRevealsAllExistingEvents() {
        let store = RainmakerStore(fileURL: fileURL)
        for thread in store.state.threads {
            XCTAssertEqual(
                store.visibleEvents(npcID: thread.id).count, thread.events.count,
                "启动时不重播历史消息"
            )
        }
    }

    func testSendMessageDeliversInstantlyInTestMode() {
        let store = RainmakerStore(fileURL: fileURL)
        store.instantDelivery = true
        store.sendMessage("你好", to: "chen")

        let truth = store.state.threads.first { $0.id == "chen" }?.events.count ?? 0
        XCTAssertEqual(store.visibleEvents(npcID: "chen").count, truth, "测试模式即时投递")
        XCTAssertGreaterThanOrEqual(truth, 2, "我方消息 + NPC 回复都已落档")
    }

    func testUnreadUsesVisibleEventsAndMarkReadClears() {
        let store = RainmakerStore(fileURL: fileURL)
        store.instantDelivery = true
        let npcID = store.state.threads[0].id
        XCTAssertGreaterThanOrEqual(store.unreadCount(npcID: npcID), 0)

        store.markRead(npcID: npcID)
        XCTAssertEqual(store.unreadCount(npcID: npcID), 0)

        let reloaded = RainmakerStore(fileURL: fileURL)
        XCTAssertEqual(reloaded.unreadCount(npcID: npcID), 0, "已读游标要持久化")
    }

    // MARK: - 列表筛选与搜索（WhatsApp 式列表页）

    func testFilterAllReturnsThreadsSortedByLastVisible() {
        let store = RainmakerStore(fileURL: fileURL)
        store.instantDelivery = true
        let all = store.filteredThreads(query: "", filter: .all)
        XCTAssertEqual(all.count, store.state.threads.count)
        let times = all.map { store.visibleEvents(npcID: $0.id).last?.at ?? .distantPast }
        XCTAssertEqual(times, times.sorted(by: >), "按最后送达消息时间降序")
    }

    func testQueryMatchesNameAndMessageText() {
        let store = RainmakerStore(fileURL: fileURL)
        store.instantDelivery = true
        store.sendMessage("这单佣金必须到位", to: "chen")

        let byName = store.filteredThreads(query: "陈", filter: .all)
        XCTAssertEqual(byName.map(\.id), ["chen"], "按 NPC 名字搜")

        let byText = store.filteredThreads(query: "佣金必须到位", filter: .all)
        XCTAssertEqual(byText.map(\.id), ["chen"], "按消息内容搜")
    }

    func testUnreadFilterExcludesReadThreads() {
        let store = RainmakerStore(fileURL: fileURL)
        store.instantDelivery = true
        let first = store.state.threads[0].id
        store.markRead(npcID: first)

        let unread = store.filteredThreads(query: "", filter: .unread)
        XCTAssertFalse(unread.contains { $0.id == first })
        XCTAssertFalse(unread.isEmpty, "其余线程仍未读")
    }

    func testDealsFilterKeepsOnlyThreadsWithLiveDeals() {
        let store = RainmakerStore(fileURL: fileURL)
        store.instantDelivery = true
        let dealNPCs = Set(
            store.state.deals
                .filter { $0.status == .offered || $0.status == .negotiating }
                .map(\.npcID)
        )
        let filtered = store.filteredThreads(query: "", filter: .deals)
        XCTAssertEqual(Set(filtered.map(\.id)), dealNPCs)
        XCTAssertFalse(filtered.isEmpty, "开局应有带项目的线程")
    }

    func testRestartResetsRun() {
        let store = RainmakerStore(fileURL: fileURL)
        store.endDay()
        XCTAssertGreaterThan(store.state.day, 1)

        store.restart()
        XCTAssertEqual(store.state.day, 1)
        XCTAssertEqual(store.state.cash, RainmakerBalance.startCash)
        XCTAssertFalse(store.state.isGameOver)
    }
}
