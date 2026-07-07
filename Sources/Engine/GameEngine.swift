import Foundation

/// 一次滑动的结果，供 UI 做两阶段动画。
struct MoveResult {
    /// 滑动阶段：所有原方块滑动后的位置（合并双方都汇聚到目标格）。
    let slidTiles: [Tile]
    /// 本次滑动产生的合并结果方块（pop 动画用）。
    let mergedTiles: [Tile]
    /// 本次滑动后随机生成的新方块。
    let spawnedTile: Tile?
    /// 本次滑动的得分增量。
    let scoreGained: Int
}

/// 2048 核心规则，忠实移植自 gabrielecirulli/2048 的 game_manager.js。
/// 纯值类型、无 UI 依赖；随机数由外部注入以便测试。
struct GameEngine: Codable {
    static let size = 4

    private(set) var tiles: [Tile]
    private(set) var score: Int
    private(set) var won: Bool
    private(set) var over: Bool
    private(set) var keepPlaying: Bool

    init(tiles: [Tile], score: Int = 0, won: Bool = false, over: Bool = false, keepPlaying: Bool = false) {
        self.tiles = tiles
        self.score = score
        self.won = won
        self.over = over
        self.keepPlaying = keepPlaying
    }

    static func newGame<R: RandomNumberGenerator>(using rng: inout R) -> GameEngine {
        var engine = GameEngine(tiles: [])
        engine.spawnRandomTile(using: &rng)
        engine.spawnRandomTile(using: &rng)
        return engine
    }

    var isTerminated: Bool { over || (won && !keepPlaying) }

    var biggestTile: Int { tiles.map(\.value).max() ?? 0 }

    var movesAvailable: Bool {
        if tiles.count < Self.size * Self.size { return true }
        var values = [[Int]](repeating: [Int](repeating: 0, count: Self.size), count: Self.size)
        for tile in tiles { values[tile.position.x][tile.position.y] = tile.value }
        for x in 0..<Self.size {
            for y in 0..<Self.size {
                if x + 1 < Self.size, values[x][y] == values[x + 1][y] { return true }
                if y + 1 < Self.size, values[x][y] == values[x][y + 1] { return true }
            }
        }
        return false
    }

    mutating func continueAfterWin() { keepPlaying = true }

    /// 朝 `direction` 滑动。没有方块移动（或对局已结束）时返回 nil 且不改变状态。
    @discardableResult
    mutating func move<R: RandomNumberGenerator>(_ direction: Direction, using rng: inout R) -> MoveResult? {
        guard !isTerminated else { return nil }

        var grid = [[Tile?]](repeating: [Tile?](repeating: nil, count: Self.size), count: Self.size)
        for tile in tiles { grid[tile.position.x][tile.position.y] = tile }

        let (dx, dy) = direction.vector
        // 从滑动方向最远端开始遍历（与原版 buildTraversals 一致）
        var xs = Array(0..<Self.size), ys = Array(0..<Self.size)
        if dx == 1 { xs.reverse() }
        if dy == 1 { ys.reverse() }

        var slidPositions = Dictionary(uniqueKeysWithValues: tiles.map { ($0.id, $0.position) })
        var mergedResultIDs: Set<UUID> = []
        var mergedTiles: [Tile] = []
        var moved = false
        var gained = 0

        for x in xs {
            for y in ys {
                guard let tile = grid[x][y] else { continue }

                // 找最远可达空位及其后第一个障碍
                var farthest = Position(x: x, y: y)
                var next = Position(x: x + dx, y: y + dy)
                while Self.inBounds(next), grid[next.x][next.y] == nil {
                    farthest = next
                    next = Position(x: next.x + dx, y: next.y + dy)
                }

                if Self.inBounds(next),
                   let other = grid[next.x][next.y],
                   other.value == tile.value,
                   !mergedResultIDs.contains(other.id) {
                    // 合并：每个方块每次滑动最多参与一次（原版 mergedFrom 语义）
                    let merged = Tile(value: tile.value * 2, position: next)
                    grid[x][y] = nil
                    grid[next.x][next.y] = merged
                    mergedResultIDs.insert(merged.id)
                    mergedTiles.append(merged)
                    slidPositions[tile.id] = next
                    gained += merged.value
                    if merged.value == 2048 { won = true }
                    moved = true
                } else {
                    grid[x][y] = nil
                    var movedTile = tile
                    movedTile.position = farthest
                    grid[farthest.x][farthest.y] = movedTile
                    slidPositions[tile.id] = farthest
                    if farthest != Position(x: x, y: y) { moved = true }
                }
            }
        }

        guard moved else { return nil }

        let slidTiles = tiles.map { tile in
            var copy = tile
            copy.position = slidPositions[tile.id] ?? tile.position
            return copy
        }
        score += gained
        tiles = grid.flatMap { $0 }.compactMap { $0 }
        let spawned = spawnRandomTile(using: &rng)
        if !movesAvailable { over = true }

        return MoveResult(slidTiles: slidTiles, mergedTiles: mergedTiles, spawnedTile: spawned, scoreGained: gained)
    }

    @discardableResult
    private mutating func spawnRandomTile<R: RandomNumberGenerator>(using rng: inout R) -> Tile? {
        let occupied = Set(tiles.map(\.position))
        var empty: [Position] = []
        for x in 0..<Self.size {
            for y in 0..<Self.size {
                let position = Position(x: x, y: y)
                if !occupied.contains(position) { empty.append(position) }
            }
        }
        guard !empty.isEmpty else { return nil }
        let position = empty[Int.random(in: 0..<empty.count, using: &rng)]
        let value = Double.random(in: 0..<1, using: &rng) < 0.9 ? 2 : 4
        let tile = Tile(value: value, position: position)
        tiles.append(tile)
        return tile
    }

    private static func inBounds(_ p: Position) -> Bool {
        p.x >= 0 && p.x < size && p.y >= 0 && p.y < size
    }
}
