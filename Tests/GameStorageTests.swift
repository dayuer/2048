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
        var rng = SeededRNG(state: 3)
        let engine = GameEngine.newGame(using: &rng)
        storage.gameState = engine
        #expect(storage.gameState?.tiles == engine.tiles)
        storage.gameState = nil
        #expect(storage.gameState == nil)
    }
}
