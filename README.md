# 2048 · 无服务器近场社交游戏

一个隐私优先、永远有得玩的休闲游戏 app：随时跟本地 AI 对手来一局，身边有人时还能近场直连对战。以经典 [2048](https://github.com/gabrielecirulli/2048) 为第一个游戏插件。无广告、无账号、无云端——数据不出设备。

## 2048 本体

- 忠实移植原版规则与视觉（滑动合并、90%/10% 生成、单次合并约束、Keep going）
- 无广告、无第三方依赖 —— 只用 SwiftUI + StoreKit + GameKit
- Game Center 双排行榜：**最高分**、**最大方块**
- 断点续玩：退出后自动恢复上次局面
- iPhone + iPad 通用，支持外接键盘方向键，最低 iOS 17

## V2 外壳（WhatsApp 式四 tab）

外壳走微信风视觉（浅灰页 / 白卡 / 发丝分隔 / 微信绿主行动），对话是脊柱：

- **四 tab**：对话 / 附近 / 游戏 / 我。
- **AI 对手常驻置顶**：对话列表顶部是本地 AI 对手线程，随时「开战」——永远不用等人。（真 expectimax 对手在 Phase 1b 接入；当前「开战」进入真实可玩的单人 2048。）
- **游戏即插件**：全部长在 `GridGame` 基本法（`Sources/GridGame/`）上，同一引擎契约 `GridGameEngine`。2048 是第一个插件，`GameRegistry` 编译期静态注册。
- **附近 / 真人对战 / 私聊**：蓝牙近场发现（B）、实时 1v1 对战（C）、1:1 私聊（D）后续接入；附近 tab 当前为引导态。
- **临时身份**：本机可重掷昵称，无账号、数据不出设备。

> `Sources/Monetization/`（Journey Pass 买断）保留编译但暂无入口——变现锚点后续迁移到「游戏内容 / +」。设计脉络见 `docs/superpowers/specs/2026-07-08-product-strategy.md`。

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
├── App/            # 入口（TabShellView 根）、entitlements、图标
├── GridGame/       # 基本法底座：状态原语 + Beat 结算时间线 + SessionActivity/GridGameEngine 契约（零游戏规则）
├── Engine/         # 2048 规则内核（GridGameEngine 特化；纯逻辑、Codable、RNG 状态随档）
├── Games/          # 游戏插件注册表：GamePlugin 描述符 + GameRegistry（编译期静态，2048 首个）
├── Chat/           # 对话线程与事件（ChatThread/ThreadEvent/ChatStore，纯本地文件 JSON）
├── Monetization/   # Journey Pass（StoreKit 2 非消耗型 IAP）——保留编译、暂无入口（变现停车场）
├── Persistence/    # UserDefaults 存档（局面 / 最高分 / 最大方块 / Pass 权益 / 临时昵称）
├── GameCenter/     # GameKit 认证与排行榜
└── UI/             # SwiftUI：四 tab 外壳（对话/附近/游戏/我）+ 线程/事件卡 + 2048 本体 + 微信风设计系统
Config/             # JourneyPass.storekit 本地测试配置
Tests/              # Swift Testing 单元测试
```

## 致谢

游戏设计来自 Gabriele Cirulli 的 [2048](https://github.com/gabrielecirulli/2048)（MIT License）。
