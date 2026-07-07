# GridGame 基本法落地 + 2048 引擎对齐 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 [GridGame 基本法](../specs/2026-07-08-gridgame-foundation-design.md) 从文档变成代码（`Sources/GridGame/`），并让在建的 2048 `GameEngine` conform `GridGameEngine`——老 `MoveResult` 换成 `Resolution`/`Beat` 结算时间线，RNG 状态并入引擎 `Codable` 状态，避免 V1 按老接口写完返工。

**Architecture:** 新增 `Sources/GridGame/` 底座（状态原语 + 结算时间线词汇 + `SessionActivity`/`GridGameEngine` 两级协议，零游戏规则）；2048 规则内核留在 `Sources/Engine/`，内部改为 `Grid<Int>` 存储、内置 `SeededGenerator`、`apply(_:) -> Resolution<Int>`；UI 两阶段动画改为消费 Beat 时间线（第 1 拍 moves+transforms 滑动、第 2 拍 spawns 淡入），视觉行为不变。Session 外壳仅做撞名重命名（`SessionActivity` struct → `ActivityLogEntry`），不做活动路由重构（那是后续工作）。

**Tech Stack:** Swift 5 / SwiftUI / Swift Testing（`@Suite`/`@Test`/`#expect`）/ xcodegen + xcodebuild。

---

## 全局须知

- **构建工程**：新增/删除 Swift 文件后必须先 `xcodegen generate` 再 xcodebuild（project.yml 按目录收集源文件）。
- **测试命令模板**：
  ```bash
  xcodebuild test -project Game2048.xcodeproj -scheme Game2048 \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:Game2048Tests/<SuiteName> 2>&1 | tail -20
  ```
  全量：去掉 `-only-testing` 参数。
- **坐标约定变更**：老代码用 `Position(x: 列, y: 行)`；基本法用 `Coord(row: 行, col: 列)`。翻译老测试时注意 `Position(x: a, y: b)` ≡ `Coord(row: b, col: a)`。
- **确定性与 UUID**：`Tile.id` 是 `UUID()` 随机生成、**不从种子派生**。所以"确定性"断言比较的是**形状**（坐标→payload 映射）与得分，绝不比较 id。
- **存档兼容**：`GameEngine` 与 `Session` 的 Codable 形状本次都会变。V1 未上架，旧档解码失败即回退新局/无 Session（`try?` 已兜底），可接受，不写迁移。
- **known-issue**：`JourneyPassStoreTests` 里的 StoreKit 集成用例在 CLI 下已知失败（见 591c5ac），全量跑测时忽略它们，其余必须全绿。

## 文件结构

| 动作 | 路径 | 职责 |
|---|---|---|
| Create | `Sources/GridGame/Coord.swift` | 坐标原语 |
| Create | `Sources/GridGame/SeededGenerator.swift` | SplitMix64 种子 RNG（Codable） |
| Create | `Sources/GridGame/Timeline.swift` | `Resolution`/`Beat`/`Move`/`Spawn`/`Removal`/`Transform` |
| Create | `Sources/GridGame/Tile.swift` | 泛型稳定标识块 `Tile<Payload>` |
| Create | `Sources/GridGame/Grid.swift` | 泛型棋盘 `Grid<Payload>` |
| Create | `Sources/GridGame/SessionActivity.swift` | 普遍活动契约 + `ActivityKind` + `ActivitySummary` |
| Create | `Sources/GridGame/GridGameEngine.swift` | 网格引擎协议 |
| Delete | `Sources/Engine/Tile.swift`、`Sources/Engine/Position.swift` | 被泛型 `Tile<Int>` + `Coord` 取代 |
| Modify | `Sources/Engine/Direction.swift` | vector 改 `(dRow, dCol)` |
| Rewrite | `Sources/Engine/GameEngine.swift` | conform `GridGameEngine`，`Grid<Int>` 存储 + 内置 RNG |
| Modify | `Sources/Session/Session.swift` | `SessionActivity` struct → `ActivityLogEntry`，kind 用基本法 `ActivityKind` |
| Create | `Sources/UI/DisplayTile.swift` | UI 渲染用 (id, value, coord) 三元组 |
| Modify | `Sources/UI/GameViewModel.swift`、`BoardView.swift`、`TileView.swift` | 消费 Beat 时间线 |
| Create | `Tests/GridGameTests.swift` | 底座单测（RNG/Grid/时间线 Codable） |
| Create | `Tests/GridGameContractTests.swift` | 契约一致性通用断言 + 2048 实例化 |
| Rewrite | `Tests/GameEngineTests.swift` | 对齐 `apply`/`Resolution` API |
| Modify | `Tests/GameStorageTests.swift`、`Tests/SessionTests.swift` | 适配新 API |
| Delete | `Tests/SeededRNG.swift` | 被 `SeededGenerator` 取代 |
| Modify | `README.md` | 项目结构补 `GridGame/` |

**非目标（本计划不做）**：共享 Beat 渲染器、Match3Engine、Session 持有 `any SessionActivity` 的活动路由、外置规则层。基本法 spec 已把它们列为后续。

---

### Task 1: GridGame 原语——Coord + SeededGenerator

**Files:**
- Create: `Sources/GridGame/Coord.swift`
- Create: `Sources/GridGame/SeededGenerator.swift`
- Create: `Tests/GridGameTests.swift`

- [ ] **Step 1: 写失败测试**

创建 `Tests/GridGameTests.swift`：

```swift
import Foundation
import Testing
@testable import Game2048

@Suite struct SeededGeneratorTests {
    @Test func sameSeedSameSequence() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        for _ in 0..<8 { #expect(a.next() == b.next()) }
    }

    @Test func differentSeedDivergesEarly() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        #expect(a.next() != b.next())
    }

    @Test func codableRoundTripContinuesSequence() throws {
        var original = SeededGenerator(seed: 7)
        _ = original.next()
        _ = original.next()
        let data = try JSONEncoder().encode(original)
        var restored = try JSONDecoder().decode(SeededGenerator.self, from: data)
        for _ in 0..<8 { #expect(original.next() == restored.next()) }
    }
}

@Suite struct CoordTests {
    @Test func codableAndHashable() throws {
        let coord = Coord(row: 2, col: 3)
        let data = try JSONEncoder().encode(coord)
        let decoded = try JSONDecoder().decode(Coord.self, from: data)
        #expect(decoded == coord)
        #expect(Set([coord, Coord(row: 2, col: 3)]).count == 1)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/SeededGeneratorTests 2>&1 | tail -20`
Expected: 编译失败 `cannot find 'SeededGenerator' in scope`

- [ ] **Step 3: 最小实现**

创建 `Sources/GridGame/Coord.swift`：

```swift
/// 基本法坐标原语：行优先（row 向下增长、col 向右增长）。
struct Coord: Codable, Hashable, Sendable {
    let row: Int
    let col: Int
}
```

创建 `Sources/GridGame/SeededGenerator.swift`：

```swift
/// SplitMix64 种子发生器：既是 RandomNumberGenerator 又 Codable。
/// RNG 状态并入引擎 Codable 状态——存档恢复/回放/每日一局同种子同结果（基本法宪法保证）。
struct SeededGenerator: RandomNumberGenerator, Codable, Equatable, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        self.state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/SeededGeneratorTests -only-testing:Game2048Tests/CoordTests 2>&1 | tail -20`
Expected: PASS（4 个用例）

- [ ] **Step 5: Commit**

```bash
git add Sources/GridGame Tests/GridGameTests.swift Game2048.xcodeproj
git commit -m "feat: GridGame 基本法原语——Coord 与 SeededGenerator（RNG 状态可 Codable）"
```

---

### Task 2: GridGame 结算时间线词汇（Beat / Resolution）

**Files:**
- Create: `Sources/GridGame/Timeline.swift`
- Modify: `Tests/GridGameTests.swift`（追加 suite）

- [ ] **Step 1: 写失败测试**

在 `Tests/GridGameTests.swift` 末尾追加：

```swift
@Suite struct TimelineCodableTests {
    @Test func resolutionRoundTripWithAllChangeKinds() throws {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID()
        let resolution = Resolution<Int>(
            beats: [
                Beat(
                    moves: [Move(id: a, from: Coord(row: 0, col: 3), to: Coord(row: 0, col: 0))],
                    removals: [Removal(id: d, at: Coord(row: 2, col: 2))],
                    transforms: [Transform(consumed: [a, b], produced: c, at: Coord(row: 0, col: 0), payload: 4)]
                ),
                Beat(spawns: [Spawn(id: e, at: Coord(row: 3, col: 1), payload: 2)]),
            ],
            scoreDelta: 4
        )
        let data = try JSONEncoder().encode(resolution)
        let decoded = try JSONDecoder().decode(Resolution<Int>.self, from: data)
        #expect(decoded == resolution)
    }

    @Test func emptyResolutionMeansNoChange() {
        let resolution = Resolution<Int>()
        #expect(resolution.beats.isEmpty)
        #expect(resolution.scoreDelta == 0)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/TimelineCodableTests 2>&1 | tail -20`
Expected: 编译失败 `cannot find 'Resolution' in scope`

- [ ] **Step 3: 最小实现**

创建 `Sources/GridGame/Timeline.swift`：

```swift
import Foundation

/// 一次操作的确定性结算时间线：UI 按拍回放即为动画。
/// 不合法/无变化的操作 = beats 为空。
struct Resolution<Payload: Codable & Equatable>: Codable, Equatable {
    var beats: [Beat<Payload>]
    var scoreDelta: Int

    init(beats: [Beat<Payload>] = [], scoreDelta: Int = 0) {
        self.beats = beats
        self.scoreDelta = scoreDelta
    }
}

/// 一拍内同时发生的原子块变化（四类封闭词汇，不泄漏任何游戏机制）。
struct Beat<Payload: Codable & Equatable>: Codable, Equatable {
    var moves: [Move]
    var spawns: [Spawn<Payload>]
    var removals: [Removal]
    var transforms: [Transform<Payload>]

    init(
        moves: [Move] = [],
        spawns: [Spawn<Payload>] = [],
        removals: [Removal] = [],
        transforms: [Transform<Payload>] = []
    ) {
        self.moves = moves
        self.spawns = spawns
        self.removals = removals
        self.transforms = transforms
    }
}

/// 位移：块从 A 移到 B。
struct Move: Codable, Equatable {
    let id: UUID
    let from: Coord
    let to: Coord
}

/// 无中生有（0→1）：新块出现。
struct Spawn<Payload: Codable & Equatable>: Codable, Equatable {
    let id: UUID
    let at: Coord
    let payload: Payload
}

/// 彻底消失（N→0）：块消失且不留下任何东西。
struct Removal: Codable, Equatable {
    let id: UUID
    let at: Coord
}

/// 合成/升级（N→1）：consumed 全部消失，产出物 produced 出现在 at、携带新 payload。
struct Transform<Payload: Codable & Equatable>: Codable, Equatable {
    let consumed: [UUID]
    let produced: UUID
    let at: Coord
    let payload: Payload
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/TimelineCodableTests 2>&1 | tail -20`
Expected: PASS（2 个用例）

- [ ] **Step 5: Commit**

```bash
git add Sources/GridGame/Timeline.swift Tests/GridGameTests.swift Game2048.xcodeproj
git commit -m "feat: 基本法结算时间线词汇——Resolution/Beat 与四类原子块变化"
```

---

### Task 3: SessionActivity 薄契约 + Session 撞名重命名

`Session.swift` 里现有 `struct SessionActivity`（活动日志条目）与基本法的 `protocol SessionActivity` 撞名。协议名以 spec 为准，日志条目改名 `ActivityLogEntry`，其 kind 直接用基本法 `ActivityKind`（`game2048` → `grid2048`，Session 旧档解码失败即视为无进行中 Session，可接受）。

**Files:**
- Create: `Sources/GridGame/SessionActivity.swift`
- Modify: `Sources/Session/Session.swift:9-16,25,48`
- Modify: `Tests/SessionTests.swift:21`

- [ ] **Step 1: 更新既有测试（先改断言再改实现）**

`Tests/SessionTests.swift` 第 21 行：

```swift
// 旧
#expect(session.activityLog[0].kind == .game2048)
// 新
#expect(session.activityLog[0].kind == .grid2048)
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/SessionTests 2>&1 | tail -20`
Expected: 编译失败（`Kind` 无成员 `grid2048`）

- [ ] **Step 3: 实现契约 + 重命名**

创建 `Sources/GridGame/SessionActivity.swift`：

```swift
/// 真正的普遍法：任何玩法 conform 即可作为一个「活动」进入断网 Session，
/// 并自动获得存档/恢复（因 Codable）。Session 外壳只认识本协议，不认识具体游戏。
protocol SessionActivity: Codable {
    /// 供 Session 路由与 UI 选择渲染器。
    static var kind: ActivityKind { get }
    /// 落地收尾展示的本地只读摘要。
    var summary: ActivitySummary { get }
}

enum ActivityKind: String, Codable, Sendable {
    case grid2048, match3
}

struct ActivitySummary: Codable, Equatable, Sendable {
    let headline: String
    let score: Int?
}
```

`Sources/Session/Session.swift` 第 8–16 行整体替换为：

```swift
/// Session 内做过的一件事的日志条目（V1 仅 2048）。仅本地。
/// kind 用基本法 ActivityKind——Session 只依赖 SessionActivity 薄契约层。
struct ActivityLogEntry: Codable, Equatable, Sendable {
    let kind: ActivityKind
    let startedAt: Date
    var endedAt: Date?
}
```

第 25 行：`private(set) var activityLog: [SessionActivity]` → `private(set) var activityLog: [ActivityLogEntry]`

第 48 行：`activityLog.append(SessionActivity(kind: .game2048, startedAt: now, endedAt: nil))` → `activityLog.append(ActivityLogEntry(kind: .grid2048, startedAt: now, endedAt: nil))`

- [ ] **Step 4: 跑测试确认通过**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/SessionTests -only-testing:Game2048Tests/SessionControllerTests -only-testing:Game2048Tests/GameStorageSessionTests 2>&1 | tail -20`
Expected: PASS（Session 全部既有用例）

- [ ] **Step 5: Commit**

```bash
git add Sources/GridGame/SessionActivity.swift Sources/Session/Session.swift Tests/SessionTests.swift Game2048.xcodeproj
git commit -m "feat: SessionActivity 薄契约落地，Session 日志条目更名 ActivityLogEntry 消除撞名"
```

---

### Task 4: Tile\<Payload\> + Grid + GridGameEngine 协议 + 2048 引擎与 UI 原子切换

老 `Tile` 与泛型 `Tile<Payload>` 同名不能共存（同一 module 内 invalid redeclaration），且测试 target 依赖 app target 编译，所以引擎与 UI 必须在同一任务内原子切换。步骤内允许中间态编译失败，任务结束必须全绿。

**Files:**
- Create: `Sources/GridGame/Tile.swift`、`Sources/GridGame/Grid.swift`、`Sources/GridGame/GridGameEngine.swift`
- Delete: `Sources/Engine/Tile.swift`、`Sources/Engine/Position.swift`、`Tests/SeededRNG.swift`
- Modify: `Sources/Engine/Direction.swift`
- Rewrite: `Sources/Engine/GameEngine.swift`、`Tests/GameEngineTests.swift`
- Create: `Sources/UI/DisplayTile.swift`
- Modify: `Sources/UI/GameViewModel.swift`、`Sources/UI/BoardView.swift`、`Sources/UI/TileView.swift`
- Modify: `Tests/GameStorageTests.swift:28-33`、`Tests/GridGameTests.swift`（追加 Grid suite）

- [ ] **Step 1: 写 Grid 的失败测试**

在 `Tests/GridGameTests.swift` 末尾追加：

```swift
@Suite struct GridTests {
    @Test func subscriptGetSet() {
        var grid = Grid<Int>(rows: 4, cols: 4)
        let tile = Tile<Int>(payload: 2)
        grid[Coord(row: 1, col: 2)] = tile
        #expect(grid[Coord(row: 1, col: 2)] == tile)
        #expect(grid[Coord(row: 2, col: 1)] == nil)
    }

    @Test func containsBounds() {
        let grid = Grid<Int>(rows: 4, cols: 4)
        #expect(grid.contains(Coord(row: 0, col: 0)))
        #expect(grid.contains(Coord(row: 3, col: 3)))
        #expect(!grid.contains(Coord(row: -1, col: 0)))
        #expect(!grid.contains(Coord(row: 0, col: 4)))
    }

    @Test func occupiedAndEmptyCoords() {
        var grid = Grid<Int>(rows: 2, cols: 2)
        grid[Coord(row: 0, col: 1)] = Tile<Int>(payload: 4)
        #expect(grid.occupied.count == 1)
        #expect(grid.occupied[0].coord == Coord(row: 0, col: 1))
        #expect(grid.occupied[0].tile.payload == 4)
        #expect(Set(grid.emptyCoords) == Set([
            Coord(row: 0, col: 0), Coord(row: 1, col: 0), Coord(row: 1, col: 1),
        ]))
    }

    @Test func codableRoundTripPreservesNilCells() throws {
        var grid = Grid<Int>(rows: 4, cols: 4)
        grid[Coord(row: 3, col: 0)] = Tile<Int>(payload: 8)
        let data = try JSONEncoder().encode(grid)
        let decoded = try JSONDecoder().decode(Grid<Int>.self, from: data)
        #expect(decoded == grid)
    }
}
```

- [ ] **Step 2: 实现 GridGame 三个新文件**

创建 `Sources/GridGame/Tile.swift`：

```swift
import Foundation

/// 稳定标识的块：id 贯穿生命周期，供 UI 追踪动画。
/// 2048 的数字块、消消乐的宝石都是它的实例（payload 各游戏自定义）。
struct Tile<Payload: Codable & Equatable>: Codable, Identifiable, Equatable {
    let id: UUID
    var payload: Payload

    init(id: UUID = UUID(), payload: Payload) {
        self.id = id
        self.payload = payload
    }
}

extension Tile: Sendable where Payload: Sendable {}
```

创建 `Sources/GridGame/Grid.swift`：

```swift
/// 泛型棋盘：格子承载一个稳定标识的块；空格为 nil。扁平存储，行优先。
struct Grid<Payload: Codable & Equatable>: Codable, Equatable {
    let rows: Int
    let cols: Int
    private(set) var cells: [Tile<Payload>?]

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.cells = Array(repeating: nil, count: rows * cols)
    }

    subscript(_ c: Coord) -> Tile<Payload>? {
        get { cells[c.row * cols + c.col] }
        set { cells[c.row * cols + c.col] = newValue }
    }

    func contains(_ c: Coord) -> Bool {
        c.row >= 0 && c.row < rows && c.col >= 0 && c.col < cols
    }

    /// 所有非空格子及其坐标（行优先），供引擎遍历与 UI 渲染。
    var occupied: [(coord: Coord, tile: Tile<Payload>)] {
        cells.indices.compactMap { index in
            cells[index].map { (Coord(row: index / cols, col: index % cols), $0) }
        }
    }

    var emptyCoords: [Coord] {
        cells.indices.compactMap { index in
            cells[index] == nil ? Coord(row: index / cols, col: index % cols) : nil
        }
    }
}

extension Grid: Sendable where Payload: Sendable {}
```

创建 `Sources/GridGame/GridGameEngine.swift`：

```swift
/// 网格玩法契约：SessionActivity 的特化。纯、确定、无头——不含 UI、不碰计时器、不做 I/O。
/// 胜负/目标不在此层：isTerminal 只表达引擎自身是否还能继续（如 2048 的死局）。
protocol GridGameEngine: SessionActivity {
    associatedtype Action
    associatedtype Payload: Codable & Equatable

    /// 确定性开局；RNG 状态并入自身 Codable 状态。
    init(seed: UInt64)

    var grid: Grid<Payload> { get }
    var score: Int { get }
    var isTerminal: Bool { get }

    /// 施加一次操作，返回一段确定性结算时间线（不合法/无变化则 beats 为空）。
    mutating func apply(_ action: Action) -> Resolution<Payload>
}
```

- [ ] **Step 3: 删旧原语，改 Direction**

```bash
rm Sources/Engine/Tile.swift Sources/Engine/Position.swift Tests/SeededRNG.swift
```

`Sources/Engine/Direction.swift` 整体替换为：

```swift
enum Direction: CaseIterable, Sendable {
    case up, down, left, right

    /// 基本法坐标系：(dRow, dCol)，行向下增长、列向右增长。
    var vector: (dRow: Int, dCol: Int) {
        switch self {
        case .up: (-1, 0)
        case .down: (1, 0)
        case .left: (0, -1)
        case .right: (0, 1)
        }
    }
}
```

- [ ] **Step 4: 重写 GameEngine**

`Sources/Engine/GameEngine.swift` 整体替换为：

```swift
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
```

- [ ] **Step 5: 重写 GameEngineTests**

`Tests/GameEngineTests.swift` 整体替换为（老用例逐一翻译到新 API；注意 `Position(x:a, y:b)` ≡ `Coord(row: b, col: a)`）：

```swift
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
        let resolution = engine.apply(.left)
        #expect(resolution.beats.count == 2)
        #expect(resolution.beats[0].moves == [Move(
            id: resolution.beats[0].moves[0].id,
            from: Coord(row: 0, col: 3), to: Coord(row: 0, col: 0)
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
        // 滑动拍：移动方 A 位移到目标格；合并双方都被 transform 消耗
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
```

- [ ] **Step 6: 修 GameStorageTests**

`Tests/GameStorageTests.swift` 中 `gameStateRoundTrip` 用例改为：

```swift
    @Test func gameStateRoundTrip() {
        #expect(storage.gameState == nil)
        var engine = GameEngine(seed: 1)
        _ = engine.apply(.left)
        storage.gameState = engine
        #expect(storage.gameState == engine)
        storage.gameState = nil
        #expect(storage.gameState == nil)
    }
```

（原用例里的 `SeededRNG`/`newGame(using:)`/`tiles` 均已不存在；若该文件顶部有 `var rng = SeededRNG(...)` 一并删除。）

- [ ] **Step 7: 更新 UI 消费方**

创建 `Sources/UI/DisplayTile.swift`：

```swift
import Foundation

/// BoardView 渲染单元：引擎 Tile<Int> + 其坐标的展开（UI 过渡帧需要独立于引擎改坐标）。
struct DisplayTile: Identifiable, Equatable {
    let id: UUID
    var value: Int
    var coord: Coord
}
```

`Sources/UI/GameViewModel.swift` 整体替换为：

```swift
import SwiftUI

/// 编排：输入 → 引擎 → 按 Beat 时间线两阶段动画 → 存档 → Game Center 提交。
@MainActor
@Observable
final class GameViewModel {
    enum Overlay {
        case none, won, lost
    }

    private(set) var engine: GameEngine
    /// BoardView 渲染的方块（滑动阶段与引擎最终状态之间的过渡帧）。
    private(set) var displayTiles: [DisplayTile]
    private(set) var bestScore: Int
    private(set) var overlay: Overlay = .none
    private(set) var scoreDelta = 0
    private(set) var scoreDeltaID = 0

    private let storage: GameStorage
    private let gameCenter: GameCenterManager
    private var isAnimating = false

    var score: Int { engine.score }

    init(storage: GameStorage = GameStorage(), gameCenter: GameCenterManager) {
        self.storage = storage
        self.gameCenter = gameCenter
        let engine = storage.gameState ?? GameEngine(seed: .random(in: .min ... .max))
        self.engine = engine
        self.displayTiles = Self.displayTiles(of: engine)
        self.bestScore = storage.bestScore
        if engine.won && !engine.keepPlaying { overlay = .won }
    }

    private static func displayTiles(of engine: GameEngine) -> [DisplayTile] {
        engine.grid.occupied.map { DisplayTile(id: $0.tile.id, value: $0.tile.payload, coord: $0.coord) }
    }

    func move(_ direction: Direction) {
        guard !isAnimating else { return }
        let resolution = engine.apply(direction)
        guard let slideBeat = resolution.beats.first else { return }
        isAnimating = true

        // 滑动拍：按 moves 更新位置（合并双方都汇聚到目标格）
        let targets = Dictionary(uniqueKeysWithValues: slideBeat.moves.map { ($0.id, $0.to) })
        var slid = displayTiles
        for index in slid.indices {
            if let to = targets[slid[index].id] { slid[index].coord = to }
        }
        // easeOut：减速滑入、平稳到位
        withAnimation(.easeOut(duration: 0.1)) {
            displayTiles = slid
        }

        Task {
            try? await Task.sleep(for: .milliseconds(100))
            // 落定拍：合并产物与新方块纯淡入，无弹跳
            withAnimation(.easeOut(duration: 0.12)) {
                displayTiles = Self.displayTiles(of: engine)
            }
            finishMove(resolution)
            isAnimating = false
        }
    }

    private func finishMove(_ resolution: Resolution<Int>) {
        if resolution.scoreDelta > 0 {
            scoreDelta = resolution.scoreDelta
            scoreDeltaID += 1
        }
        if engine.score > bestScore {
            bestScore = engine.score
            storage.bestScore = bestScore
            gameCenter.submitBestScore(bestScore)
        }
        if engine.biggestTile > storage.biggestTile {
            storage.biggestTile = engine.biggestTile
            gameCenter.submitBiggestTile(engine.biggestTile)
        }
        if engine.isTerminal {
            storage.gameState = nil
            overlay = .lost
        } else {
            storage.gameState = engine
            if engine.won && !engine.keepPlaying { overlay = .won }
        }
    }

    func newGame() {
        storage.gameState = nil
        engine = GameEngine(seed: .random(in: .min ... .max))
        overlay = .none
        withAnimation(.easeOut(duration: 0.2)) {
            displayTiles = Self.displayTiles(of: engine)
        }
    }

    func keepGoing() {
        engine.continueAfterWin()
        storage.gameState = engine
        overlay = .none
    }

    func showLeaderboard() {
        gameCenter.showLeaderboard()
    }
}
```

`Sources/UI/BoardView.swift` 整体替换为：

```swift
import SwiftUI

struct BoardView: View {
    let tiles: [DisplayTile]

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            let spacing = side * 0.03
            let cellSize = (side - spacing * CGFloat(GameEngine.size + 1)) / CGFloat(GameEngine.size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: side * 0.016)
                    .fill(Theme.board)

                ForEach(0..<GameEngine.size * GameEngine.size, id: \.self) { index in
                    let coord = Coord(row: index / GameEngine.size, col: index % GameEngine.size)
                    RoundedRectangle(cornerRadius: cellSize * 0.06)
                        .fill(Theme.emptyCell)
                        .frame(width: cellSize, height: cellSize)
                        .offset(offset(for: coord, cellSize: cellSize, spacing: spacing))
                }

                ForEach(tiles) { tile in
                    TileView(value: tile.value, cellSize: cellSize)
                        .offset(offset(for: tile.coord, cellSize: cellSize, spacing: spacing))
                        // 出现只做纯淡入（无任何缩放/弹跳）；移除立即消失
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .identity
                        ))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func offset(for coord: Coord, cellSize: CGFloat, spacing: CGFloat) -> CGSize {
        CGSize(
            width: spacing + (cellSize + spacing) * CGFloat(coord.col),
            height: spacing + (cellSize + spacing) * CGFloat(coord.row)
        )
    }
}
```

`Sources/UI/TileView.swift` 改为按值渲染（不再依赖引擎 Tile 类型）：

```swift
import SwiftUI

struct TileView: View {
    let value: Int
    let cellSize: CGFloat

    private var fontSize: CGFloat {
        switch String(value).count {
        case ...2: cellSize * 0.52
        case 3: cellSize * 0.42
        case 4: cellSize * 0.34
        default: cellSize * 0.27
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cellSize * 0.06)
            .fill(Theme.tileColor(value))
            .overlay(
                Text(verbatim: String(value))
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(Theme.tileTextColor(value))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(cellSize * 0.05)
            )
            // 先把块+数字合成为单一图层再做透明度过渡，
            // 避免淡入时数字（对比度低）比色块晚显现造成的视觉跳动
            .compositingGroup()
            .frame(width: cellSize, height: cellSize)
    }
}
```

- [ ] **Step 8: 全量构建 + 测试**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30`
Expected: 除 JourneyPassStoreTests 已知 StoreKit CLI 失败外全绿（GridGameTests / GameEngineTests / GameStorage* / Session* 全 PASS）

- [ ] **Step 9: Commit**

```bash
git add -A
git commit -m "feat: 2048 引擎对齐基本法——conform GridGameEngine，MoveResult 换 Resolution/Beat，RNG 并入 Codable 状态，UI 消费时间线"
```

---

### Task 5: 契约一致性测试（基本法通用断言）

spec 要求"为每个 conform 的引擎提供一组通用断言"。写成泛型助手，先用 GameEngine 实例化；Match3Engine 到来时直接复用。

**Files:**
- Create: `Tests/GridGameContractTests.swift`

- [ ] **Step 1: 写测试（新代码直接写全，跑一次即验证）**

创建 `Tests/GridGameContractTests.swift`：

```swift
import Foundation
import Testing
@testable import Game2048

/// 基本法契约一致性断言：任何 GridGameEngine 都应通过。
enum GridGameContract {
    /// 网格形状（坐标→payload）。UUID 非种子派生，不参与确定性比较。
    static func shape<E: GridGameEngine>(_ engine: E) -> [Coord: E.Payload] {
        Dictionary(uniqueKeysWithValues: engine.grid.occupied.map { ($0.coord, $0.tile.payload) })
    }

    /// 同种子开局形状一致。
    static func assertDeterministicStart<E: GridGameEngine>(_ type: E.Type, seed: UInt64) {
        #expect(shape(E(seed: seed)) == shape(E(seed: seed)))
    }

    /// Codable 往返后施加同一操作，形状与得分一致（RNG 状态随档恢复）。
    static func assertCodableRoundTripPreservesApply<E: GridGameEngine>(_ engine: E, action: E.Action) throws {
        var original = engine
        let data = try JSONEncoder().encode(engine)
        var restored = try JSONDecoder().decode(E.self, from: data)
        let a = original.apply(action)
        let b = restored.apply(action)
        #expect(shape(original) == shape(restored))
        #expect(a.scoreDelta == b.scoreDelta)
        #expect(a.beats.count == b.beats.count)
    }

    /// 时间线 id 自洽：moves/removals/consumed 引用当拍已知的块；
    /// spawns/produced 是新块；回放完毕后的存活集合 == 结算后棋盘上的块。
    static func assertTimelineIDsConsistent<E: GridGameEngine>(_ start: E, action: E.Action) {
        var engine = start
        var known = Set(engine.grid.occupied.map(\.tile.id))
        let resolution = engine.apply(action)
        for beat in resolution.beats {
            for move in beat.moves { #expect(known.contains(move.id)) }
            for removal in beat.removals {
                #expect(known.contains(removal.id))
                known.remove(removal.id)
            }
            for transform in beat.transforms {
                for consumed in transform.consumed {
                    #expect(known.contains(consumed))
                    known.remove(consumed)
                }
                #expect(!known.contains(transform.produced))
                known.insert(transform.produced)
            }
            for spawn in beat.spawns {
                #expect(!known.contains(spawn.id))
                known.insert(spawn.id)
            }
        }
        #expect(Set(engine.grid.occupied.map(\.tile.id)) == known)
    }
}

@Suite struct Game2048ContractTests {
    /// 从种子局面走几步，得到一个"棋局中段"引擎（比开局更能暴露契约问题）。
    private func midGameEngine() -> GameEngine {
        var engine = GameEngine(seed: 99)
        _ = engine.apply(.left)
        _ = engine.apply(.up)
        return engine
    }

    @Test func deterministicStart() {
        GridGameContract.assertDeterministicStart(GameEngine.self, seed: 2048)
    }

    @Test func codableRoundTripPreservesApply() throws {
        try GridGameContract.assertCodableRoundTripPreservesApply(midGameEngine(), action: .down)
    }

    @Test func timelineIDsConsistent() {
        for direction in Direction.allCases {
            GridGameContract.assertTimelineIDsConsistent(midGameEngine(), action: direction)
        }
    }

    @Test func sessionActivityConformance() {
        #expect(GameEngine.kind == .grid2048)
        let engine = midGameEngine()
        #expect(engine.summary.headline == "2048")
        #expect(engine.summary.score == engine.score)
    }
}
```

- [ ] **Step 2: 跑测试确认通过**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/Game2048ContractTests 2>&1 | tail -20`
Expected: PASS（4 个用例）

- [ ] **Step 3: Commit**

```bash
git add Tests/GridGameContractTests.swift Game2048.xcodeproj
git commit -m "test: 基本法契约一致性通用断言（确定性/Codable 往返/时间线 id 自洽）+ 2048 实例化"
```

---

### Task 6: 文档回填（README 项目结构）

**Files:**
- Modify: `README.md:54-64`

- [ ] **Step 1: 更新项目结构**

`README.md` 项目结构代码块中，在 `├── App/` 之后、`├── Engine/` 行处改为：

```
Sources/
├── App/            # 入口、entitlements、图标
├── GridGame/       # 基本法底座：状态原语 + Beat 结算时间线 + SessionActivity/GridGameEngine 契约（零游戏规则）
├── Engine/         # 2048 规则内核（GridGameEngine 特化；纯逻辑、Codable、RNG 状态随档）
├── Session/        # 断网时段状态机 + SessionController 编排 + 离线提示（纯逻辑，可单测）
├── Monetization/   # Journey Pass（StoreKit 2 非消耗型 IAP，权益本地持久化）
├── Persistence/    # UserDefaults 存档（局面 / Session / Pass 权益）
├── GameCenter/     # GameKit 认证与排行榜（Session 语境下自愿、非门槛）
└── UI/             # SwiftUI 视图：2048 本体 + Session 外壳（墨上留白）
Config/             # JourneyPass.storekit 本地测试配置
Tests/              # Swift Testing 单元测试
```

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README 项目结构补 GridGame 基本法底座"
```
