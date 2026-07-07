import Foundation

/// Session 的生命周期状态。与设计文档一致：setup → active → landed → closed。
enum SessionState: String, Codable, Sendable {
    case setup, active, landed, closed
}

/// Session 内做过的一件事（V1 仅 2048，接口为未来程序化组件预留）。仅本地。
struct SessionActivity: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case game2048
    }
    let kind: Kind
    let startedAt: Date
    var endedAt: Date?
}

/// 一个有始有终的断网时段容器。纯值类型、注入时钟、进度可 Codable 往返。
struct Session: Codable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    /// 计划时长（秒）。可空——用户可以不设时长。
    var plannedDuration: TimeInterval?
    private(set) var state: SessionState
    private(set) var activityLog: [SessionActivity]
    /// 非 nil 表示当前处于暂停中，值为暂停开始时刻。
    private(set) var pausedAt: Date?
    /// 已累计的暂停总时长（秒），用于从墙钟时间中扣除。
    private(set) var accumulatedPause: TimeInterval
    /// 落地时刻。非 nil 后所有时长计算冻结在此刻（收尾统计不随停留而继续增长）。
    private(set) var landedAt: Date?

    init(id: UUID = UUID(), startedAt: Date, plannedDuration: TimeInterval? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.plannedDuration = plannedDuration
        self.state = .setup
        self.activityLog = []
        self.pausedAt = nil
        self.accumulatedPause = 0
        self.landedAt = nil
    }

    /// 进入 active，并登记本次 Session 的 Hero 活动（2048）。
    mutating func begin(at now: Date) {
        guard state == .setup else { return }
        state = .active
        activityLog.append(SessionActivity(kind: .game2048, startedAt: now, endedAt: nil))
    }

    /// 应对颠簸/供餐/广播打断。重复暂停为无操作（不叠加）。
    mutating func pause(at now: Date) {
        guard state == .active, pausedAt == nil else { return }
        pausedAt = now
    }

    /// 从暂停恢复，累计本次暂停时长。
    mutating func resume(at now: Date) {
        guard state == .active, let pausedAt else { return }
        accumulatedPause += now.timeIntervalSince(pausedAt)
        self.pausedAt = nil
    }

    /// 进入 landed，收束所有未结束的活动，并冻结时长于此刻。
    mutating func land(at now: Date) {
        guard state == .active else { return }
        if pausedAt != nil { resume(at: now) }
        for index in activityLog.indices where activityLog[index].endedAt == nil {
            activityLog[index].endedAt = now
        }
        landedAt = now
        state = .landed
    }

    /// 收尾完成，进入 closed（供 UI 清场/归档）。
    mutating func close() {
        state = .closed
    }

    /// 计算截止时刻：落地后冻结在 landedAt，否则用传入的 now。
    private func effectiveEnd(_ now: Date) -> Date { landedAt ?? now }

    /// 断网时段的墙钟时长（秒）：从开始到（落地或现在），含暂停。收尾统计「分钟离线」用它。
    func elapsedWallTime(at now: Date) -> TimeInterval {
        max(0, effectiveEnd(now).timeIntervalSince(startedAt))
    }

    /// 净活跃时长（秒），扣除全部暂停区间。落地后冻结。
    func elapsedActiveTime(at now: Date) -> TimeInterval {
        let end = effectiveEnd(now)
        let wall = end.timeIntervalSince(startedAt)
        let currentPause = pausedAt.map { end.timeIntervalSince($0) } ?? 0
        return max(0, wall - accumulatedPause - currentPause)
    }
}
