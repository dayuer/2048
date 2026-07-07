import Foundation
import StoreKit

/// Journey Pass：非消耗型 IAP。免费下载，2048 永不被墙；付费买断的是 Session 模式。
/// 权益本地持久化后完全离线可用；联网时以 StoreKit 当前权益校验/恢复。
@MainActor
@Observable
final class JourneyPassStore {
    static let productID = "com.dayuer.above.journeypass"

    /// 购买失败/未联网的静默降级信息（绝不打断游戏）。
    enum PurchaseError: Error, Equatable {
        case productUnavailable
        case verificationFailed
        case userCancelled
        case pending
    }

    private(set) var product: Product?
    /// UI 用的权益真相源：本地持久化优先，联网时被 StoreKit 校验同步。
    private(set) var isUnlocked: Bool

    private let storage: GameStorage
    private nonisolated(unsafe) var updatesTask: Task<Void, Never>?

    init(storage: GameStorage) {
        self.storage = storage
        self.isUnlocked = storage.journeyPassUnlocked
        // 监听交易更新（如其它设备恢复购买）。
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.applyEntitlement(verification: update)
            }
        }
    }

    nonisolated deinit { updatesTask?.cancel() }

    /// 候机室在线加载产品。失败即静默降级（product 保持 nil）。
    func loadProduct() async throws {
        let products = try await Product.products(for: [Self.productID])
        guard let first = products.first else { throw PurchaseError.productUnavailable }
        product = first
    }

    /// 发起购买。成功→写入本地权益（离线可用）。
    func purchase() async throws {
        guard let product else { throw PurchaseError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            try await handle(verification: verification, finishing: true)
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.verificationFailed
        }
    }

    /// 恢复购买/联网校验：扫描当前权益，同步本地状态。
    func refreshEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            await applyEntitlement(verification: entitlement)
        }
    }

    /// 显式恢复购买（用户点「恢复购买」）。
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    /// 校验一笔交易并落地权益（非 finishing 路径）。
    private func applyEntitlement(verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification,
              transaction.productID == Self.productID,
              transaction.revocationDate == nil else { return }
        setUnlocked(true)
    }

    /// throwing 版本，供购买路径区分校验失败。
    private func handle(verification: VerificationResult<Transaction>, finishing: Bool) async throws {
        guard case .verified(let transaction) = verification else {
            throw PurchaseError.verificationFailed
        }
        guard transaction.productID == Self.productID else { return }
        setUnlocked(true)
        if finishing { await transaction.finish() }
    }

    private func setUnlocked(_ value: Bool) {
        isUnlocked = value
        storage.journeyPassUnlocked = value
    }
}
