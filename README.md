# 2048

经典 [2048](https://github.com/gabrielecirulli/2048) 游戏的纯 Swift / SwiftUI 移植版。

- 忠实移植原版规则与视觉（滑动合并、90%/10% 生成、单次合并约束、Keep going）
- 无广告、无内购、无第三方依赖 —— 只用 SwiftUI + GameKit
- Game Center 双排行榜：**最高分**、**最大方块**
- 断点续玩：退出后自动恢复上次局面
- iPhone + iPad 通用，支持外接键盘方向键，最低 iOS 17

## 构建

需要 Xcode 26+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）：

```bash
xcodegen generate
open Game2048.xcodeproj
```

命令行构建与测试：

```bash
xcodebuild test -project Game2048.xcodeproj -scheme Game2048 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO
```

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
├── Engine/         # 核心规则（纯逻辑、Codable、RNG 注入、19 个单测覆盖）
├── Persistence/    # UserDefaults 存档
├── GameCenter/     # GameKit 认证与排行榜
└── UI/             # SwiftUI 视图与动画
Tests/              # Swift Testing 单元测试
```

## 致谢

游戏设计来自 Gabriele Cirulli 的 [2048](https://github.com/gabrielecirulli/2048)（MIT License）。
