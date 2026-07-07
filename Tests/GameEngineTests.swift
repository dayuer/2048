import Foundation
import Testing
@testable import Game2048

/// 按 (value, row, col) 摆盘。
func makeGrid(_ entries: [(value: Int, row: Int, col: Int)]) -> Grid<Int> {
    var grid = Grid<Int>(rows: GameEngine.size, cols: GameEngine.size)
    for entry in entries {
        grid[Coord(row: entry.row, col: entry.col)] = Tile(payload: entry.value)
    }
    return grid
}

func makeEngine(
    _ entries: [(value: Int, row: Int, col: Int)],
    won: Bool = false,
    seed: UInt64 = 42
) -> GameEngine {
    GameEngine(grid: makeGrid(entries), won: won, rng: SeededGenerator(seed: seed))
}

/// 网格形状（坐标→数值），忽略 UUID。
func shape(_ grid: Grid<Int>) -> [Coord: Int] {
    Dictionary(uniqueKeysWithValues: grid.occupied.map { ($0.coord, $0.tile.payload) })
}

@Suite struct DirectionTests {
    @Test func vectors() {
        #expect(Direction.up.vector == (-1, 0))
        #expect(Direction.down.vector == (1, 0))
        #expect(Direction.left.vector == (0, -1))
        #expect(Direction.right.vector == (0, 1))
    }
}

@Suite struct GameEngineMoveTests {
    @Test func slideToEdge() {
        var engine = makeEngine([(2, 0, 3)])
        let movingID = engine.grid[Coord(row: 0, col: 3)]!.id
        let resolution = engine.apply(.left)
        #expect(resolution.beats.count == 2)
        #expect(resolution.beats[0].moves == [Move(
            id: movingID, from: Coord(row: 0, col: 3), to: Coord(row: 0, col: 0)
        )])
        #expect(engine.grid[Coord(row: 0, col: 0)]?.payload == 2)
        #expect(engine.grid.occupied.count == 2) // 移动后生成一个新方块
        #expect(resolution.beats[1].spawns.count == 1)
    }

    @Test func mergeEqualTiles() {
        var engine = makeEngine([(2, 0, 0), (2, 0, 3)])
        let resolution = engine.apply(.left)
        #expect(resolution.scoreDelta == 4)
        #expect(engine.score == 4)
        #expect(engine.grid[Coord(row: 0, col: 0)]?.payload == 4)
        #expect(engine.grid.occupied.count == 2) // 合并结果 + 新生成
        let transforms = resolution.beats[0].transforms
        #expect(transforms.count == 1)
        #expect(transforms[0].at == Coord(row: 0, col: 0))
        #expect(transforms[0].payload == 4)
        #expect(transforms[0].consumed.count == 2)
    }

    @Test func quadRowMergesToPairs() {
        var engine = makeEngine([(2, 0, 0), (2, 0, 1), (2, 0, 2), (2, 0, 3)])
        let resolution = engine.apply(.left)
        #expect(resolution.scoreDelta == 8)
        #expect(engine.grid[Coord(row: 0, col: 0)]?.payload == 4) // 不是 [8]
        #expect(engine.grid[Coord(row: 0, col: 1)]?.payload == 4)
    }

    @Test func noDoubleMergeInOneMove() {
        var engine = makeEngine([(2, 0, 0), (2, 0, 1), (4, 0, 2)])
        _ = engine.apply(.left)
        #expect(!engine.grid.occupied.contains { $0.tile.payload == 8 })
        #expect(engine.grid[Coord(row: 0, col: 0)]?.payload == 4)
        #expect(engine.grid[Coord(row: 0, col: 1)]?.payload == 4)
    }

    @Test func noMoveReturnsEmptyResolutionAndKeepsState() {
        var engine = makeEngine([(2, 0, 0), (4, 0, 1)])
        let before = engine
        let resolution = engine.apply(.left)
        #expect(resolution.beats.isEmpty)
        #expect(resolution.scoreDelta == 0)
        #expect(engine == before) // 含 RNG 状态在内完全不变
    }

    @Test func mergeTo2048SetsWon() {
        var engine = makeEngine([(1024, 0, 0), (1024, 0, 1)])
        _ = engine.apply(.left)
        #expect(engine.won)
    }

    @Test func mergeTimelineConvergesConsumedTilesToTarget() {
        var engine = makeEngine([(2, 0, 0), (2, 0, 3)])
        let movingID = engine.grid[Coord(row: 0, col: 3)]!.id
        let stayingID = engine.grid[Coord(row: 0, col: 0)]!.id
        let resolution = engine.apply(.left)
        // 滑动拍：移动方位移到目标格；合并双方都被 transform 消耗
        let beat = resolution.beats[0]
        #expect(beat.moves == [Move(id: movingID, from: Coord(row: 0, col: 3), to: Coord(row: 0, col: 0))])
        #expect(Set(beat.transforms[0].consumed) == Set([movingID, stayingID]))
        #expect(beat.transforms[0].produced == engine.grid[Coord(row: 0, col: 0)]!.id)
    }
}

@Suite struct GameEngineStateTests {
    @Test func notTerminalWithEmptyCell() {
        let engine = makeEngine([(2, 0, 0)])
        #expect(engine.movesAvailable)
        #expect(!engine.isTerminal)
    }

    @Test func notTerminalOnFullBoardWithMatch() {
        // 满盘：其余格子值互不相同，仅 (0,0) 和 (0,1) 相等
        var entries: [(value: Int, row: Int, col: Int)] = [(2, 0, 0), (2, 0, 1)]
        var value = 4
        for row in 0..<4 {
            for col in 0..<4 where !(row == 0 && col < 2) {
                entries.append((value, row, col))
                value *= 2
            }
        }
        let engine = makeEngine(entries)
        #expect(engine.movesAvailable)
    }

    @Test func terminalOnCheckerboard() {
        // 棋盘格交替 2/4：无空格且无相邻同值
        var entries: [(value: Int, row: Int, col: Int)] = []
        for row in 0..<4 {
            for col in 0..<4 {
                entries.append(((row + col) % 2 == 0 ? 2 : 4, row, col))
            }
        }
        let engine = makeEngine(entries)
        #expect(engine.isTerminal)
    }

    @Test func terminatedWhenWonWithoutKeepPlaying() {
        var engine = makeEngine([(2, 0, 0)], won: true)
        #expect(engine.isTerminated)
        engine.continueAfterWin()
        #expect(!engine.isTerminated)
    }

    @Test func terminatedEngineIgnoresMoves() {
        var engine = makeEngine([(2, 0, 3)], won: true)
        #expect(engine.apply(.left).beats.isEmpty)
    }

    @Test func seededInitHasTwoStartTiles() {
        let engine = GameEngine(seed: 7)
        #expect(engine.grid.occupied.count == 2)
        #expect(engine.grid.occupied.allSatisfy { $0.tile.payload == 2 || $0.tile.payload == 4 })
        #expect(engine.score == 0)
    }

    @Test func sameSeedSameOpening() {
        #expect(shape(GameEngine(seed: 5).grid) == shape(GameEngine(seed: 5).grid))
    }

    @Test func biggestTile() {
        let engine = makeEngine([(2, 0, 0), (512, 0, 1)])
        #expect(engine.biggestTile == 512)
    }

    @Test func codableRoundTripPreservesStateAndRNG() throws {
        var engine = GameEngine(seed: 1)
        _ = engine.apply(.left)
        let data = try JSONEncoder().encode(engine)
        var decoded = try JSONDecoder().decode(GameEngine.self, from: data)
        #expect(decoded == engine)
        // RNG 状态随档恢复：双方继续走同一步，形状与得分仍一致
        var original = engine
        let a = original.apply(.up)
        let b = decoded.apply(.up)
        #expect(shape(original.grid) == shape(decoded.grid))
        #expect(a.scoreDelta == b.scoreDelta)
    }
}
