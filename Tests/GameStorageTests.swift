import Foundation
import Testing
@testable import Game2048

@Suite struct GameStorageTests {
    let defaults: UserDefaults
    let storage: GameStorage

    init() {
        defaults = UserDefaults(suiteName: "GameStorageTests")!
        defaults.removePersistentDomain(forName: "GameStorageTests")
        storage = GameStorage(defaults: defaults)
    }

    @Test func bestScoreRoundTrip() {
        #expect(storage.bestScore == 0)
        storage.bestScore = 1234
        #expect(storage.bestScore == 1234)
    }

    @Test func biggestTileRoundTrip() {
        #expect(storage.biggestTile == 0)
        storage.biggestTile = 2048
        #expect(storage.biggestTile == 2048)
    }

    @Test func gameStateRoundTripAndClear() {
        #expect(storage.gameState == nil)
        var engine = GameEngine(seed: 3)
        _ = engine.apply(.left)
        storage.gameState = engine
        #expect(storage.gameState == engine)
        storage.gameState = nil
        #expect(storage.gameState == nil)
    }

    @Test func nicknameRoundTrip() {
        #expect(storage.nickname == nil)
        storage.nickname = "旅人42"
        #expect(storage.nickname == "旅人42")
        storage.nickname = nil
        #expect(storage.nickname == nil)
    }
}
