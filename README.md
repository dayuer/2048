# 顶级掮客 (The Rainmaker)

一款以现代顶尖 FA（财务顾问/掮客）为主角的**文字模拟经营 + 策略卡牌**游戏。100% 依托微信式聊天 UI 展开：在消息列表里接单谈生意，维持现金流，防止破产。单机离线、无账号、无云端——数据不出设备。

> 本项目由「无服务器社交 2048」整体转向（pivot）而来，2048 保留为游戏内的「深度工作」修炼玩法。旧定位见 `docs/superpowers/specs/2026-07-08-product-strategy.md`（已废止）。

## 核心循环（MVP）

1. **消息**里处理 NPC 日常，接项目单（消耗精力 AP）
2. 谈判赚佣金、攒信誉（Phase 2 接入 Balatro 式卡牌算分）
3. **深度工作**（2048）产出谈判话术卡（Phase 3 挂钩）
4. 【结束今日】结算：交割佣金、扣固定开销——**现金归零即破产出局**

## 当前进度（Phase 1 已完成）

- ✅ 经营内核：资金 / 信誉 / 精力（AP）/ 每日结算 / 破产判定，纯逻辑 + 注入 RNG 确定性，全量单测
- ✅ 微信式四 tab 外壳：消息（资源条 + NPC 线程）/ 通讯录 / 发现 / 我的
- ✅ 聊天式交互：NPC 气泡、项目卡片（Deal Card）接单、系统结算通知
- ✅ 简化接单闭环：接单扣 AP → 次日交割发佣金 → 未接作废
- ⬜ Phase 2：谈判卡牌对赌（chips × mult 算分、见好就收/爆仓）
- ⬜ Phase 3：2048「顿悟」掉落话术卡
- ⬜ Phase 4：近场「闭门私董会」联机拼单（BLE/局域网）

## 构建

需要 Xcode 26+ 和 [XcodeGen](https://github.com/yonaskolb/XcodeGen)（`brew install xcodegen`）：

```bash
xcodegen generate
open Game2048.xcodeproj
```

命令行测试：

```bash
xcodebuild test -project Game2048.xcodeproj -scheme Game2048 \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

> StoreKit 集成测试在命令行受 Apple FB22237318 影响记为 known issue（不判失败），Xcode 内 Cmd+U 可全量验证。

## 项目结构

```
Sources/
├── App/            # 入口（RainmakerRootView 根）、entitlements、图标
├── Rainmaker/      # 经营内核：数值表/项目单/NPC 名录/引擎/存档仓库（纯逻辑、Codable）
├── UI/Rainmaker/   # 四 tab 外壳 + 聊天详情 + Deal Card + 破产结算
├── UI/             # WhatsApp 式设计系统（WA token/气泡/涂鸦画布）+ 2048 棋盘视图
├── GridGame/       # 网格游戏基本法：状态原语 + 确定性 RNG + 引擎契约
├── Engine/         # 2048 规则内核（「深度工作」玩法本体）
├── GameCenter/     # Game Center 认证与排行榜（2048 沿用）
├── Persistence/    # 2048 断点续玩存档
└── Monetization/   # 买断内购底座（保留编译，入口待 Phase 5 变现设计）
Tests/              # 引擎/存档/经营内核全量单测
```

## 设计原则

- **聊天即界面**：无 2D/3D 场景，一切玩法长在消息气泡里
- **确定性**：所有随机走注入 RNG（SplitMix64），同种子同结果，可回放
- **隐私灵魂**：零账号、零服务器、数据不出设备；不做激励视频/数据变现/FOMO 收费
