import Foundation
import Testing
@testable import Game2048

@Suite struct GameStorageSessionTests {
    let defaults: UserDefaults
    let storage: GameStorage

    init() {
        defaults = UserDefaults(suiteName: "GameStorageSessionTests")!
        defaults.removePersistentDomain(forName: "GameStorageSessionTests")
        storage = GameStorage(defaults: defaults)
    }

    @Test func currentSessionRoundTripAndClear() {
        #expect(storage.currentSession == nil)
        var session = Session(startedAt: Date(timeIntervalSince1970: 3_000_000))
        session.begin(at: Date(timeIntervalSince1970: 3_000_000))
        storage.currentSession = session
        #expect(storage.currentSession == session)
        storage.currentSession = nil
        #expect(storage.currentSession == nil)
    }

    @Test func journeyPassDefaultsLockedAndPersists() {
        #expect(storage.journeyPassUnlocked == false)
        storage.journeyPassUnlocked = true
        #expect(storage.journeyPassUnlocked == true)
    }

    @Test func offlineNudgeDisabledDefaultsFalseAndPersists() {
        #expect(storage.offlineNudgeDisabled == false)
        storage.offlineNudgeDisabled = true
        #expect(storage.offlineNudgeDisabled == true)
    }
}
