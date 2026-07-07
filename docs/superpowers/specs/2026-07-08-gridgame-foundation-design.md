# GridGame 公共底座（基本法）设计文档

日期：2026-07-08
仓库：https://github.com/dayuer/2048.git
定位：**基本法**——所有网格类玩法（2048、消消乐、及未来游戏）共同遵守的最薄公共契约。

## 目的与范围

「离线时刻伴侣」会承载多款游戏。本 spec 定义它们**共享的底座**，让每款游戏都能：即插进 Session、复用同一套 UI 渲染与动画、共享存档/恢复与测试脚手架。

**本 spec 只定义契约，不含任何游戏规则。** 它规定的东西分两层：

- **普遍活动契约** `SessionActivity`：Session 唯一依赖的最薄接口。任何玩法（网格 / 经营 / 文字…）conform 即可插入断网 Session。它比 GridGame 宽，因为它要容纳未来的**非网格**家族。
- **网格玩法契约（GridGame 本体）**，`GridGameEngine` 是 `SessionActivity` 的一个特化：
  1. 公共状态原语（`Coord` / `Grid` / `Tile` / RNG / `Codable`）
  2. **结算时间线词汇**（统一描述"棋盘上发生了什么"）
  3. **引擎协议** `GridGameEngine`（网格游戏引擎 conform）
  4. UI 渲染契约

落点：`Sources/GridGame/`，零第三方依赖。

## 第一性原则（宪法精神）

- **只抽公共契约，绝不抽规则内核。** 2048 的"沿轴滑动+合并"与消消乐的"匹配+连锁+重力"是**不同的算法**，各自独立、各自单测。基本法**不含**任何一种机制。
- **薄。** 底座宁小勿大。它只统一"状态形状 + 结算词汇 + 协议"，不做聪明的通用逻辑。
- **无上帝引擎。** 违反前两条即为违宪。
- **每个引擎独立可理解、可测试**，仅通过本契约与外界通信。

## 分层

```
┌─────────────────────────────────────────────────┐
│  Session 外壳（只依赖 SessionActivity，不认识具体游戏）    │
├─────────────────────────────────────────────────┤
│  SessionActivity 普遍活动契约（真正的普遍法）             │  ← Codable 存档/恢复 + kind + summary
│    ├─ GridGameEngine 家族（网格·操作驱动）               │
│    │    GameEngine(2048) │ Match3Engine │ …        │  ← 各自规则内核，独立可测
│    │    + 一套 SwiftUI 棋盘渲染器（消费 Beat 时间线）        │
│    └─ 未来 SimEngine 家族（经营·时间驱动）… 本 spec 不设计   │
├─────────────────────────────────────────────────┤
│  GridGame 基本法原语（本 spec）                         │
│   Coord / Grid<Tile> / Tile<Payload>(稳定 UUID)     │
│   SeededGenerator(RNG, Codable) / Codable 状态       │
│   结算时间线词汇：Beat { moves, spawns,               │
│                        removals, transforms }       │
│   引擎协议 GridGameEngine（: SessionActivity）         │
└─────────────────────────────────────────────────┘
```

## 1. 公共状态原语

```swift
struct Coord: Codable, Hashable { let row: Int; let col: Int }

/// 泛型棋盘：格子承载一个稳定标识的块；空格为 nil
struct Grid<Payload: Codable & Equatable>: Codable {
    let rows: Int
    let cols: Int
    private(set) var cells: [Tile<Payload>?]     // 扁平存储 + 下标助手
    subscript(_ c: Coord) -> Tile<Payload>? { get set }
}

/// 稳定标识的块：id 供 UI 追踪动画（2048 的 Tile、消消乐的 Gem 都是它的实例）
struct Tile<Payload: Codable & Equatable>: Codable, Identifiable, Equatable {
    let id: UUID          // 稳定标识，贯穿其生命周期
    var payload: Payload  // 各游戏自定义：2048 = 数值；消消乐 = 颜色+类型
}
```

### RNG（确定性的宪法保证）

```swift
/// 种子发生器：既是 RandomNumberGenerator，又 Codable
struct SeededGenerator: RandomNumberGenerator, Codable { /* SplitMix64 等 */ }
```

- **RNG 状态是引擎 `Codable` 状态的一部分**——存档恢复、回放、"每日一局"（同种子=同结果）全部可复现。
- 测试通过固定种子获得确定性。

## 2. 结算时间线词汇（基本法的心脏）

所有游戏对"发生了什么"用**同一套原子块变化**描述。一次操作的结果是一段有序的 `Beat` 序列（时间线）；UI 按拍回放即为动画。

```swift
struct Resolution<Payload: Codable & Equatable>: Codable {
    var beats: [Beat<Payload>]   // 按顺序回放的时间线（2048 通常 1–2 拍，消消乐每层连锁一拍）
    var scoreDelta: Int
}

struct Beat<Payload: Codable & Equatable>: Codable {
    var moves:      [Move]                  // 块从 A 移到 B
    var spawns:     [Spawn<Payload>]        // 新块出现（2048 新生成 / 消消乐顶部补充）
    var removals:   [Removal]               // 块消失且不留下任何东西（消消乐消除）
    var transforms: [Transform<Payload>]    // N 个块合为 1 个（2048 合并 / 消消乐生成特殊块）
}

struct Move:                    Codable { let id: UUID; let from: Coord; let to: Coord }
struct Spawn<Payload>:          Codable { let id: UUID; let at: Coord; let payload: Payload }
struct Removal:                 Codable { let id: UUID; let at: Coord }
struct Transform<Payload>:      Codable { let consumed: [UUID]; let produced: UUID; let at: Coord; let payload: Payload }
```

**四类原子块变化 = 一套封闭词汇**，既够两个已知游戏表达，又不泄漏任一方的机制：
- `move`：位移
- `spawn`：无中生有（0→1）
- `removal`：彻底消失（N→0）
- `transform`：合成/升级（N→1，产出物在 `at`，携带新 `payload`）

## 3. 引擎协议 `GridGameEngine`

```swift
protocol GridGameEngine: SessionActivity {   // SessionActivity 已含 Codable
    associatedtype Action           // 2048 = 方向；消消乐 = 交换两坐标
    associatedtype Payload: Codable & Equatable

    init(seed: UInt64)              // 确定性开局；RNG 状态并入自身 Codable 状态
    var grid: Grid<Payload> { get }
    var score: Int { get }
    var isTerminal: Bool { get }    // 2048 = 无路可走；消消乐(Zen) 恒为 false

    /// 施加一次操作，返回一段确定性结算时间线（不合法/无变化则 beats 为空）
    mutating func apply(_ action: Action) -> Resolution<Payload>
}
```

- **纯、确定、无头**：不含 UI、不碰计时器、不做 I/O。
- **胜负/目标不在此层**：`isTerminal` 只表达"引擎自身是否还能继续"（2048 的死局）；游戏模式、目标、失败判定是引擎之上的外置规则层。

## 4. SessionActivity 普遍活动契约 与 UI 渲染契约

### SessionActivity —— Session 唯一依赖的最薄接口

Session 外壳**不认识** `GridGameEngine`，只认识 `SessionActivity`。这样网格之外的玩法（经营 `SimEngine`、文字推理…）也能插进断网 Session，而**不污染 GridGame**。

```swift
/// 真正的普遍法。任何玩法 conform 即可作为一个「活动」进入断网 Session，
/// 并自动获得存档/恢复（因 Codable）。
protocol SessionActivity: Codable {
    static var kind: ActivityKind { get }   // 供 Session 路由与 UI 选择渲染器
    var summary: ActivitySummary { get }     // 落地收尾展示的本地只读摘要（如标题/分数）
}

enum ActivityKind: String, Codable { case grid2048, match3 /* , sim… 未来扩展 */ }
struct ActivitySummary: Codable { let headline: String; let score: Int? }
```

- **`GridGameEngine: SessionActivity`**：网格游戏免费获得活动身份；`summary` 可由 `score` 提供默认实现。
- 未来的 `SimEngine`（经营/模拟）同样 conform `SessionActivity`，但**不** conform `GridGameEngine`——经营游戏是另一个物种（时间/经济内核），本 spec 不设计。
- **刻意最薄**：只含 Session 收尾与路由真正需要的三样（`kind` + `summary` + `Codable`），不多。

### UI 渲染契约

- **网格家族**共享一套 SwiftUI 棋盘渲染器：消费 `Beat` 时间线，按 `Tile.id` 做位移/淡入/合并/消除动画（复用 2048 已定的稳定 UUID 动画纪律）。**一套渲染器驱动所有网格游戏**——这是本基本法最大的复用回报。
- 非网格家族（如 `SimEngine`）自带各自的渲染，但仍通过 `SessionActivity` 统一接入 Session 生命周期。

## 两个引擎如何映射到基本法（证明契约不泄漏）

**2048** —— `Action = Direction`，`Payload = Int(数值)`：
- `apply(.left)` → `Resolution`，通常 **1–2 拍**：
  - 第 1 拍：`moves`（所有滑动的块）+ `transforms`（每次合并：`consumed:[a,b], produced:c, payload: 翻倍值`）
  - 第 2 拍：`spawns`（那一个随机新块，payload 2 或 4）
- `scoreDelta` = 合并值之和；`isTerminal` = 无空格且四向无同值。
- 无 `removals`。

**消消乐** —— `Action = Swap(Coord,Coord)`，`Payload = (颜色, 类型)`：
- `apply(swap)` → `Resolution`，**每层连锁一拍**：
  - 每拍：`removals`（消除的普通块）+ `transforms`（生成特殊块：`consumed: 匹配组ids, produced: 特殊块id, at: 枢轴`）+ `moves`（重力下落）+ `spawns`（顶部补充）
  - 第 0 拍的 `moves` 表达最初的交换动作
- `scoreDelta` = 连锁总分；`isTerminal` 恒 false（Zen，重排兜底）。

两者落在**同一套 `Beat` 词汇**上，各自的规则内核完全私有。契约成立。

## 纪律 / 不做的事

- **不在基本法里写任何游戏规则**（不写匹配、不写合并、不写滑动）。
- **不做共享规则引擎 / 上帝引擎。**
- **保持薄**：两个实例是"看见模式"的最小样本；只固化已被两方证明的公共契约，不为想象中的第三款网格游戏预留花哨扩展点（第三款出现时再演进）。
- **`SessionActivity` 比 GridGame 宽是有意的**：这是两个不同的轴——它为**解耦**而存在（让非网格家族也能接 Session），只含 Session 真正需要的三样（`kind`/`summary`/`Codable`），不是投机扩展点；GridGame 本体仍保持窄。
- 不含 UI / 动画时长 / 持久化 I/O（那些消费本契约，不属于本层）。

## 测试

- 基本法自身逻辑极少：主要测 `Grid` 下标/边界助手、`SeededGenerator` 的**确定性与 `Codable` 往返**（同种子恢复后续序列一致）、`Resolution`/`Beat` 的 `Codable` 往返。
- **契约一致性测试**：为每个 conform 的引擎提供一组通用断言（`apply` 确定性、`Codable` 往返后 `apply` 结果一致、时间线里引用的 `id` 均自洽）。

## 需要回填的既有 spec

本基本法确立后，以下两份 spec 应声明"遵循基本法"，并把各自的结果类型对齐到 `Resolution`/`Beat`：

- [2048 App 设计](2026-07-07-2048-swift-app-design.md)：`MoveResult` → `Resolution`（滑动/合并/生成映射为 `Beat`）。
- [消消乐引擎设计](2026-07-08-match3-engine-design.md)：`ResolutionStep` → `Beat`；`Match3Engine` conform `GridGameEngine`。

## 后续（非本 spec）

- UI 渲染器与 Session「活动」接口的实现。
- 外置规则层（Zen / 目标 / 限步 / 胜负）。
- 第三款游戏出现时，再评估基本法是否需要演进。
