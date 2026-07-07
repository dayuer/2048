import Foundation

/// 断网时段编排层。UI 的单一真相源；每次状态变更立即存档，进度绝不丢失。
@MainActor
@Observable
final class SessionController {
    private(set) var session: Session?

    private let storage: GameStorage
    private let now: () -> Date

    init(storage: GameStorage, now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.now = now
        // 启动即恢复进行中的 Session（landed 之前的都算进行中）。
        if let saved = storage.currentSession, saved.state == .active || saved.state == .setup {
            self.session = saved
        } else {
            self.session = nil
        }
    }

    /// 开始一个断网时段。可选设时长（秒）；nil = 不设时长。
    func begin(duration: TimeInterval?) {
        var new = Session(startedAt: now(), plannedDuration: duration)
        new.begin(at: now())
        session = new
        persist()
    }

    func pause() {
        session?.pause(at: now())
        persist()
    }

    func resume() {
        session?.resume(at: now())
        persist()
    }

    /// 落地：进入 landed 收尾态（展示克制的「你已落地」）。
    func land() {
        session?.land(at: now())
        persist()
    }

    /// 收尾完成：清场，回到入口态。
    func close() {
        session?.close()
        session = nil
        storage.currentSession = nil
    }

    /// 当前净活跃时长（秒），供收尾统计展示。
    func elapsedActiveTime() -> TimeInterval {
        session?.elapsedActiveTime(at: now()) ?? 0
    }

    private func persist() {
        storage.currentSession = session
    }
}
