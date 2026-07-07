# 消消乐引擎（Match3Engine）设计文档

日期：2026-07-08
仓库：https://github.com/dayuer/2048.git
所属：Game #2 子项目 —— 「离线时刻伴侣」的第二款玩法（见 [离线时刻伴侣 V1 设计](2026-07-07-offline-session-companion-design.md)）
遵循：[GridGame 公共底座（基本法）](2026-07-08-gridgame-foundation-design.md)。`Match3Engine` conform `GridGameEngine`；本文的 `ResolutionStep` 即基本法的 `Beat`，`MoveOutcome.resolved` 即 `Resolution`。

## 范围

本 spec 只覆盖 **无头（headless）、确定性的消消乐引擎 `Match3Engine`**：纯逻辑、`Codable`、注入 RNG、可单测。**不含** UI / 动画 / Session 集成 / 变现——那些是后续子项目。

与 2048 的 `GameEngine` 同构，落在 `Sources/Engine/Match3/`，零第三方依赖。

## 已确认的设计决策（brainstorm 结论）

1. **交互模型**：经典**相邻交换**式 match-3（Bejeweled / 开心消消乐 风格），非点消/塌缩。
2. **引擎哲学**：无头、确定性。输入 `状态 + 操作`，输出 `新状态 + 一段可回放的结算时间线（ResolutionStep 序列）`。引擎不认识 SwiftUI、不认识动画时长、不碰计时器。
3. **特殊块 = 核心三件套**：match-4 → 线消块；match-5（直线）→ 同色炸弹；L/T 相交 → 范围炸弹（3×3）。**不做**两个特殊块交换的连锁大效果（后续扩展）。
4. **纯机制，模式外置**：引擎只做「结算一步 + 计分 + 事件」，**不认识失败/目标/胜负**。Zen 无限玩是默认；目标 / 限步 / 胜负判定做成引擎之上的规则层（不在本 spec）。

## 状态模型（全部 Codable）

- `GemColor`：枚举，数量可配置（默认 6 色）。
- `GemKind`：
  - `.normal`
  - `.lineClear(Axis)`：激活时清除其所在的一整行或一整列（`Axis = .row | .column`）。
  - `.bomb`：激活时清除以自身为中心的 3×3 区域。
  - `.colorBomb`：激活时清除棋盘上某一颜色的全部块（默认取与之交换的相邻块颜色；若非交换触发则取自身颜色）。
- `Gem`：`id: UUID`（稳定标识，供 UI 追踪下落/消除动画，与 2048 的 `Tile` 同套路）、`color: GemColor`、`kind: GemKind`。
- `Cell = Gem?`：`nil` 表示空（仅结算过程中的瞬态）。
- `Board`：`rows`、`cols`、格子存储（扁平 `[Gem?]` + 下标助手）。
- `Coord`：`(row, col)`。
- `GameState`：`board`、`score`、`movesMade`、`rng`（见下）。**整个 `GameState` 可 `Codable`，即为存档。**

### RNG（确定性的关键）

- 通过 `RandomNumberGenerator` 协议注入；提供一个 **`SeededGenerator`（如 SplitMix64/xorshift），本身 `Codable`**。
- **RNG 状态作为 `GameState` 的一部分被序列化**——这样存档恢复、回放、"每日一局"（同种子 = 同棋盘同补块）都完全可复现。
- 测试通过固定种子获得确定性；断言精确棋盘状态。

## 核心 API

```swift
struct Match3Engine {
    let config: Config
    private(set) var state: GameState

    /// 生成一个「无预成匹配、且至少存在一步可走」的开局棋盘
    init(config: Config, seed: UInt64)

    /// 相邻且两端非空
    func canSwap(_ a: Coord, _ b: Coord) -> Bool

    /// 尝试交换：要么被拒（无匹配且无特殊触发），要么产生一段结算时间线
    mutating func swap(_ a: Coord, _ b: Coord) -> MoveOutcome

    /// 所有能形成匹配的合法交换（供提示 + 死局检测）
    func possibleMoves() -> [Move]

    /// 无步可走时重排（保证无预成匹配且≥1步）
    mutating func reshuffle()

    /// 一个提示走法（无则 nil）
    func hint() -> Move?
}
```

`swap` 内部使用 `state.rng`（不外传 RNG 参数），以保证存档/回放的确定性。

### 输出：结算时间线

```swift
enum MoveOutcome {
    case rejected                       // 无匹配 → UI「晃一下弹回」
    case resolved(Resolution)
}

struct Resolution {
    var swappedPair: (Coord, Coord)     // UI 先播交换动作
    var steps: [ResolutionStep]         // 连锁时间线（按拍回放）
    var scoreDelta: Int
    var specialsCreated: [SpecialSpawn]
}

struct ResolutionStep {                 // 连锁中的「一拍」
    var cleared: [Clear]                // gem id、coord、原因（匹配 / 特殊激活）
    var specialActivations: [Activation]
    var falls: [Fall]                   // gem id、from、to
    var spawns: [Spawn]                 // 新块、进入坐标（从顶部落入）
}
```

**引擎只描述"发生了什么"，不决定动画时长**——UI 顺序回放这些拍即为消除动画。这是引擎可单测、可复用的根本原因。

## 三段核心算法

### 1. 匹配检测与形状分类

- 扫描所有**极大**水平连段（长度 ≥3、同色）与垂直连段，收集被匹配的格子集合。
- 将连通的被匹配格子并成**匹配组**（union）。对每组按**形状**分类，决定生成的特殊块：
  1. 含长度 ≥5 的直线 → **同色炸弹**
  2. 同时含水平 ≥3 与垂直 ≥3 且相交（L / T / +）→ **范围炸弹**
  3. 否则含长度 4 的直线 → **线消块**（`Axis` 取该直线方向）
  4. 否则（仅长度 3）→ 无特殊块
- 特殊块生成于**枢轴格**：优先取本次交换落点（若在该组内），否则取相交点，否则取组的中心。

### 2. 结算 / 连锁循环（`swap` 内部）

```
1. 暂时交换 a、b
2. matches = detect()
   —— 若交换的一端是特殊块（如同色炸弹被交换），即使无 match 也触发其激活
3. 若 matches 为空且无特殊触发 → 撤销交换 → 返回 .rejected
4. 循环（每轮 = 一拍 ResolutionStep）：
     a. 计算清除集 = 匹配格 ∪ 被激活特殊块波及的格
        —— 特殊块激活会扩张清除集；若扩张又波及其它特殊块，则它们也激活
          （对特殊块做 BFS，直到不再波及新的特殊块），本拍内一次性求出清除集
     b. 记分（含连锁倍率：第 n 拍倍率递增）
     c. 为达标的匹配组在枢轴生成特殊块
     d. 移除清除集（置空）
     e. 重力：逐列，非空块下落填补空位
     f. 补充：顶部用 rng 生成新块填满剩余空位
     g. 记录 ResolutionStep（cleared / activations / falls / spawns）
     h. matches = detect() 再检测（连锁：落下的块可能又凑成匹配）
        若为空 → break
5. 稳定后：若 possibleMoves() 为空 → reshuffle()
6. movesMade += 1；返回 .resolved(...)
```

### 3. 重力 / 补充 / 可行步 / 重排

- **重力+补充**：逐列把非空块压到底部，顶部空位用 RNG 新块填入。
- **possibleMoves / hint**：对每个格子，模拟与其右邻、下邻交换（不真正改棋盘），若 `detect()` 出匹配则记为合法走法。用于提示与**死局检测**。
- **reshuffle**：收集所有块、RNG 洗牌重排；保证无预成匹配且 ≥1 步（不满足则重掷）。

## 不变量（每次 `.resolved` 之后的后置条件）

1. 棋盘**满**（无空格）
2. 棋盘**稳定**（不存在现成的 ≥3 匹配）
3. **至少存在一步可走**（否则已 reshuffle）—— 这就是"高容错、无死局"的保证，契合飞行场景的随时中断。

## 配置（`Config`）

- `rows`、`cols`（默认 8×8）、`colorCount`（默认 6）
- 计分参数、连锁倍率曲线
- 特殊块规则（哪种匹配 → 哪种特殊块；L/T 开关）——默认即核心三件套
- 全部可调，便于未来做变体而不改核心。

## 性能与功耗

- 每次 `detect()` 为 O(rows×cols)；一步棋触发数拍连锁，计算量微小。
- **仅在用户出招时计算，闲置零 CPU**，无计时器、无常驻循环——完全契合本产品的续航焦虑约束。引擎不做任何渲染。

## 测试（Swift Testing，固定种子确定性）

- **匹配检测**：水平/垂直、长度 3/4/5、L/T 分类 → 生成正确特殊块。
- **被拒交换**：无匹配的交换后棋盘不变。
- **连锁**：构造会连锁 N 次的棋盘，断言时间线拍数与内容。
- **重力/补充**：断言下落与补位正确。
- **特殊块激活**：线消清整行/列；范围炸弹清 3×3；同色炸弹清一整色；**链式激活**（特殊块被特殊块波及）。
- **possibleMoves 正确性**；死局 → reshuffle。
- **不变量属性测试**：随机 fuzz 大量走法后，三条不变量恒成立。
- **`Codable` 往返**（含 RNG 状态）→ 恢复后后续序列完全一致。

## 不做的事（引擎 V1 YAGNI）

- 不含 UI / 动画 / 时长（只输出时间线）。
- 不含目标 / 失败 / 胜负 / 模式（外置规则层）。
- 不做两个特殊块交换的连锁大效果（后续扩展）。
- 不做障碍物（果冻、锁、掉落物等）。
- 不做提示的自动弹出时机（UI 关注点）。
- 不做持久化 I/O（`Persistence` 层的事；引擎只保证 `Codable`）。

## 与参考仓库的关系

- [rembound/Match-3-Game-HTML5](https://github.com/rembound/Match-3-Game-HTML5)：匹配检测、重力/补充、可行步检测的算法参考。
- [bazhanius/match-3-game](https://github.com/bazhanius/match-3-game)：特殊块、闲置提示、本地最高分的机制参考。
- 二者均为 **算法参考**，用 Swift 原生重写；**若逐行移植任何代码，先逐仓核实 LICENSE 并保留署名**。本引擎主体为按算法的净室实现。

## 后续（非本 spec）

- 规则层：Zen / 目标 / 限步等游戏模式。
- 特殊块组合（bomb+bomb、colorBomb+line 等）。
- 障碍物与关卡目标。
- UI 层（SwiftUI，消费 ResolutionStep 时间线做动画，复用 2048 的稳定 UUID 动画纪律）与 Session 集成。
- 种子化"每日一局"。
