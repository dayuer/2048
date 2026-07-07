import Foundation

/// 2048 核心规则，忠实移植自 gabrielecirulli/2048 的 game_manager.js
/// （遍历顺序、最远位置、单次合并约束）。遵循 GridGame 基本法：
/// conform GridGameEngine，结果以 Resolution/Beat 时间线表达，
/// RNG 状态并入 Codable 状态——存档恢复后续序列可复现。
struct GameEngine: GridGameEngine, Codable, Equatable {
    static let size = 4
    static let kind = ActivityKind.grid2048

    private(set) var grid: Grid<Int>
    private(set) var score: Int
    private(set) var won: Bool
    private(set) var keepPlaying: Bool
    private var rng: SeededGenerator

    /// 确定性开局：同种子 = 同开局与同后续生成序列。
    init(seed: UInt64) {
        self.init(grid: Grid(rows: Self.size, cols: Self.size), rng: SeededGenerator(seed: seed))
        spawnRandomTile()
        spawnRandomTile()
    }

    /// 指定局面构造（测试用）。
    init(
        grid: Grid<Int>,
        score: Int = 0,
        won: Bool = false,
        keepPlaying: Bool = false,
        rng: SeededGenerator = SeededGenerator(seed: 0)
    ) {
        self.grid = grid
        self.score = score
        self.won = won
        self.keepPlaying = keepPlaying
        self.rng = rng
    }

    var summary: ActivitySummary { ActivitySummary(headline: "2048", score: score) }

    /// 引擎自身无路可走（无空格且四向无同值）。胜利目标是外层规则，不在此判定。
    var isTerminal: Bool { !movesAvailable }

    /// 对局终止：死局，或已胜且未选择继续。
    var isTerminated: Bool { isTerminal || (won && !keepPlaying) }

    var biggestTile: Int { grid.occupied.map(\.tile.payload).max() ?? 0 }

    var movesAvailable: Bool {
        if !grid.emptyCoords.isEmpty { return true }
        for row in 0..<Self.size {
            for col in 0..<Self.size {
                guard let value = grid[Coord(row: row, col: col)]?.payload else { continue }
                if row + 1 < Self.size, grid[Coord(row: row + 1, col: col)]?.payload == value { return true }
                if col + 1 < Self.size, grid[Coord(row: row, col: col + 1)]?.payload == value { return true }
            }
        }
        return false
    }

    mutating func continueAfterWin() { keepPlaying = true }

    /// 朝 action 方向滑动。时间线：第 1 拍 moves + transforms（滑动与合并），
    /// 第 2 拍 spawns（那一个随机新块）。无变化/已终止时 beats 为空且状态不变。
    @discardableResult
    mutating func apply(_ action: Direction) -> Resolution<Int> {
        guard !isTerminated else { return Resolution() }

        let (dRow, dCol) = action.vector
        // 从滑动方向最远端开始遍历（与原版 buildTraversals 一致）
        var rowOrder = Array(0..<Self.size)
        var colOrder = Array(0..<Self.size)
        if dRow == 1 { rowOrder.reverse() }
        if dCol == 1 { colOrder.reverse() }

        var work = grid
        var beat = Beat<Int>()
        var mergedResultIDs: Set<UUID> = []
        var moved = false
        var gained = 0

        for row in rowOrder {
            for col in colOrder {
                let start = Coord(row: row, col: col)
                guard let tile = work[start] else { continue }

                // 找最远可达空位及其后第一个障碍
                var farthest = start
                var next = Coord(row: row + dRow, col: col + dCol)
                while work.contains(next), work[next] == nil {
                    farthest = next
                    next = Coord(row: next.row + dRow, col: next.col + dCol)
                }

                if work.contains(next),
                   let other = work[next],
                   other.payload == tile.payload,
                   !mergedResultIDs.contains(other.id) {
                    // 合并：每个方块每次滑动最多参与一次（原版 mergedFrom 语义）
                    let merged = Tile(payload: tile.payload * 2)
                    work[start] = nil
                    work[next] = merged
                    mergedResultIDs.insert(merged.id)
                    beat.moves.append(Move(id: tile.id, from: start, to: next))
                    beat.transforms.append(Transform(
                        consumed: [tile.id, other.id], produced: merged.id, at: next, payload: merged.payload
                    ))
                    gained += merged.payload
                    if merged.payload == 2048 { won = true }
                    moved = true
                } else if farthest != start {
                    work[start] = nil
                    work[farthest] = tile
                    beat.moves.append(Move(id: tile.id, from: start, to: farthest))
                    moved = true
                }
            }
        }

        guard moved else { return Resolution() }

        grid = work
        score += gained
        var beats = [beat]
        if let spawn = spawnRandomTile() {
            beats.append(Beat(spawns: [spawn]))
        }
        return Resolution(beats: beats, scoreDelta: gained)
    }

    @discardableResult
    private mutating func spawnRandomTile() -> Spawn<Int>? {
        let empty = grid.emptyCoords
        guard !empty.isEmpty else { return nil }
        let coord = empty[Int.random(in: 0..<empty.count, using: &rng)]
        let value = Double.random(in: 0..<1, using: &rng) < 0.9 ? 2 : 4
        let tile = Tile<Int>(payload: value)
        grid[coord] = tile
        return Spawn(id: tile.id, at: coord, payload: value)
    }
}
