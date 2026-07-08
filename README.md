# FA 实战模拟营（内部代号：顶级掮客 / The Rainmaker）

一款面向创投/投行从业者与学习者的**商业实战模拟训练工具**：100% 依托微信式聊天 UI，在消息列表里接项目、做尽调、谈条款，维持现金流。谈判策略取材真实创投知识体系（Term Sheet 条款博弈、估值方法、谈判心理学），失败有复盘、术语可查典。单机离线、无账号、无云端——数据不出设备。

> 定位：商业/教育类沙盘模拟（对标 gamified education），非游戏分类。教学闭环 = 策略包实战 + 失败复盘报告 + 创投百科词典 + 商业史档案。

> 本项目由「无服务器社交 2048」整体转向（pivot）而来，2048 保留为游戏内的「深度工作」修炼玩法。旧定位见 `docs/superpowers/specs/2026-07-08-product-strategy.md`（已废止）。

## 核心循环（MVP）

1. **消息**里处理 NPC 日常，接项目单（消耗尽调工时）
2. 条款谈判赚佣金、攒信誉（Phase 2：筹码 × 倍率算分 + 知识型策略包）
3. **财务数据重组沙盘**（2048）产出谈判策略与商业史档案（Phase 3 挂钩）
4. 【结束今日】结算：交割佣金、扣固定开销——**现金归零即信用破产**

## 当前进度（Phase 1 已完成）

- ✅ 经营内核：资金 / 信誉 / 精力（AP）/ 每日结算 / 破产判定，纯逻辑 + 注入 RNG 确定性，全量单测
- ✅ 微信式四 tab 外壳：消息（资源条 + NPC 线程）/ 通讯录 / 发现 / 我的
- ✅ 聊天式交互：NPC 气泡、项目卡片（Deal Card）接单、系统结算通知
- ✅ Phase 2 谈判对赌：筹码 × 倍率算分、知识型策略包（无效矩阵 + NPC 嘲讽教学）、
  见好就收/交易流产、失败复盘报告
- ✅ Phase 2.5 创投百科词典：17 词条 × 4 分类，卡面 ⓘ 直达
- ✅ WhatsApp 式聊天：常驻输入框、正在输入投递节奏、未读角标、已读双勾、
  大标题列表页 + 搜索 + 筛选 chips
- ✅ Phase 3 沙盘顿悟：合成 128–2048 掉话术卡入库（谈判自动带上）、
  解锁商业绝密档案图鉴（说谎者的扑克牌/门口的野蛮人 + 传说卡）、2048 永久信誉
- ⬜ Phase 4：近场「闭门私董会」联机拼单（BLE/局域网）
- ⬜ 白银/王者卡池（防稀释、领售权、毒丸、白衣骑士、LBO 实战）

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
