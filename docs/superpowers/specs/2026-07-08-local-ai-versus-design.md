# 本地 AI 同种子实时竞速（Local AI Versus）设计文档 — V2 子项目 A

日期：2026-07-08
仓库：https://github.com/dayuer/2048.git
上位：`2026-07-08-serverless-social-v2-vision.md`（V2 愿景与分解）的第一个可交付子项目。

## 一句话概念

**一个单机「你 vs AI」的 2048 对战模式：你和一个本地 AI 对手玩同一种子的盘（同一串方块生成，纯技巧），AI 以拟人节奏同时在跑，你实时看到双方进度赛跑；难度自适应跟随你的水平，先到 2048 或卡死时比分高者胜。** 无网络、纯本地，并为将来的真人 1v1 直连对战打好 UI 与规则地基。

## 目标

- 让用户**随时**有一局有对抗感的 2048 可玩（永远不用等人），作为「留人器」飞轮的核心。
- 产出可被子项目 C（真人 1v1）**直接复用**的对战屏与胜负规则：把「对手」从 AI 换成远端 peer 即可。
- 全程纯本地、确定性、可单测；不引入任何网络或账号。

## 依赖既有代码

- `Sources/Engine/`：`GameEngine`（`move(_:using:)`、`newGame(using:)`、`isTerminated`、`biggestTile`、`score`、`tiles`）、`Tile`、`Direction`、`Position`、`MoveResult`。
- `Sources/UI/`：`BoardView`、`TileView`、`Theme`、`Shell`（微信风 token）。
- 测试：`Tests/SeededRNG.swift`（现仅在测试目标）。**需上移到 Sources**（见组件 1）。

## 组件设计

新增 `Sources/Versus/` 模块（纯逻辑为主）+ UI 一屏。核心原则：**AI 与难度控制是纯函数式、可单测；AI 的推进步进可被测试直接驱动（不依赖真实计时器）。**

```
Sources/
├── Engine/
│   └── SeededRNG.swift        # 从 Tests 上移：确定性 RNG（同种子竞速的地基）
├── Versus/                    # 新增
│   ├── AI2048.swift           # 纯逻辑：expectimax + 启发式，按 knobs 选一步
│   ├── DifficultyController.swift # 纯逻辑：橡皮筋 DDA，按分差产出 AI knobs
│   └── VersusController.swift # @MainActor @Observable：双引擎同种子编排 + 胜负
├── UI/
│   └── VersusView.swift       # 你的大盘 + AI 小盘 + 双分/进度 + 结果（微信风）
Tests/
│   ├── AI2048Tests.swift
│   ├── DifficultyControllerTests.swift
│   └── VersusControllerTests.swift
```

### 1. SeededRNG 上移（同种子地基）

把 `Tests/SeededRNG.swift` 移到 `Sources/Engine/SeededRNG.swift`（`struct SeededRNG: RandomNumberGenerator`，`init(state:)`）。双方引擎各持一个**用相同种子初始化**的 `SeededRNG`：随机流一致，方块生成的「运气流」相同，棋盘分化只来自双方**走子选择**（即纯技巧）。既有测试对它的引用不变（同 target 内仍可见）。

### 2. AI2048（纯逻辑）

```
enum AI2048 {
    struct Knobs { var depth: Int; var blunderRate: Double }  // depth≥1；blunderRate∈[0,1]
    static func chooseMove<R: RandomNumberGenerator>(
        _ engine: GameEngine, knobs: Knobs, using rng: inout R
    ) -> Direction?
}
```

- **expectimax**：对四个方向，在引擎副本上模拟「我方走一步 + 随机生成」的期望价值，递归到 `depth` 层；用启发式给叶子局面打分。
- **启发式**（加权和）：空格数、单调性（大数聚一角的排列）、平滑度（相邻数接近）、最大数在角。权重为常量，注释说明。
- **blunderRate**：以概率 `blunderRate` 用 `rng` 从合法走法里**随机**选一步（而非最优），实现「失误」；`0` = 尽力，`1` = 纯随机。
- 无合法走法返回 `nil`。纯函数、注入 RNG、可单测。

### 3. DifficultyController（纯逻辑，橡皮筋 DDA）

```
struct DifficultyController {
    // 边界：保证「更强的人」仍会赢——AI 的帮扶有上限。
    init(minDepth: Int = 1, maxDepth: Int = 4,
         minBlunder: Double = 0.0, maxBlunder: Double = 0.6, step: Double = 0.08)
    private(set) var knobs: AI2048.Knobs
    // 每步按分差调整：gap = humanScore - aiScore
    mutating func update(scoreGap: Int) -> AI2048.Knobs
}
```

- **橡皮筋**：人领先（`gap>0`）→ **增强 AI**（`blunderRate` 向 `minBlunder` 收、`depth` 向 `maxDepth` 升）；人落后（`gap<0`）→ **放水**（`blunderRate` 向 `maxBlunder` 升、`depth` 向 `minDepth` 降）。变化每步以 `step` 平滑逼近，避免突兀。
- **有界帮扶**：`blunderRate` 封顶 `maxBlunder`（如 0.6），即 AI 再放水也不会纯随机——**明显更强的人依然稳赢**，技巧仍然决定胜负，DDA 只让比分「贴身」。
- 纯值类型、可单测（喂分差断言 knobs 方向与夹紧）。

### 4. VersusController（@MainActor @Observable）

```
@MainActor @Observable final class VersusController {
    enum Result { case youWin, aiWin, draw }
    private(set) var humanTiles: [Tile]
    private(set) var aiTiles: [Tile]
    private(set) var humanScore: Int
    private(set) var aiScore: Int
    private(set) var result: Result?

    init(seed: UInt64, aiTickInterval: Duration = .milliseconds(900))
    func moveHuman(_ direction: Direction)   // 玩家滑动：推进人方引擎 + 动画
    func stepAI()                            // 推进 AI 一步（测试可直接驱动；计时器也调它）
    func start() / func stop()               // 启停 AI 拟人节奏计时器（调用 stepAI）
}
```

- 持有 `humanEngine`、`aiEngine`（各一个 `SeededRNG(state: seed)`，**同种子**）与一个 `DifficultyController`。
- `stepAI()`：`knobs = difficulty.update(scoreGap: humanScore - aiScore)` → `AI2048.chooseMove(aiEngine, knobs:, using: aiRNG)` → 应用到 `aiEngine` → 刷新 `aiTiles/aiScore` → 判胜负。**把 AI 步进与计时器解耦**：计时器只周期性调 `stepAI()`，测试可手动逐步调用，无需真实时间。
- **胜负**：任一方率先出现 2048 方块 → 该方胜，`result` 立即置位、停表；否则当**双方引擎都 `isTerminated`** → 比分高者胜、相等为 `draw`。（一方先卡死则等另一方结束或达 2048。）
- 拟人节奏：`aiTickInterval`（默认约 0.9s/步）让 AI 看起来在「同时玩」，也省电（非全速搜索刷屏）。

### 5. VersusView（UI，微信风）

- 顶部：你 vs AI 的双分 + 进度（各自最大方块 / 分数）。
- 主体：**你的大盘**（复用 `BoardView`，接你的滑动手势）+ **AI 小盘**（缩小镜像，实时反映 AI）。
- 结果：克制的胜/负/平覆盖层 + 「再来一局」（换新种子重开）。
- 入口：从（未来的）首页「跟 AI 对战」进入；本子项目可先挂一个临时入口按钮，Shell/IA 子项目再归位。

### 6. Persistence（最小）

- 可选记录累计战绩 `versusWins` / `versusLosses`（`GameStorage` 扩展，`Int`）。MVP 仅此，或先不做。

## 数据流

1. 进入对战 → 选一个 `seed`（随机或每日窗口）→ `VersusController(seed:)` 建双引擎（同种子各两个初始方块，双方起始盘一致）。
2. `start()` 启动 AI 拟人计时器。
3. 玩家滑动 → `moveHuman` 推进人方引擎、动画、刷新分数。
4. 计时器周期性 `stepAI()`：按当前分差算 knobs → AI 选步 → 推进 AI 引擎。
5. 任一方到 2048 或双方卡死 → 结算 `result` → 覆盖层 → 「再来一局」。

## 错误处理与边界

- 玩家在结算后仍滑动 → 忽略（`result != nil` 时 `moveHuman` 无操作）。
- AI 无合法走法（先卡死）→ 停其步进，等玩家结束或达标再结算。
- 同种子公平性：双方各自独立但**同种子**的 RNG，运气流一致；分化只来自走子。
- 难度帮扶有界：`blunderRate` 封顶，明显更强的人稳赢（防止 DDA 变成「AI 放水送」）。

## 测试

- **AI2048（纯单测）**：构造局面，`blunderRate=0, depth≥2` 时选出合理走法（有合并优势时走合并；仅一条不致死路时避开致死）；注入 `SeededRNG` 保证确定性；`blunderRate=1` 时走法落在合法集内。
- **DifficultyController（纯单测）**：人领先 → knobs 变强（blunder↓/depth↑）；人落后 → 变弱且**夹紧在边界**（blunder≤maxBlunder、depth≥minDepth）；逐步平滑（每次变化 ≤ step 尺度）。
- **VersusController（单测）**：同种子确定性（两引擎同种子 + 同一串走子 → 完全相同棋盘）；胜负规则（先到 2048 判胜、双方卡死比分定序、相等为 draw）；`result != nil` 后 `moveHuman` 无效。用 `stepAI()` 手动驱动，无需真实时间。
- 沿用 Swift Testing 风格；复用上移后的 `SeededRNG`。

## 不做的事（子项目 A YAGNI）

- **不做**任何网络 / 蓝牙 / 真人对战（那是子项目 B/C）。
- **不做**聊天（子项目 D）。
- **不做**除 2048 外的游戏类型（同框架后扩展）。
- **不做**皮肤 / 段位 / 复杂战绩系统 / 云同步。
- **不做**端侧大模型——AI 是确定性搜索 bot。

## 为子项目 C 预留的接口

`VersusController` 的「对手」抽象：当前对手 = 本地 `AI2048 + DifficultyController` 驱动 `aiEngine`。子项目 C 只需把「对手一步从哪来」从「本地 AI 计算」换成「远端 peer 通过连接送来的走子」，双分/进度/胜负/对战屏全部复用。设计 `stepAI()` 与对手推进解耦，正是为此。
