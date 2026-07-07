# 舱内擂台（Mesh Cabin Ladder）V2 设计文档

日期：2026-07-08
仓库：https://github.com/dayuer/2048.git
关系：实现 V1 设计文档《离线时刻伴侣》路线图第 5 项「蓝牙 Mesh 的同舱共在」的第一个可交付切片。

## 一句话概念

**在飞机这个天然封闭场景里，用蓝牙 mesh 把同舱乘客悄悄连起来：所有人玩同一航班种子的 2048，分数经设备间「相遇即交换、缓存转发」的 gossip 汇成一张「本舱排行榜」。** 无服务器、无账号、无云端；一个人也成立，人越多榜越热。

## 为什么这样收敛（brainstorm 结论）

逐层收敛锁定了以下决策，全部服务于两个硬约束——**电量**与**密度**：

- **核心体验 = 异步对局，而非实时**。跨多跳 BLE mesh 的延迟/丢包让实时联机近乎不可行；异步彻底绕开「需要两人同时在线」，也贴合「诚实离线伴侣」的克制气质。
- **旗舰玩法 = 同种子 2048 竞速**。复用既有确定性 `GameEngine`（RNG 注入，测试里已有 `SeededRNG`）：同一种子 → 同一串方块生成 → 纯技巧公平竞速。mesh 只需搬运极小消息（种子 + 分数）。
- **匹配模型 = 舱内擂台排行榜，而非 1v1 挑战**。无需对手接受；只有你也成立（榜上就你一个），有人则榜单变热。密度鲁棒性最强。
- **传输 = CoreBluetooth BLE gossip（存储转发）**，而非 MultipeerConnectivity。BLE-only 最省电（不开 AWDL/Wi-Fi 无线电，直击 #1 风险），对异步小消息最贴合；MC 的 AWDL 耗电、~8 peer 上限、后台弱，是杀鸡用牛刀。
- **擂台免费**。参与排行榜完全免费——每多一个参与者，mesh 对所有人更密（网络效应）。付费墙拦社交会直接饿死 mesh。Journey Pass 仍锁「高质量容器 + 扩展 solo 内容库」。
- **飞轮**：solo 内容（游戏、读书）让用户留在 app → 设备保持前台、成为活跃可发现的中继节点 → 分数得以在舱内传播 → 榜单更完整 → 更有理由留下。solo 留人与 mesh 社交互为因果。

## 目标与成功标准

- **目标**：在一次航班里，让「同舱有其他离线玩家」这件事被感知、可比、可回味，且**不牺牲续航、不引入任何在线化**。
- **成功标准**（V2 验证假设）：
  1. 蓝牙关闭/无人在范围时，功能优雅降级为「只有你」的单人体验，绝不报错、绝不打断。
  2. 两台及以上设备在舱内相遇后，双方最终看到**一致**的本舱排行榜（收敛）。
  3. 全程无服务器、无账号、无 PII 离开设备；退出 Session 后本地缓存清理。
  4. mesh 运行的额外耗电在「一次航班」尺度可接受（BLE-only，前台为主）。

## 范围与分解

- **本 spec 只覆盖 Cabin Ladder（mesh + 同种子 2048 + 排行榜）这一可实现子系统。**
- **扩展 solo 内容库（更多单机游戏、读书等「留人器」）是其配套的留存轨道，但属于独立子系统**：内容/功能性质、与 mesh 网络无耦合，留作**单独的后续 spec**。本文把它作为**命名依赖**列出（飞轮的另一半），但不在此细化。
- 依赖既有 V1：Session 外壳（active 态）、`GameEngine`、`SeededRNG`、`Persistence`、`Theme`/`Shell`（微信风）。

## 组件设计

在既有分层上新增一个模块 `Mesh/`，UI 扩展一个 Session 活动。核心原则：**把 CoreBluetooth 藏在协议后面，让排行榜逻辑成为可单测的纯 CRDT。**

```
Sources/
├── Mesh/                         # 新增
│   ├── MeshTransport.swift       # 传输协议 + 消息类型（可注入模拟实现）
│   ├── BLEMeshTransport.swift    # CoreBluetooth 实现（广播/扫描/相遇/收发字节）
│   ├── LadderGossip.swift        # 纯逻辑 CRDT：合并摘要 → 收敛排行榜（可单测）
│   ├── FlightSeed.swift          # 时间窗口种子（各设备本地一致，无需协调）
│   ├── CabinIdentity.swift       # 每窗口 ephemeral 身份 + 昵称（无 PII，轮换）
│   └── LadderController.swift    # @MainActor @Observable 编排：传输×gossip×身份×种子
├── UI/
│   └── LadderView.swift          # 本舱排行榜 + 「玩今天这局」（复用 GameView/引擎）
├── Persistence/GameStorage.swift # 扩展：本窗口榜单缓存、我的最高分、舱内昵称/ID
└── Session/                      # 既有：Ladder 作为 active 态内的可选活动挂入
```

### 排行榜是一个状态型 CRDT（关键简化）

本舱排行榜 = **一张映射：`playerID → 最高分`（附时间戳）**。合并 = **对每个 key 取更高分**（分数相同用较早时间戳定序）。

- 这是一个 **LWW / grow-max map（收敛无冲突复制类型）**：任意两节点交换并合并后趋于一致，**不需要 TTL、不需要消息去重、不需要 flooding 计数**。
- 「多跳中继」是**隐式**的：B 从 A 学到 A 的条目，之后遇到 C 再把整份状态给 C——状态自然扩散全舱。
- 这让 `LadderGossip` 成为一段纯函数式、易于单测收敛性的逻辑。

### 组件契约

- `LadderEntry`（`Codable, Equatable`）：`playerID: String`、`nickname: String`、`bestScore: Int`、`updatedAt: Date`、`seedEpoch: UInt64`。
- `LadderDigest`（`Codable`）：`seedEpoch: UInt64`、`entries: [LadderEntry]`。相遇时交换当前 epoch 的整份摘要（一舱至多数百条，字节量小）。
- `LadderGossip`（`@Observable`，纯逻辑）：
  - `private(set) var ranking: [LadderEntry]`（按分数降序、时间升序）。
  - `func upsertLocal(bestScore:nickname:playerID:at:)`：写入/抬高本机条目。
  - `func merge(_ digest: LadderDigest)`：对同 epoch 逐 key 取 max 合并；忽略不同 epoch。
  - `func digest() -> LadderDigest`：导出当前状态供发送。
- `MeshTransport`（protocol）：`start()`, `stop()`, `send(_ data: Data)`（广播给当前可达对端）, `var onReceive: (Data) -> Void`, `var onPeerContact: () -> Void`（相遇即触发一次摘要交换）。
  - `BLEMeshTransport`：CoreBluetooth。同时作 peripheral（广播固定 service UUID + 一个可读/可写特征承载 `LadderDigest`）与 central（扫描该 service、连接、读写特征）。相遇 = 发现对端并完成一次特征读/写。
  - `SimulatedMeshTransport`（测试）：内存中把多个节点连成图，投递字节，用于单测收敛。
- `FlightSeed`：`static func epoch(at: Date) -> UInt64`（如按「日期 + N 小时窗口」哈希）；`static func rng(for epoch: UInt64) -> SeededRNG`。各设备本地一致，无需协调；舱的边界由 BLE 可达性天然界定。
- `CabinIdentity`：`id: String`（足够长随机，避免碰撞）、`nickname: String`（本地自动生成，如「过道 3F」风格）；按窗口持久化、窗口结束轮换（隐私）。
- `LadderController`（`@MainActor @Observable`）：持有 transport + gossip + identity + seed；`begin()`/`end()` 随 Session active 态启停；把「玩今天这局」的最高分回灌 `gossip.upsertLocal`；`onPeerContact` → 交换摘要 → `merge` → 榜单刷新；`end()` 时停止 BLE 并按隐私策略清缓存。

## 数据流

1. 进入 Session（active 态）→ `LadderController.begin()`。
2. 计算 `seedEpoch = FlightSeed.epoch(at: now)`；取回/生成 `CabinIdentity`。
3. `BLEMeshTransport.start()`：开始广播 + 扫描。
4. 用户玩「今天这局」= 同种子 2048（`GameEngine` + `FlightSeed.rng(for:)`）；刷新最高分 → `gossip.upsertLocal(...)` → 本地持久化。
5. 相遇对端（`onPeerContact`）→ 交换 `digest()` → `merge()` → `ranking` 实时更新（隐式多跳扩散）。
6. 落地 / 退出 Session → `end()`：停止 BLE、按隐私策略清理本窗口缓存与轮换身份。

## 错误处理与边界

- **蓝牙关闭 / 未授权**：克制引导「在飞行模式下保持蓝牙开启即可与同舱连接」，**可跳过**；跳过后 solo 同种子 2048 仍完整可玩，榜单显示「只有你」。
- **无人在范围**：榜单只有你，优雅降级，绝不报错。
- **后台**：iOS 后台 BLE 受限（扫描节流、后台无 local name、需已知 service UUID）；mesh **以前台为主**，后台尽力而为——这与「solo 内容留人于前台」的飞轮一致。
- **作弊 / 自报分数**：V2 接受自报（无奖励、无风险场景可接受）。**后续硬化**（独立跟进）：随分数附带压缩的走子日志，对端用同种子确定性重放校验——引擎已确定性，代价低。
- **ID 碰撞**：足够长随机 `playerID`。
- **隐私**：无 PII 离开设备；ephemeral 身份按窗口轮换；退出即清缓存；全程无服务器、无云。

## 测试

- **Gossip CRDT 收敛（纯单测，核心）**：用 `SimulatedMeshTransport` 把多节点连成图，喂乱序摘要，断言所有节点 `ranking` 收敛一致；断言 per-key 取 max、跨 epoch 忽略、时间戳定序。
- **FlightSeed 确定性单测**：同一时刻/窗口在不同实例产出相同 epoch 与相同方块序列（复用 `SeededRNG`）。
- **LadderGossip 属性**：`upsertLocal` 只增不减（不会把高分覆盖为低分）；合并幂等（重复 merge 同一摘要不变）。
- **CabinIdentity**：窗口内稳定、跨窗口轮换、持久化往返。
- **BLE 层**：抽象在协议后，`BLEMeshTransport` 以真机/模拟器手动验证（两设备相遇 → 榜单合并）；不做 CoreBluetooth 的单测。
- 复用既有 `SeededRNG` 保证同种子公平；沿用 Swift Testing 风格。

## 不做的事（V2 YAGNI）

- **不做**实时对战 / 准实时动作（mesh 延迟硬约束）。
- **不做**聊天室、1v1 挑战对局（擂台跑通后再议）。
- **不做**Android / 跨平台（iOS 先行；Android Nearby 留待路线图后期）。
- **不做**跨舱 / 跨航班 / 服务器辅助的「同航班」判定（proximity 即分组）。
- **不做**账号、云同步、排行榜上云。
- **不做**扩展 solo 内容库（独立子系统，单独 spec）——本文只作为命名依赖列出。
- **不做**分数上链 / 走子日志校验（作为已记录的后续硬化项）。

## 后续（非本 spec 范围）

1. 扩展 solo 内容库（更多确定性单机玩法、读书）——飞轮的留存另一半，独立 spec。
2. 走子日志确定性重放校验（反作弊硬化）。
3. 聊天室 / 1v1 挑战 / 表情共在等更丰富的 mesh 社交。
4. Android 端 mesh（Nearby Connections / BLE）与跨平台互通。
