# WhatsApp 式外壳与 IA（Shell/IA）设计文档 — V2 子项目 1a

日期：2026-07-08
仓库：https://github.com/dayuer/2048.git
上位：`2026-07-08-serverless-social-v2-vision.md`。
前置：GridGame 基本法 alignment 计划落地（`Sources/GridGame/` 在建，本子项目实现前须等其收尾）。

## 一句话概念

**把 app 外壳重构为 WhatsApp 架构模式：对话列表是首页与脊柱，AI 对手是置顶常驻对话，真人对战与聊天都是 1:1 线程内的事件；四 tab（对话/附近/游戏/我）；游戏是 GridGame 基本法上的独立插件。断网容器（Session 仪式）整体拆除。**

## IA 骨架

```
TabShell（四 tab）
├── 对话（默认）  ChatListView ── ThreadView（消息气泡 + 对战事件卡）
│     ├── 置顶：AI 对手线程（无自由聊天输入，只有对局卡 + 开战）
│     └── 真人 1:1 线程（附近遇到的人；按最近事件排序）
├── 附近         NearbyView（BLE 发现的人 + 可被发现开关；B 落地前为引导态）
├── 游戏         GameLibraryView（插件库：单人 / vs AI / vs 附近的人）
└── 我           MeView(本机 ephemeral 身份 + 隐私自述 + 设置)
```

- **对战即事件**：线程里的对战邀请卡（游戏+种子 → 接受/婉拒）与结果卡（比分 + 再来一局），像 WhatsApp 的附件/通话记录。发起入口：线程输入框「＋」→ 选游戏插件。
- **AI 线程诚实原则**：AI 是游戏对手不是 LLM——AI 线程只有对局卡与「开战」按钮，无聊天输入框。
- **微信风视觉沿用**：现有 `Shell` token（浅灰页/白卡/发丝线/绿主行动）直接迁移为全 app 设计系统。

## 组件设计

```
Sources/
├── GridGame/                    # 基本法（在建，0 号前置）
├── Games/                       # 新增：插件目录
│   ├── GamePlugin.swift         # 插件描述符 + GameRegistry（静态注册表）
│   └── Game2048/                # 第一个插件（迁移既有 Engine/UI 归位）
├── Chat/                        # 新增：线程与事件（纯本地）
│   ├── Thread.swift             # Thread / ThreadEvent（Codable，纯逻辑可单测）
│   └── ChatStore.swift          # 本地持久化（文件 JSON），@Observable
├── UI/
│   ├── TabShellView.swift       # 四 tab 根（取代 SessionShellView 成为 App 入口）
│   ├── ChatListView.swift       # 对话列表（AI 置顶 + 真人线程）
│   ├── ThreadView.swift         # 线程：气泡 + 事件卡 + 「＋」发起对战
│   ├── NearbyView.swift         # B 前引导态（说明 + 开关占位）
│   ├── GameLibraryView.swift    # 插件库
│   └── MeView.swift             # 身份 / 隐私自述 / 设置
```

### 1. GamePlugin / GameRegistry（游戏插件契约）

```swift
/// 一个可插拔的游戏。引擎侧已由 GridGame 基本法约束（GridGameEngine），
/// 这里只补齐「库里怎么陈列、怎么开局」的 app 层描述。
struct GamePlugin: Identifiable {
    let id: String                 // "game2048"
    let name: String               // "2048"
    let icon: String               // SF Symbol
    let supportsVersus: Bool       // 能否 vs AI / vs 人（同种子竞速）
    let makeSoloView: () -> AnyView                 // 单人自由玩
    let makeVersusView: (_ seed: UInt64, _ opponent: OpponentKind) -> AnyView
}
enum OpponentKind { case ai; case peer /* C 落地后携连接 */ }

enum GameRegistry { static let all: [GamePlugin]   // V2 起步只有 2048
}
```

- 插件**不引入动态加载**——就是编译期静态注册表；「插件」的含义是**模块边界**：每个游戏自带引擎（conform `GridGameEngine`）+ 视图工厂，除注册表外互不相识。

### 2. Chat 数据模型（纯逻辑，可单测）

```swift
struct Thread: Codable, Identifiable {
    let id: String                 // peerID；AI 线程固定 "ai"
    var nickname: String
    var events: [ThreadEvent]      // 时间升序
    var lastEventAt: Date
}

enum ThreadEvent: Codable, Identifiable {
    case message(id: UUID, text: String, mine: Bool, at: Date)          // D 落地后有真人消息
    case battleInvite(id: UUID, gameID: String, seed: UInt64, mine: Bool, at: Date)
    case battleResult(id: UUID, gameID: String, myScore: Int, theirScore: Int, at: Date)
}
```

- `ChatStore`（`@MainActor @Observable`）：`threads` 排序视图、`append(event:to:)`、文件 JSON 持久化（UserDefaults 不适合会增长的消息体）。
- AI 线程由 store 保证常驻置顶；真人线程在 B/C/D 落地后由发现/对战/消息创建。

### 3. 各 tab 视图

- **TabShellView**：`TabView` 四页；取代 `SessionShellView` 成为 `Game2048App` 根视图。
- **ChatListView**：AI 置顶行（绿色标识 + 「随时开战」副题）+ 真人线程行（昵称/最近事件摘要/时间）。
- **ThreadView**：事件流渲染三种 `ThreadEvent`；AI 线程底部是「开战」主按钮（进入子项目 A 的对战屏），真人线程底部是输入框 + 「＋」（D 前输入框禁用置灰，「＋」可发对战邀请——C 前亦为引导态）。
- **NearbyView**：B 落地前 = 引导态（隐私友好文案 + 不可用的「可被发现」开关 + 「即将到来」）；B 落地后替换为真列表。
- **GameLibraryView**：`GameRegistry.all` 列表；每项进入「单人 / vs AI / vs 附近的人」选择（vs 人在 C 前置灰）。单人 2048 = 原免费直玩迁居于此。
- **MeView**：ephemeral 昵称（可重掷）、隐私自述卡（无服务器/无账号/数据不出设备）、设置（如清空线程）。

### 4. 拆除清单（断网容器退场）

删除：`SessionShellView` / `SessionSetupView` / `SessionActiveView` / `SessionLandedView` / `OfflineNudge` / `JourneyPassView` 的 UI 挂载（Monetization 模块与 `.storekit` 保留编译、无入口）。
`Session.swift` / `SessionController` 若 alignment 计划落地后无消费者即一并删除（`SessionActivity` 契约在 `Sources/GridGame/`，不受影响）。
`GameStorage` 中 Session/nudge 键随之清理；`journeyPassUnlocked` 保留（变现停车场）。

## 数据流（V2 第一梯队完成时）

1. 启动 → `TabShellView` → 对话 tab：AI 线程置顶（可能已有历史对局卡）。
2. 点 AI 线程 → 「开战」→ 子项目 A 对战屏（同种子 vs 本地 bot）→ 结束 → `battleResult` 事件卡落回 AI 线程。
3. 游戏 tab → 2048 → 单人自由玩 / vs AI（同一对战屏）。
4. 附近 / 真人线程：引导态，B/C/D 落地后逐步点亮。

## 错误处理与边界

- **无任何网络权限诉求**：第一梯队全程零蓝牙/零网络，附近 tab 只是引导态——不提前要权限。
- **线程存储损坏**：解码失败回退空 store（AI 线程重建），不崩溃。
- **AI 线程不可删除**；真人线程可删（本地清除即彻底消失，呼应隐私自述）。
- **横竖屏/iPad**：沿用现有 portrait 约束，tab 外壳不引入新姿态。

## 测试

- **Chat 纯逻辑单测**：`Thread`/`ThreadEvent` Codable 往返（含 enum associated values）；`ChatStore` append/排序/持久化往返/损坏回退；AI 线程常驻不可删。
- **GameRegistry 单测**：注册表非空、id 唯一、2048 插件 `supportsVersus == true`。
- **UI**：构建 + 模拟器手动验证四 tab、AI 线程开战闭环；沿用 Swift Testing。

## 不做的事（子项目 1a YAGNI）

- 不做蓝牙/网络（B）、真人对战（C）、真人消息（D）——只留好接口与引导态。
- 不做动态插件加载、游戏内购、皮肤。
- 不做群聊、通讯录、消息已读回执。
- 不做 app 更名/图标改版（发布前事项）。
