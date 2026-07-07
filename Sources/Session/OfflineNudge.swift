import Foundation
import Network

/// 轻量离线监测：仅在 setup 态、且用户未永久关闭时，提示「要开始一个 Session 吗？」。
/// 绝不强依赖飞行检测、绝不强制、可永久关闭（关闭后绝不再骚扰）。
@MainActor
@Observable
final class OfflineNudge {
    private(set) var isOffline = false

    private let monitor = NWPathMonitor()
    private let storage: GameStorage

    init(storage: GameStorage) {
        self.storage = storage
        monitor.pathUpdateHandler = { [weak self] path in
            let offline = (path.status != .satisfied)
            Task { @MainActor in self?.isOffline = offline }
        }
        monitor.start(queue: DispatchQueue(label: "OfflineNudge"))
    }

    deinit { monitor.cancel() }

    /// 是否应展示提示：离线 且 用户未永久关闭。
    var shouldPrompt: Bool { isOffline && !storage.offlineNudgeDisabled }

    /// 用户永久关闭提示（此后绝不再骚扰）。
    func disableForever() { storage.offlineNudgeDisabled = true }
}
