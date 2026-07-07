# 2048 纯 Swift App 设计文档

日期：2026-07-07
仓库：https://github.com/dayuer/2048.git

## 目标

把 [gabrielecirulli/2048](https://github.com/gabrielecirulli/2048)（原版网页游戏）改写为纯 Swift 的 iOS app：

- 纯 Swift + SwiftUI，无任何第三方依赖
- 无广告、无内购、无统计 SDK
- 接入 Game Center，两个排行榜：最高分、最大方块
- 目标平台：iPhone + iPad（通用），最低 iOS 17

## 原版游戏规则（移植依据）

研究自原版 `js/game_manager.js` / `grid.js` / `tile.js`：

1. 4×4 网格，开局随机生成 2 个方块。
2. 每次生成的方块：90% 概率为 2，10% 概率为 4，位置在随机空格。
3. 滑动时，按方向向量构建遍历顺序（朝滑动方向最远端的先处理），每个方块滑到最远可达空位；若前方相邻方块数值相同**且本次滑动尚未合并过**，则合并为双倍值（每个方块每次滑动最多参与一次合并）。
4. 得分 = 累加每次合并产生的新方块值。
5. 只有当至少一个方块实际移动了，才生成新随机方块。
6. 合并出 2048 时标记胜利，弹出胜利提示，可选择「继续玩」（keep playing）。
7. 无空格且相邻无同值方块时游戏结束。
8. 持久化：当前局面实时存档（game over 时清除存档），最高分永久保存；重新打开 app 恢复上次局面。

## 架构

> 遵循 [GridGame 公共底座（基本法）](2026-07-08-gridgame-foundation-design.md)：`GameEngine` conform `GridGameEngine`，`MoveResult` 对齐为基本法的 `Resolution`/`Beat`（滑动→`moves`、合并→`transforms`、生成→`spawns`）。

四层模块，游戏逻辑与 UI 完全分离：

```
Sources/
├── App/            # App 入口、根视图
├── Engine/         # 纯逻辑，无 UI 依赖，可单元测试
├── Persistence/    # UserDefaults 存档
├── GameCenter/     # GameKit 认证与排行榜
└── UI/             # SwiftUI 视图
```

### Engine（纯逻辑）

- `Tile`：`id: UUID`（稳定标识，供 SwiftUI 动画追踪）、`value: Int`、`position: Position`
- `Position`：`(x, y)`，Codable、Hashable
- `Direction`：up / down / left / right，含移动向量
- `GameEngine`（struct 或 final class）：
  - `tiles: [Tile]`、`score: Int`、`won: Bool`、`over: Bool`、`keepPlaying: Bool`
  - `move(_ direction: Direction) -> MoveResult`：忠实移植原版算法（遍历顺序、最远位置、单次合并约束）
  - `MoveResult`：是否移动、合并事件列表（供 UI 做 pop 动画和飘分）、新生成方块
  - RNG 通过 `RandomNumberGenerator` 协议注入，测试时用固定种子
  - 整个引擎 `Codable`，直接用于存档
- 胜利判定：合并出 2048；结束判定：无空格且四方向相邻无同值

### Persistence

- `GameStorage`：`UserDefaults` + `Codable`
  - `gameState`：当前局面（game over 时清除，与原版语义一致）
  - `bestScore: Int`、`biggestTile: Int`（历史最大方块，供排行榜）

### GameCenter

- `GameCenterManager`（`@Observable`）：
  - 启动时 `GKLocalPlayer.local.authenticateHandler` 认证
  - 排行榜 ID 常量：`best_score`、`biggest_tile`
  - 最高分 / 最大方块刷新时 `GKLeaderboard.submitScore` 提交
  - 提供打开 Game Center 排行榜面板的方法（`GKGameCenterViewController` 包装）
  - 未登录 / 提交失败静默降级，不打断游戏
- 工程配置：`com.apple.developer.game-center` entitlement
- ⚠️ 手动步骤：需在 App Store Connect 创建 app 及两个排行榜 ID 后排行榜才真正生效

### UI（SwiftUI）

复刻原版视觉：

- 配色：背景 `#faf8ef`、棋盘 `#bbada0`、空格 `rgba(238,228,218,0.35)`、方块按数值取原版调色板（2 → `#eee4da` … 2048 → `#edc22e`，超过 2048 用 `#3c3a32`），数值 ≤4 深色文字、≥8 白色文字
- `GameView`（根）：标题「2048」、分数/最高分卡片、New Game 按钮、排行榜按钮、棋盘、说明文字
- `BoardView`：`GeometryReader` 计算格子尺寸；背景层画 16 个空格，前景层按 `Tile.id` 渲染方块；位移用 spring 动画（~100ms），合并 pop 弹跳，新方块 scale-in
- 飘分动画：合并加分时分数卡片上方飘 `+N`
- 胜利/失败遮罩：半透明覆盖层，「You win! / Game over!」+「Keep going / Try again」按钮
- 输入：`DragGesture` 判定四方向滑动；`onKeyPress` 支持 iPad 外接键盘方向键
- 状态桥接：`GameViewModel`（`@Observable`）持有 engine，处理 move → 存档 → 提交 Game Center 的编排

### 工程化

- XcodeGen `project.yml` 生成 `.xcodeproj`
- Bundle ID：`com.dayuer.game2048`，显示名「2048」
- Targets：app + unit tests
- App 图标：程序化生成原版风格图标（`#edc22e` 底 + 白色「2048」）

## 测试

- Swift Testing 单元测试，覆盖 Engine：
  - 各方向移动与合并正确性（含单次合并约束，如 `[2,2,2,2] → [4,4]`）
  - 得分累加、胜利判定、game over 判定
  - 无移动时不生成新方块
  - Codable 序列化往返
- UI 通过模拟器构建 + 手动验证

## 不做的事（YAGNI）

- 无广告、无内购、无第三方 SDK
- 无 undo、无多种棋盘尺寸、无主题切换
- 不做 macOS / watchOS / visionOS
