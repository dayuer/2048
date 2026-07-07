import Foundation
import Testing
@testable import Game2048

@Suite struct SessionTests {
    /// 固定基准时刻，避免依赖 Date()。
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func startsInSetup() {
        let session = Session(startedAt: t0, plannedDuration: 30 * 60)
        #expect(session.state == .setup)
        #expect(session.plannedDuration == 30.0 * 60)
        #expect(session.activityLog.isEmpty)
    }

    @Test func beginEntersActiveAndLogsHeroActivity() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        #expect(session.state == .active)
        #expect(session.activityLog.count == 1)
        #expect(session.activityLog[0].kind == .game2048)
        #expect(session.activityLog[0].startedAt == t0)
        #expect(session.activityLog[0].endedAt == nil)
    }

    @Test func elapsedActiveTimeExcludesPausedSpan() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        // 玩 10 分钟
        session.pause(at: t0.addingTimeInterval(600))
        // 暂停 5 分钟（颠簸/供餐）
        session.resume(at: t0.addingTimeInterval(900))
        // 再玩 10 分钟后落地
        session.land(at: t0.addingTimeInterval(1500))
        // 实际活跃时间 = 600 + 600 = 1200 秒，暂停的 300 秒被扣除
        #expect(session.elapsedActiveTime(at: t0.addingTimeInterval(1500)) == 1200)
    }

    @Test func landClosesOpenActivityAndEntersLanded() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        session.land(at: t0.addingTimeInterval(1200))
        #expect(session.state == .landed)
        #expect(session.activityLog[0].endedAt == t0.addingTimeInterval(1200))
    }

    @Test func closeEntersClosed() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        session.land(at: t0.addingTimeInterval(60))
        session.close()
        #expect(session.state == .closed)
    }

    @Test func pauseWhileAlreadyPausedIsNoOp() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        session.pause(at: t0.addingTimeInterval(100))
        session.pause(at: t0.addingTimeInterval(200)) // 重复暂停不叠加
        session.resume(at: t0.addingTimeInterval(300))
        // 暂停从 100 到 300 = 200 秒；活跃 = 300 - 200 = 100
        #expect(session.elapsedActiveTime(at: t0.addingTimeInterval(300)) == 100)
    }

    @Test func elapsedTimeFreezesAfterLanding() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        session.land(at: t0.addingTimeInterval(1200))
        // 落地后即使时钟继续前进（用户停留在收尾页），时长应冻结在落地时刻。
        let muchLater = t0.addingTimeInterval(9999)
        #expect(session.elapsedWallTime(at: muchLater) == 1200)
        #expect(session.elapsedActiveTime(at: muchLater) == 1200)
    }

    @Test func wallTimeIncludesPausedSpans() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        session.pause(at: t0.addingTimeInterval(600))
        session.resume(at: t0.addingTimeInterval(900)) // 暂停 300 秒
        session.land(at: t0.addingTimeInterval(1500))
        // 墙钟时长含暂停 = 1500；净活跃时长扣除暂停 = 1200。
        #expect(session.elapsedWallTime(at: t0.addingTimeInterval(9999)) == 1500)
        #expect(session.elapsedActiveTime(at: t0.addingTimeInterval(9999)) == 1200)
    }

    @Test func codableRoundTrip() throws {
        var session = Session(startedAt: t0, plannedDuration: 45 * 60)
        session.begin(at: t0)
        session.pause(at: t0.addingTimeInterval(120))
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        #expect(decoded == session)
    }
}
