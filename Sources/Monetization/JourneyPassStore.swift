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
        // 监听交易更新：其它设备恢复购买、Ask-to-Buy 批准，以及**退款/撤销**（带 revocationDate）。
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.process(update)
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

    /// 发起购买。成功→写入本地权益（离线可用）。校验失败明确抛错供 UI 区分。
    func purchase() async throws {
        guard let product else { throw PurchaseError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified = verification else { throw PurchaseError.verificationFailed }
            await process(verification)
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.verificationFailed
        }
    }

    /// 恢复购买 / 联网校验：扫描当前权益并同步。
    /// 只增不减（`currentEntitlements` 只含未撤销的权益）——保证已购用户离线时绝不被误锁；
    /// 撤销/退款由 `Transaction.updates` 流负责重新落锁（见 `process`）。
    func refreshEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            await process(entitlement)
        }
    }

    /// 显式恢复购买（用户点「恢复购买」）。
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    /// 校验并落地一笔交易的权益状态，然后 finish（避免更新流反复重投）。
    /// 撤销/退款的交易带 `revocationDate` → 落锁；有效交易 → 解锁。
    private func process(_ verification: VerificationResult<Transaction>) async {
        guard case .verified(let transaction) = verification,
              transaction.productID == Self.productID else { return }
        setUnlocked(transaction.revocationDate == nil)
        await transaction.finish()
    }

    private func setUnlocked(_ value: Bool) {
        isUnlocked = value
        storage.journeyPassUnlocked = value
    }
}
