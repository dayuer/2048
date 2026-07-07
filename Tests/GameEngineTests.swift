import Foundation
import Testing
@testable import Game2048

func makeTile(_ value: Int, _ x: Int, _ y: Int) -> Tile {
    Tile(value: value, position: Position(x: x, y: y))
}

@Suite struct DirectionTests {
    @Test func vectors() {
        #expect(Direction.up.vector == (0, -1))
        #expect(Direction.down.vector == (0, 1))
        #expect(Direction.left.vector == (-1, 0))
        #expect(Direction.right.vector == (1, 0))
    }
}

@Suite struct GameEngineMoveTests {
    var rng = SeededRNG(state: 42)

    @Test mutating func slideToEdge() {
        var engine = GameEngine(tiles: [makeTile(2, 3, 0)])
        let result = engine.move(.left, using: &rng)
        #expect(result != nil)
        #expect(engine.tiles.contains { $0.value == 2 && $0.position == Position(x: 0, y: 0) })
        #expect(engine.tiles.count == 2) // 移动后生成一个新方块
    }

    @Test mutating func mergeEqualTiles() {
        var engine = GameEngine(tiles: [makeTile(2, 0, 0), makeTile(2, 3, 0)])
        let result = engine.move(.left, using: &rng)
        #expect(result?.scoreGained == 4)
        #expect(engine.score == 4)
        #expect(engine.tiles.contains { $0.value == 4 && $0.position == Position(x: 0, y: 0) })
        #expect(engine.tiles.count == 2) // 合并结果 + 新生成
    }

    @Test mutating func quadRowMergesToPairs() {
        var engine = GameEngine(tiles: [
            makeTile(2, 0, 0), makeTile(2, 1, 0), makeTile(2, 2, 0), makeTile(2, 3, 0),
        ])
        let result = engine.move(.left, using: &rng)
        #expect(result?.scoreGained == 8)
        let rowValues = engine.tiles.filter { $0.position.y == 0 && $0.position.x < 2 }.map(\.value)
        #expect(rowValues.sorted() == [4, 4]) // 不是 [8]
    }

    @Test mutating func noDoubleMergeInOneMove() {
        var engine = GameEngine(tiles: [makeTile(2, 0, 0), makeTile(2, 1, 0), makeTile(4, 2, 0)])
        _ = engine.move(.left, using: &rng)
        #expect(!engine.tiles.contains { $0.value == 8 })
        #expect(engine.tiles.contains { $0.value == 4 && $0.position == Position(x: 0, y: 0) })
        #expect(engine.tiles.contains { $0.value == 4 && $0.position == Position(x: 1, y: 0) })
    }

    @Test mutating func noMoveReturnsNilAndSpawnsNothing() {
        var engine = GameEngine(tiles: [makeTile(2, 0, 0), makeTile(4, 1, 0)])
        let result = engine.move(.left, using: &rng)
        #expect(result == nil)
        #expect(engine.tiles.count == 2)
        #expect(engine.score == 0)
    }

    @Test mutating func mergeTo2048SetsWon() {
        var engine = GameEngine(tiles: [makeTile(1024, 0, 0), makeTile(1024, 1, 0)])
        _ = engine.move(.left, using: &rng)
        #expect(engine.won)
    }

    @Test mutating func slidTilesReportIntermediatePositions() {
        var engine = GameEngine(tiles: [makeTile(2, 0, 0), makeTile(2, 3, 0)])
        let result = engine.move(.left, using: &rng)
        // 滑动阶段：两个原方块都汇聚到 (0,0)，供 UI 做位移动画
        let slid = result!.slidTiles
        #expect(slid.count == 2)
        #expect(slid.allSatisfy { $0.position == Position(x: 0, y: 0) })
        #expect(result!.mergedTiles.count == 1)
        #expect(result!.mergedTiles[0].value == 4)
    }
}

@Suite struct GameEngineStateTests {
    var rng = SeededRNG(state: 7)

    @Test func movesAvailableWithEmptyCell() {
        let engine = GameEngine(tiles: [makeTile(2, 0, 0)])
        #expect(engine.movesAvailable)
    }

    @Test func movesAvailableOnFullBoardWithMatch() {
        // 满盘：其余格子值互不相同，仅 (0,0) 和 (1,0) 相等
        var tiles: [Tile] = [makeTile(2, 0, 0), makeTile(2, 1, 0)]
        var value = 4
        for y in 0..<4 {
            for x in 0..<4 where !(y == 0 && x < 2) {
                tiles.append(makeTile(value, x, y))
                value *= 2
            }
        }
        let engine = GameEngine(tiles: tiles)
        #expect(engine.movesAvailable)
    }

    @Test func noMovesOnCheckerboard() {
        // 棋盘格交替 2/4：无空格且无相邻同值
        var tiles: [Tile] = []
        for y in 0..<4 {
            for x in 0..<4 {
                tiles.append(makeTile((x + y) % 2 == 0 ? 2 : 4, x, y))
            }
        }
        let engine = GameEngine(tiles: tiles)
        #expect(!engine.movesAvailable)
    }

    @Test func terminatedWhenWonWithoutKeepPlaying() {
        var engine = GameEngine(tiles: [makeTile(2, 0, 0)], won: true)
        #expect(engine.isTerminated)
        engine.continueAfterWin()
        #expect(!engine.isTerminated)
    }

    @Test mutating func terminatedEngineIgnoresMoves() {
        var engine = GameEngine(tiles: [makeTile(2, 3, 0)], over: true)
        #expect(engine.move(.left, using: &rng) == nil)
    }

    @Test mutating func newGameHasTwoStartTiles() {
        let engine = GameEngine.newGame(using: &rng)
        #expect(engine.tiles.count == 2)
        #expect(engine.tiles.allSatisfy { $0.value == 2 || $0.value == 4 })
        #expect(engine.tiles[0].position != engine.tiles[1].position)
        #expect(engine.score == 0)
    }

    @Test func biggestTile() {
        let engine = GameEngine(tiles: [makeTile(2, 0, 0), makeTile(512, 1, 0)])
        #expect(engine.biggestTile == 512)
    }

    @Test func codableRoundTrip() throws {
        var rng = SeededRNG(state: 1)
        var engine = GameEngine.newGame(using: &rng)
        _ = engine.move(.left, using: &rng)
        let data = try JSONEncoder().encode(engine)
        let decoded = try JSONDecoder().decode(GameEngine.self, from: data)
        #expect(decoded.tiles == engine.tiles)
        #expect(decoded.score == engine.score)
        #expect(decoded.won == engine.won)
        #expect(decoded.over == engine.over)
    }
}
