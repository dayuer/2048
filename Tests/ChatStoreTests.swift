import Foundation
import Testing
@testable import Game2048

@Suite struct ThreadEventCodableTests {
    @Test func messageRoundTrip() throws {
        let event = ThreadEvent.message(id: UUID(), text: "hi", mine: true, at: Date(timeIntervalSince1970: 100))
        let data = try JSONEncoder().encode(event)
        #expect(try JSONDecoder().decode(ThreadEvent.self, from: data) == event)
    }

    @Test func battleInviteRoundTrip() throws {
        let event = ThreadEvent.battleInvite(id: UUID(), gameID: "game2048", seed: 42, mine: false, at: Date(timeIntervalSince1970: 200))
        let data = try JSONEncoder().encode(event)
        #expect(try JSONDecoder().decode(ThreadEvent.self, from: data) == event)
    }

    @Test func battleResultRoundTrip() throws {
        let event = ThreadEvent.battleResult(id: UUID(), gameID: "game2048", myScore: 1024, theirScore: 512, at: Date(timeIntervalSince1970: 300))
        let data = try JSONEncoder().encode(event)
        #expect(try JSONDecoder().decode(ThreadEvent.self, from: data) == event)
    }

    @Test func threadRoundTripPreservesEventOrder() throws {
        var thread = ChatThread(id: "ai", nickname: "AI 对手")
        thread.events = [
            .battleInvite(id: UUID(), gameID: "game2048", seed: 1, mine: true, at: Date(timeIntervalSince1970: 1)),
            .battleResult(id: UUID(), gameID: "game2048", myScore: 8, theirScore: 4, at: Date(timeIntervalSince1970: 2)),
        ]
        let data = try JSONEncoder().encode(thread)
        #expect(try JSONDecoder().decode(ChatThread.self, from: data) == thread)
    }
}

@MainActor
@Suite struct ChatStoreTests {
    /// 每个用例独立临时文件，互不污染。
    private func makeStore() -> ChatStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-\(UUID().uuidString).json")
        return ChatStore(fileURL: url)
    }

    @Test func startsWithPinnedAIThread() {
        let store = makeStore()
        #expect(store.threads.count == 1)
        #expect(store.threads[0].id == "ai")
    }

    @Test func appendPersistsAndReloads() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-\(UUID().uuidString).json")
        let store = ChatStore(fileURL: url)
        store.append(.battleInvite(id: UUID(), gameID: "game2048", seed: 7, mine: true, at: Date(timeIntervalSince1970: 10)), to: "ai")
        let reloaded = ChatStore(fileURL: url)
        #expect(reloaded.thread(id: "ai")?.events.count == 1)
    }

    @Test func threadsSortedByLastEventDescendingWithAIPinnedFirst() {
        let store = makeStore()
        store.upsert(ChatThread(id: "peer-b", nickname: "B", events: [
            .message(id: UUID(), text: "b", mine: false, at: Date(timeIntervalSince1970: 50)),
        ]))
        store.upsert(ChatThread(id: "peer-a", nickname: "A", events: [
            .message(id: UUID(), text: "a", mine: false, at: Date(timeIntervalSince1970: 90)),
        ]))
        // AI 恒置顶，其余按 lastEventAt 降序
        #expect(store.threads.map(\.id) == ["ai", "peer-a", "peer-b"])
    }

    @Test func deleteRemovesRealThreadButNotAI() {
        let store = makeStore()
        store.upsert(ChatThread(id: "peer-a", nickname: "A", events: []))
        store.delete(id: "peer-a")
        #expect(store.thread(id: "peer-a") == nil)
        store.delete(id: "ai")            // 不可删
        #expect(store.thread(id: "ai") != nil)
    }

    @Test func corruptFileFallsBackToPinnedAIThread() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-\(UUID().uuidString).json")
        try Data("not json".utf8).write(to: url)
        let store = ChatStore(fileURL: url)
        #expect(store.threads.count == 1)
        #expect(store.threads[0].id == "ai")
    }
}
