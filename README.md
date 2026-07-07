# 2048 · 离线时刻伴侣

一个本地优先的「离线 Session（断网时段）」伴侣，以经典 [2048](https://github.com/gabrielecirulli/2048) 为第一个核心玩法。卖的不是游戏，而是「被好好度过的断网时间」——无广告、无账号、无云端牵引。

## 2048 本体

- 忠实移植原版规则与视觉（滑动合并、90%/10% 生成、单次合并约束、Keep going）
- 无广告、无第三方依赖 —— 只用 SwiftUI + StoreKit + GameKit
- Game Center 双排行榜：**最高分**、**最大方块**
- 断点续玩：退出后自动恢复上次局面
- iPhone + iPad 通用，支持外接键盘方向键，最低 iOS 17

## 离线时刻伴侣 V1（Session 外壳）

在 2048 之上生长出的「断网时间容器」，美学走「墨上留白（Ink-on-Void）」：深墨底、暖白墨、单一克制的黄铜点缀，安静、克制、无红点无 badge。

- **Session 主轴**：`setup`（开始一个断网时段，可选设时长）→ `active`（安静环境，2048 承载其中）→ `landed`（克制的「你已落地」+ 本地统计 + 自愿同步）。
- **进度绝不丢失**：pause/resume 与切后台每步立即存档。
- **诚实变现 Journey Pass**：StoreKit 2 一次性买断，**永久解锁 Session 模式**；**2048 本体永久免费，永不被付费墙拦住**。权益本地持久化，此后完全离线可用，支持恢复购买。
- **可选离线轻提示**：`NWPathMonitor` 检测到离线时轻提示「要开始一个 Session 吗？」，可永久关闭，绝不强依赖飞行检测。

## 构建

需要 Xcode 26+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）：

```bash
xcodegen generate
open Game2048.xcodeproj
```

命令行构建与测试：

```bash
xcodebuild test -project Game2048.xcodeproj -scheme Game2048 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

> StoreKit 购买闭环用本地 `Config/JourneyPass.storekit` 配置。Xcode / iOS 26.x 下 `xcodebuild test`（命令行）无法把该配置推送到模拟器 `storekitd`（Apple FB22237318），因此 `JourneyPassStoreIntegrationTests` 在命令行会被记为 *known issue*（不判失败）；在 **Xcode 内按 Cmd+U** 运行可真正验证购买 → 权益 → 恢复。纯逻辑（离线权益、状态机、存档）在命令行稳定全绿。

## Game Center 配置

代码已内置认证与分数提交，排行榜生效需要在 App Store Connect 完成：

1. 创建 app（Bundle ID `com.dayuer.game2048`）并开启 Game Center；
2. 创建两个排行榜，ID 分别为 `best_score`（最高分）和 `biggest_tile`（最大方块），
   与 `Sources/GameCenter/GameCenterManager.swift` 中的 `LeaderboardID` 常量对应；
3. 在 Xcode 中选择自己的开发者 Team 后真机运行验证登录。

未登录 Game Center 时游戏功能不受影响，分数提交静默跳过。

## 项目结构

```
Sources/
├── App/            # 入口、entitlements、图标
├── Engine/         # 2048 核心规则（纯逻辑、Codable、RNG 注入）
├── Session/        # 断网时段状态机 + SessionController 编排 + 离线提示（纯逻辑，可单测）
├── Monetization/   # Journey Pass（StoreKit 2 非消耗型 IAP，权益本地持久化）
├── Persistence/    # UserDefaults 存档（局面 / Session / Pass 权益）
├── GameCenter/     # GameKit 认证与排行榜（Session 语境下自愿、非门槛）
└── UI/             # SwiftUI 视图：2048 本体 + Session 外壳（墨上留白）
Config/             # JourneyPass.storekit 本地测试配置
Tests/              # Swift Testing 单元测试
```

## 致谢

游戏设计来自 Gabriele Cirulli 的 [2048](https://github.com/gabrielecirulli/2048)（MIT License）。
