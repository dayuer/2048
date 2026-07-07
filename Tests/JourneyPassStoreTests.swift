import Foundation
import Testing
import StoreKitTest
@testable import Game2048

@MainActor
@Suite struct JourneyPassStoreTests {
    let defaults: UserDefaults
    let storage: GameStorage
    let session: SKTestSession

    init() throws {
        defaults = UserDefaults(suiteName: "JourneyPassStoreTests")!
        defaults.removePersistentDomain(forName: "JourneyPassStoreTests")
        storage = GameStorage(defaults: defaults)
        session = try SKTestSession(configurationFileNamed: "JourneyPass")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    @Test func loadsProduct() async throws {
        let store = JourneyPassStore(storage: storage)
        try await store.loadProduct()
        #expect(store.product?.id == JourneyPassStore.productID)
    }

    @Test func purchaseUnlocksAndPersistsEntitlement() async throws {
        #expect(storage.journeyPassUnlocked == false)
        let store = JourneyPassStore(storage: storage)
        try await store.loadProduct()
        try await store.purchase()
        #expect(store.isUnlocked == true)
        // 权益本地持久化 → 此后离线可用
        #expect(storage.journeyPassUnlocked == true)
    }

    @Test func refreshEntitlementsSyncsFromStoreKit() async throws {
        // 预置一笔已购买交易
        let store1 = JourneyPassStore(storage: storage)
        try await store1.loadProduct()
        try await store1.purchase()

        // 新实例（模拟重装/新会话）：清掉本地标记，靠 StoreKit 恢复
        storage.journeyPassUnlocked = false
        let store2 = JourneyPassStore(storage: storage)
        await store2.refreshEntitlements()
        #expect(store2.isUnlocked == true)
        #expect(storage.journeyPassUnlocked == true)
    }
}
