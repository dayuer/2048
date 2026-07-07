import Foundation
import Testing
@testable import Game2048

@MainActor
@Suite struct SessionControllerTests {
    let defaults: UserDefaults
    let storage: GameStorage
    var clock: Date

    init() {
        defaults = UserDefaults(suiteName: "SessionControllerTests")!
        defaults.removePersistentDomain(forName: "SessionControllerTests")
        storage = GameStorage(defaults: defaults)
        clock = Date(timeIntervalSince1970: 2_000_000)
    }

    /// 构造一个时钟可控的 controller。
    func makeController(now: @escaping () -> Date) -> SessionController {
        SessionController(storage: storage, now: now)
    }

    @Test mutating func beginPersistsActiveSession() {
        let base = clock
        let controller = makeController { base }
        controller.begin(duration: 30 * 60)
        #expect(controller.session?.state == .active)
        // 立即存档
        #expect(storage.currentSession?.state == .active)
    }

    @Test mutating func restoresInFlightSessionFromStorage() {
        let base = clock
        // 先用一个 controller 制造一个进行中的 Session
        let first = makeController { base }
        first.begin(duration: nil)
        // 新 controller 应从存档恢复，进度不丢
        let restored = makeController { base }
        #expect(restored.session?.state == .active)
        #expect(restored.session?.id == first.session?.id)
    }

    @Test mutating func pauseResumePersistAndPreserveProgress() {
        var now = clock
        let controller = makeController { now }
        controller.begin(duration: nil)
        now = clock.addingTimeInterval(600)
        controller.pause()
        #expect(storage.currentSession?.pausedAt != nil)
        now = clock.addingTimeInterval(900)
        controller.resume()
        #expect(storage.currentSession?.pausedAt == nil)
    }

    @Test mutating func landMovesToLandedAndClearsOnClose() {
        var now = clock
        let controller = makeController { now }
        controller.begin(duration: nil)
        now = clock.addingTimeInterval(1200)
        controller.land()
        #expect(controller.session?.state == .landed)
        #expect(storage.currentSession?.state == .landed)
        controller.close()
        #expect(controller.session == nil)
        #expect(storage.currentSession == nil) // closed 后清场
    }
}
