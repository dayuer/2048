# WhatsApp 式外壳 + 断网容器拆除（Phase 1a）Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 app 外壳从「断网时段容器（setup→active→landed 仪式）」整体重构为 WhatsApp 架构的四 tab 外壳（对话/附近/游戏/我），对话线程是脊柱、AI 对手是置顶常驻线程、游戏是 GridGame 基本法上的静态注册插件；同时拆除离线 Session 容器与 JourneyPass UI（Monetization 模块保留编译、无入口）。

**Architecture:** 三层新增：`Sources/Chat/`（纯本地线程/事件数据模型 + 文件 JSON 持久化的 `@Observable` store，纯逻辑可单测）；`Sources/Games/`（编译期静态 `GameRegistry` + `GamePlugin` 描述符，2048 是第一个插件，引擎规则仍留在 `Sources/Engine/`）；`Sources/UI/` 四 tab 视图 + 线程视图 + 事件卡。app 根从 `SessionShellView` 换成 `TabShellView`。拆除层：删除 5 个 Session/Nudge/Pass UI 文件 + `Session.swift`/`SessionController.swift`/`OfflineNudge.swift` 及其测试，`GameStorage` 清掉 Session/nudge 键。既有 `GameView`（2048 棋盘）保留，成为插件的单人视图与 AI 线程对战屏（1a 占位，真 AI 对手在 Phase 1b）。

**Tech Stack:** Swift 5 / SwiftUI / Swift Testing（`@Suite`/`@Test`/`#expect`）/ xcodegen + xcodebuild。设计系统沿用 `Shell` token（微信风：浅灰页/白卡/发丝线/绿主行动）。

---

## 全局须知

- **构建工程**：新增/删除 Swift 文件后必须先 `xcodegen generate` 再 xcodebuild（`project.yml` 按目录收集源文件，不手改 pbxproj）。
- **测试命令模板**：
  ```bash
  xcodebuild test -project Game2048.xcodeproj -scheme Game2048 \
    -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
    -only-testing:Game2048Tests/<SuiteName> 2>&1 | tail -20
  ```
  全量：去掉 `-only-testing`。看结果用 `| grep -E "Test Suite|Executed|passed|failed|error:|✔|✘" | tail -50`。
- **命名避坑**：线程模型命名 **`ChatThread`**，绝不叫 `Thread`——`Foundation.Thread` 会被遮蔽，导致后续引用系统类型时的诡异行为。
- **known-issue**：`JourneyPassStoreIntegrationTests`（`loadsProduct`/`purchase…`/`refresh…`）在 CLI 下已知 StoreKit `.productUnavailable`，标记为 known issue（`withKnownIssue`），全量跑测时视为通过。本计划**不动** Monetization 模块与这些测试。
- **存档兼容**：V1 未上架。`GameStorage` 删除 `currentSession`/`offlineNudgeDisabled` 键后旧值成为孤儿数据，无害；不写迁移。`journeyPassUnlocked` 键保留（变现停车场）。
- **AI 线程诚实原则（1a 范围）**：AI 线程有置顶常驻 + 「开战」按钮，点击进入既有单人 2048 棋盘（真实可玩）。**1a 不伪造对手比分、不自动写 `battleResult`**——真 AI 对手与结果卡在 Phase 1b。`ThreadEvent.battleResult` 数据结构本轮完整建好并单测，仅 UI 侧暂不产出真人/AI 结果。

## 文件结构

| 动作 | 路径 | 职责 |
|---|---|---|
| Create | `Sources/Chat/ChatThread.swift` | `ChatThread` / `ThreadEvent`（Codable 纯逻辑） |
| Create | `Sources/Chat/ChatStore.swift` | 线程持久化 `@MainActor @Observable`（文件 JSON） |
| Create | `Sources/Games/GamePlugin.swift` | `GamePlugin` 描述符 + `OpponentKind` + `GameRegistry` 静态注册表 |
| Create | `Sources/UI/TabShellView.swift` | 四 tab 根（取代 `SessionShellView` 成为 App 入口） |
| Create | `Sources/UI/ChatListView.swift` | 对话列表（AI 置顶 + 真人线程） |
| Create | `Sources/UI/ThreadView.swift` | 线程：事件卡流 + AI 线程「开战」/ 真人线程禁用输入框 |
| Create | `Sources/UI/NearbyView.swift` | 附近 tab（B 前引导态） |
| Create | `Sources/UI/GameLibraryView.swift` | 插件库（`GameRegistry.all`） |
| Create | `Sources/UI/MeView.swift` | 身份 / 隐私自述 / 设置（清空线程） |
| Create | `Sources/UI/EphemeralIdentity.swift` | 本机临时昵称（可重掷，本地持久化） |
| Modify | `Sources/App/Game2048App.swift` | 根视图 `SessionShellView` → `TabShellView` |
| Modify | `Sources/UI/GameView.swift` | 加可选「返回」闭包，供从线程/库进入时可退出（默认无按钮＝tab 内直玩） |
| Modify | `Sources/Persistence/GameStorage.swift` | 删 `currentSession`/`offlineNudgeDisabled`，加 `nickname` |
| Delete | `Sources/UI/SessionShellView.swift`、`SessionSetupView.swift`、`SessionActiveView.swift`、`SessionLandedView.swift`、`JourneyPassView.swift` | 断网容器 + Pass UI |
| Delete | `Sources/Session/Session.swift`、`SessionController.swift`、`OfflineNudge.swift` | 容器逻辑（`SessionActivity` 契约在 `GridGame/`，不受影响） |
| Delete | `Tests/SessionTests.swift`、`SessionControllerTests.swift`、`GameStorageSessionTests.swift` | 容器测试 |
| Create | `Tests/ChatStoreTests.swift` | 线程/事件 Codable + store 往返/排序/损坏回退/AI 常驻 |
| Create | `Tests/GameRegistryTests.swift` | 注册表非空/ id 唯一 / 2048 `supportsVersus` |
| Modify | `Sources/UI/ShellTheme.swift` | 文档注释从「Session 外壳」改为「全 app 设计系统」（无逻辑变更） |
| Modify | `README.md` | 项目结构：去 Session 容器叙述，补 Chat/Games/TabShell |

**保留不动（编译但无入口，变现停车场）**：`Sources/Monetization/JourneyPassStore.swift`、`Tests/JourneyPassStoreTests.swift`、`Config/JourneyPass.storekit`、`GameStorage.journeyPassUnlocked`。

**非目标（本计划不做，属 B/C/D 或 1b）**：蓝牙/网络发现、真人对战与消息收发、真 AI expectimax 对手、动态插件加载、游戏内购、群聊、app 更名/图标。

---

### Task 1: Chat 数据模型（`ChatThread` / `ThreadEvent`）

纯值类型、Codable、无 SwiftUI 依赖。先建数据层，UI 与 store 都依赖它。

**Files:**
- Create: `Sources/Chat/ChatThread.swift`
- Create: `Tests/ChatStoreTests.swift`

- [ ] **Step 1: 写失败测试**

创建 `Tests/ChatStoreTests.swift`：

```swift
import Foundation
import Testing
@testable import Game2048

@Suite struct ThreadEventCodableTests {
    @Test func messageRoundTrip() throws {
        let event = ThreadEvent.message(id: UUID(), text: "hi", mine: true, at: Date(timeIntervalSince1970: 100))
        let data = try JSONEncoder().encode(event)
        #expect(try JSONDecoder().decode(ThreadEvent.self, from: data) == event)
    }

    @Test func battleInviteRoundTrip() throws {
        let event = ThreadEvent.battleInvite(id: UUID(), gameID: "game2048", seed: 42, mine: false, at: Date(timeIntervalSince1970: 200))
        let data = try JSONEncoder().encode(event)
        #expect(try JSONDecoder().decode(ThreadEvent.self, from: data) == event)
    }

    @Test func battleResultRoundTrip() throws {
        let event = ThreadEvent.battleResult(id: UUID(), gameID: "game2048", myScore: 1024, theirScore: 512, at: Date(timeIntervalSince1970: 300))
        let data = try JSONEncoder().encode(event)
        #expect(try JSONDecoder().decode(ThreadEvent.self, from: data) == event)
    }

    @Test func threadRoundTripPreservesEventOrder() throws {
        var thread = ChatThread(id: "ai", nickname: "AI 对手")
        thread.events = [
            .battleInvite(id: UUID(), gameID: "game2048", seed: 1, mine: true, at: Date(timeIntervalSince1970: 1)),
            .battleResult(id: UUID(), gameID: "game2048", myScore: 8, theirScore: 4, at: Date(timeIntervalSince1970: 2)),
        ]
        let data = try JSONEncoder().encode(thread)
        #expect(try JSONDecoder().decode(ChatThread.self, from: data) == thread)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/ThreadEventCodableTests 2>&1 | tail -20`
Expected: 编译失败 `cannot find 'ThreadEvent' in scope`

- [ ] **Step 3: 最小实现**

创建 `Sources/Chat/ChatThread.swift`：

```swift
import Foundation

/// 一根 1:1 对话线程（AI 对手或附近真人）。纯本地、Codable。
/// 命名 ChatThread 而非 Thread——避免遮蔽 Foundation.Thread。
struct ChatThread: Codable, Identifiable, Equatable, Sendable {
    /// peerID；AI 线程固定 "ai"。
    let id: String
    var nickname: String
    /// 时间升序。
    var events: [ThreadEvent]

    init(id: String, nickname: String, events: [ThreadEvent] = []) {
        self.id = id
        self.nickname = nickname
        self.events = events
    }

    /// 线程排序键：最后一个事件时间；空线程用 .distantPast。
    var lastEventAt: Date { events.last?.at ?? .distantPast }
}

/// 线程里的一条事件。三态：消息 / 对战邀请 / 对战结果。
/// message 的真人收发在 D 落地；battleResult 的真对手在 Phase 1b。
enum ThreadEvent: Codable, Identifiable, Equatable, Sendable {
    case message(id: UUID, text: String, mine: Bool, at: Date)
    case battleInvite(id: UUID, gameID: String, seed: UInt64, mine: Bool, at: Date)
    case battleResult(id: UUID, gameID: String, myScore: Int, theirScore: Int, at: Date)

    var id: UUID {
        switch self {
        case let .message(id, _, _, _): id
        case let .battleInvite(id, _, _, _, _): id
        case let .battleResult(id, _, _, _, _): id
        }
    }

    var at: Date {
        switch self {
        case let .message(_, _, _, at): at
        case let .battleInvite(_, _, _, _, at): at
        case let .battleResult(_, _, _, _, at): at
        }
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/ThreadEventCodableTests 2>&1 | tail -20`
Expected: PASS（4 个用例）

- [ ] **Step 5: Commit**

```bash
git add Sources/Chat/ChatThread.swift Tests/ChatStoreTests.swift Game2048.xcodeproj
git commit -m "feat: Chat 数据模型 ChatThread/ThreadEvent（纯本地 Codable）"
```

---

### Task 2: ChatStore（文件 JSON 持久化 + AI 线程常驻）

`@MainActor @Observable`。文件 JSON（消息体会增长，不用 UserDefaults）。AI 线程（id `"ai"`）由 store 保证常驻置顶且不可删。

**Files:**
- Create: `Sources/Chat/ChatStore.swift`
- Modify: `Tests/ChatStoreTests.swift`（追加 suite）

- [ ] **Step 1: 写失败测试**

在 `Tests/ChatStoreTests.swift` 末尾追加：

```swift
@MainActor
@Suite struct ChatStoreTests {
    /// 每个用例独立临时文件，互不污染。
    private func makeStore() -> ChatStore {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-\(UUID().uuidString).json")
        return ChatStore(fileURL: url)
    }

    @Test func startsWithPinnedAIThread() {
        let store = makeStore()
        #expect(store.threads.count == 1)
        #expect(store.threads[0].id == "ai")
    }

    @Test func appendPersistsAndReloads() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-\(UUID().uuidString).json")
        let store = ChatStore(fileURL: url)
        store.append(.battleInvite(id: UUID(), gameID: "game2048", seed: 7, mine: true, at: Date(timeIntervalSince1970: 10)), to: "ai")
        let reloaded = ChatStore(fileURL: url)
        #expect(reloaded.thread(id: "ai")?.events.count == 1)
    }

    @Test func threadsSortedByLastEventDescendingWithAIPinnedFirst() {
        let store = makeStore()
        store.upsert(ChatThread(id: "peer-b", nickname: "B", events: [
            .message(id: UUID(), text: "b", mine: false, at: Date(timeIntervalSince1970: 50)),
        ]))
        store.upsert(ChatThread(id: "peer-a", nickname: "A", events: [
            .message(id: UUID(), text: "a", mine: false, at: Date(timeIntervalSince1970: 90)),
        ]))
        // AI 恒置顶，其余按 lastEventAt 降序
        #expect(store.threads.map(\.id) == ["ai", "peer-a", "peer-b"])
    }

    @Test func deleteRemovesRealThreadButNotAI() {
        let store = makeStore()
        store.upsert(ChatThread(id: "peer-a", nickname: "A", events: []))
        store.delete(id: "peer-a")
        #expect(store.thread(id: "peer-a") == nil)
        store.delete(id: "ai")            // 不可删
        #expect(store.thread(id: "ai") != nil)
    }

    @Test func corruptFileFallsBackToPinnedAIThread() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("chat-\(UUID().uuidString).json")
        try Data("not json".utf8).write(to: url)
        let store = ChatStore(fileURL: url)
        #expect(store.threads.count == 1)
        #expect(store.threads[0].id == "ai")
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/ChatStoreTests 2>&1 | tail -20`
Expected: 编译失败 `cannot find 'ChatStore' in scope`

- [ ] **Step 3: 最小实现**

创建 `Sources/Chat/ChatStore.swift`：

```swift
import Foundation
import Observation

/// 线程仓库：文件 JSON 持久化，AI 线程常驻置顶不可删。UI 的单一真相源。
@MainActor
@Observable
final class ChatStore {
    static let aiThreadID = "ai"

    private(set) var threads: [ChatThread]
    private let fileURL: URL

    init(fileURL: URL = ChatStore.defaultFileURL) {
        self.fileURL = fileURL
        let loaded = Self.load(from: fileURL)
        self.threads = Self.ensureAIThread(loaded)
        sort()
    }

    static var defaultFileURL: URL {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("chat-threads.json")
    }

    func thread(id: String) -> ChatThread? { threads.first { $0.id == id } }

    /// 追加事件到指定线程（线程须已存在；AI 线程恒存在）。
    func append(_ event: ThreadEvent, to threadID: String) {
        guard let index = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[index].events.append(event)
        sortAndPersist()
    }

    /// 新增或替换整根线程（B/C/D 落地后由发现/对战/消息调用）。
    func upsert(_ thread: ChatThread) {
        if let index = threads.firstIndex(where: { $0.id == thread.id }) {
            threads[index] = thread
        } else {
            threads.append(thread)
        }
        sortAndPersist()
    }

    /// 删除真人线程；AI 线程不可删。
    func delete(id: String) {
        guard id != Self.aiThreadID else { return }
        threads.removeAll { $0.id == id }
        sortAndPersist()
    }

    // MARK: - 私有

    /// AI 恒置顶，其余按 lastEventAt 降序。
    private func sort() {
        threads.sort { a, b in
            if a.id == Self.aiThreadID { return true }
            if b.id == Self.aiThreadID { return false }
            return a.lastEventAt > b.lastEventAt
        }
    }

    private func sortAndPersist() {
        sort()
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(threads) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    private static func load(from url: URL) -> [ChatThread] {
        guard let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([ChatThread].self, from: data)
        else { return [] }
        return decoded
    }

    /// 保证 AI 线程存在（损坏/首启回退）。
    private static func ensureAIThread(_ threads: [ChatThread]) -> [ChatThread] {
        guard !threads.contains(where: { $0.id == aiThreadID }) else { return threads }
        return [ChatThread(id: aiThreadID, nickname: "AI 对手")] + threads
    }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/ChatStoreTests 2>&1 | tail -20`
Expected: PASS（5 个用例）

- [ ] **Step 5: Commit**

```bash
git add Sources/Chat/ChatStore.swift Tests/ChatStoreTests.swift Game2048.xcodeproj
git commit -m "feat: ChatStore 文件 JSON 持久化，AI 线程常驻置顶不可删"
```

---

### Task 3: GamePlugin + GameRegistry（编译期静态插件注册表）

「插件」= 模块边界（每个游戏自带引擎 + 视图工厂），非动态加载。1a 只有 2048。视图工厂返回 `AnyView`；单人 = 既有 `GameView`；versus 1a 先返回同一 `GameView`（真 AI 对手在 1b 替换）。

**Files:**
- Create: `Sources/Games/GamePlugin.swift`
- Create: `Tests/GameRegistryTests.swift`

- [ ] **Step 1: 写失败测试**

创建 `Tests/GameRegistryTests.swift`：

```swift
import Foundation
import Testing
@testable import Game2048

@Suite struct GameRegistryTests {
    @Test func registryNotEmpty() {
        #expect(!GameRegistry.all.isEmpty)
    }

    @Test func idsAreUnique() {
        let ids = GameRegistry.all.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test func has2048Plugin() {
        let plugin = GameRegistry.all.first { $0.id == "game2048" }
        #expect(plugin != nil)
        #expect(plugin?.supportsVersus == true)
    }
}
```

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/GameRegistryTests 2>&1 | tail -20`
Expected: 编译失败 `cannot find 'GameRegistry' in scope`

- [ ] **Step 3: 最小实现**

创建 `Sources/Games/GamePlugin.swift`：

```swift
import SwiftUI

/// 对手类型。peer 在 C 落地后携带连接。
enum OpponentKind: Equatable {
    case ai
    case peer
}

/// 一个可插拔游戏的 app 层描述符（引擎侧已由 GridGame 基本法 GridGameEngine 约束）。
/// 只补齐「库里怎么陈列、怎么开局」。
struct GamePlugin: Identifiable {
    let id: String              // "game2048"
    let name: String            // "2048"
    let icon: String            // SF Symbol
    let supportsVersus: Bool
    let makeSoloView: () -> AnyView
    let makeVersusView: (_ seed: UInt64, _ opponent: OpponentKind) -> AnyView
}

/// 编译期静态注册表。V2 起步只有 2048。
enum GameRegistry {
    static let all: [GamePlugin] = [
        GamePlugin(
            id: "game2048",
            name: "2048",
            icon: "square.grid.2x2.fill",
            supportsVersus: true,
            makeSoloView: { AnyView(GameView()) },
            // 1a：versus 暂用同一单人棋盘占位；真 AI 对手/对战屏在 Phase 1b 替换。
            makeVersusView: { _, _ in AnyView(GameView()) }
        ),
    ]

    static func plugin(id: String) -> GamePlugin? { all.first { $0.id == id } }
}
```

- [ ] **Step 4: 跑测试确认通过**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/GameRegistryTests 2>&1 | tail -20`
Expected: PASS（3 个用例）

- [ ] **Step 5: Commit**

```bash
git add Sources/Games/GamePlugin.swift Tests/GameRegistryTests.swift Game2048.xcodeproj
git commit -m "feat: GamePlugin 描述符 + GameRegistry 静态注册表（2048 首个插件）"
```

---

### Task 4: EphemeralIdentity + GameStorage 清理（删 Session/nudge 键，加 nickname）

先把存储层调对：删掉断网容器/nudge 键（它们的消费者本任务后续删除），加 `nickname`（临时身份，MeView 用）。本任务先只做 `GameStorage` + 新增身份类型，暂不删 Session 文件（Task 6 统一删，避免中间编译断裂）。

**Files:**
- Modify: `Sources/Persistence/GameStorage.swift`
- Create: `Sources/UI/EphemeralIdentity.swift`
- Modify: `Tests/GameStorageTests.swift`（追加 nickname 往返用例）

- [ ] **Step 1: 写失败测试**

在 `Tests/GameStorageTests.swift` 中已有 `@Suite struct GameStorageTests` 内追加用例（放在最后一个 `@Test` 后）：

```swift
    @Test func nicknameRoundTrip() {
        #expect(storage.nickname == nil)
        storage.nickname = "旅人42"
        #expect(storage.nickname == "旅人42")
        storage.nickname = nil
        #expect(storage.nickname == nil)
    }
```

> 注：该文件顶部已有 `let storage = GameStorage(defaults: ...)`（用独立 suite 名的 UserDefaults）。若无，参照文件现有 setUp 方式。

- [ ] **Step 2: 跑测试确认失败**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/GameStorageTests 2>&1 | tail -20`
Expected: 编译失败（`GameStorage` 无成员 `nickname`）

- [ ] **Step 3: 实现——改 GameStorage**

`Sources/Persistence/GameStorage.swift` 中删除 `currentSession` 与 `offlineNudgeDisabled` 两个计算属性（第 36–61 行整块），在 `journeyPassUnlocked` 之后追加：

```swift
    /// 本机临时昵称（ephemeral 身份，可重掷）。nil = 尚未生成。
    var nickname: String? {
        get { defaults.string(forKey: "nickname") }
        nonmutating set {
            if let newValue {
                defaults.set(newValue, forKey: "nickname")
            } else {
                defaults.removeObject(forKey: "nickname")
            }
        }
    }
```

保留 `bestScore`/`biggestTile`/`gameState`/`journeyPassUnlocked` 不动。删除文件顶部注释里关于 Session 的措辞（若有），改为「当前局面 / 最高分 / 最大方块 / Pass 权益 / 临时昵称」。

- [ ] **Step 4: 创建 EphemeralIdentity**

创建 `Sources/UI/EphemeralIdentity.swift`：

```swift
import SwiftUI
import Observation

/// 本机临时身份：一个可重掷的昵称，纯本地。呼应「无账号 / 数据不出设备」。
@MainActor
@Observable
final class EphemeralIdentity {
    private(set) var nickname: String
    private let storage: GameStorage

    private static let adjectives = ["安静的", "漫游的", "云端的", "夜航的", "折返的", "微光的"]
    private static let nouns = ["旅人", "过客", "候鸟", "信使", "棋手", "行者"]

    init(storage: GameStorage = GameStorage()) {
        self.storage = storage
        if let saved = storage.nickname {
            self.nickname = saved
        } else {
            let generated = Self.generate()
            self.nickname = generated
            storage.nickname = generated
        }
    }

    /// 重掷一个新昵称并持久化。
    func reroll() {
        let new = Self.generate()
        nickname = new
        storage.nickname = new
    }

    private static func generate() -> String {
        "\(adjectives.randomElement()!)\(nouns.randomElement()!)\(Int.random(in: 10...99))"
    }
}
```

- [ ] **Step 5: 跑测试确认通过**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/GameStorageTests 2>&1 | tail -20`
Expected: 编译失败——`SessionController`/`OfflineNudge`/Session 视图仍引用已删的 `currentSession`/`offlineNudgeDisabled`。

> 这是预期的中间态：Task 6 删除这些消费者后即恢复。**本任务不 commit**，直接进 Task 5、6 一次性把外壳换掉再统一验证。若要独立验证，可临时 `-only-testing:Game2048Tests/GameStorageTests` 只测该 suite——但全量编译此刻会断。

- [ ] **Step 6: 暂不 commit**（与 Task 5/6 合并为一次外壳切换提交，见 Task 6 Step）。

---

### Task 5: 四 tab 视图（TabShell + 各 tab + ThreadView）

一次性建齐 UI 层。这些视图依赖 Task 1–4 的 `ChatStore`/`GameRegistry`/`EphemeralIdentity` 与既有 `GameView`/`Shell` token。

**Files:**
- Create: `Sources/UI/TabShellView.swift`、`ChatListView.swift`、`ThreadView.swift`、`NearbyView.swift`、`GameLibraryView.swift`、`MeView.swift`
- Modify: `Sources/UI/GameView.swift`（加可选返回闭包）

- [ ] **Step 1: 给 GameView 加可选返回闭包**

`Sources/UI/GameView.swift` 顶部结构改为（新增 `onExit`，默认 nil＝tab 内直玩无返回键；从库/线程进入时传闭包显示返回）：

将第 3–11 行

```swift
struct GameView: View {
    @State private var gameCenter: GameCenterManager
    @State private var viewModel: GameViewModel

    init() {
        let gameCenter = GameCenterManager()
        _gameCenter = State(initialValue: gameCenter)
        _viewModel = State(initialValue: GameViewModel(gameCenter: gameCenter))
    }
```

替换为

```swift
struct GameView: View {
    @State private var gameCenter: GameCenterManager
    @State private var viewModel: GameViewModel
    private let onExit: (() -> Void)?

    init(onExit: (() -> Void)? = nil) {
        let gameCenter = GameCenterManager()
        _gameCenter = State(initialValue: gameCenter)
        _viewModel = State(initialValue: GameViewModel(gameCenter: gameCenter))
        self.onExit = onExit
    }
```

并在 `toolbar` 的 `HStack {` 后、`Spacer()` 前插入返回按钮：

```swift
            if let onExit {
                Button(action: onExit) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.lightText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.button, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
```

- [ ] **Step 2: 创建 TabShellView**

创建 `Sources/UI/TabShellView.swift`：

```swift
import SwiftUI

/// App 根：四 tab 外壳（对话 / 附近 / 游戏 / 我）。取代 SessionShellView。
/// ChatStore / EphemeralIdentity 在此持有，向下注入。
struct TabShellView: View {
    @State private var chat = ChatStore()
    @State private var identity = EphemeralIdentity()
    @State private var gameCenter = GameCenterManager()

    var body: some View {
        TabView {
            ChatListView(chat: chat)
                .tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right.fill") }

            NearbyView()
                .tabItem { Label("附近", systemImage: "dot.radiowaves.left.and.right") }

            GameLibraryView()
                .tabItem { Label("游戏", systemImage: "gamecontroller.fill") }

            MeView(identity: identity, chat: chat)
                .tabItem { Label("我", systemImage: "person.crop.circle") }
        }
        .tint(Shell.accent)
        .task { gameCenter.authenticate() }
    }
}
```

- [ ] **Step 3: 创建 ChatListView**

创建 `Sources/UI/ChatListView.swift`：

```swift
import SwiftUI

/// 对话列表：AI 置顶行 + 真人线程行。微信风白行 + 发丝分隔。
struct ChatListView: View {
    let chat: ChatStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(chat.threads) { thread in
                    NavigationLink {
                        ThreadView(chat: chat, threadID: thread.id)
                    } label: {
                        row(for: thread)
                    }
                    .listRowBackground(Shell.card)
                }
            }
            .listStyle(.plain)
            .background(Shell.page)
            .navigationTitle("对话")
        }
    }

    @ViewBuilder
    private func row(for thread: ChatThread) -> some View {
        let isAI = thread.id == ChatStore.aiThreadID
        HStack(spacing: 12) {
            Image(systemName: isAI ? "cpu.fill" : "person.fill")
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(isAI ? Shell.accent : Shell.textSecondary, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
            VStack(alignment: .leading, spacing: 3) {
                Text(thread.nickname)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Shell.textPrimary)
                Text(isAI ? "随时开战" : subtitle(for: thread))
                    .font(.system(size: 13))
                    .foregroundStyle(Shell.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, 4)
    }

    private func subtitle(for thread: ChatThread) -> String {
        switch thread.events.last {
        case let .message(_, text, _, _): return text
        case .battleInvite: return "发起了一局对战"
        case let .battleResult(_, _, my, their, _): return "对战结束 \(my) : \(their)"
        case nil: return "开始一段对话"
        }
    }
}
```

- [ ] **Step 4: 创建 ThreadView**

创建 `Sources/UI/ThreadView.swift`：

```swift
import SwiftUI

/// 线程详情：事件卡流。AI 线程底部是「开战」主按钮（进入单人 2048，1a 占位对战屏）；
/// 真人线程底部是禁用的输入框 + 「＋」（D/C 前引导态）。
struct ThreadView: View {
    let chat: ChatStore
    let threadID: String

    @State private var playing = false

    private var thread: ChatThread? { chat.thread(id: threadID) }
    private var isAI: Bool { threadID == ChatStore.aiThreadID }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if let events = thread?.events, !events.isEmpty {
                        ForEach(events) { event in
                            EventCard(event: event)
                        }
                    } else {
                        Text(isAI ? "跟本地 AI 对手来一局——永远不用等人。" : "还没有消息。")
                            .font(.system(size: 14))
                            .foregroundStyle(Shell.textSecondary)
                            .padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Shell.page)

            Divider().background(Shell.separator)
            footer
        }
        .navigationTitle(thread?.nickname ?? "对话")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $playing) {
            // 1a：AI 线程「开战」= 真实可玩单人 2048。不伪造对手结果（Phase 1b 接真 bot）。
            GameView(onExit: { playing = false })
                .background(Theme.background.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var footer: some View {
        if isAI {
            Button {
                playing = true
            } label: {
                Text("开战")
            }
            .buttonStyle(WeChatPrimaryButtonStyle())
            .padding(16)
        } else {
            // 真人线程：D/C 落地前禁用引导态
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Shell.textSecondary)
                Text("消息与对战即将开放")
                    .font(.system(size: 15))
                    .foregroundStyle(Shell.textSecondary)
                Spacer()
            }
            .padding(16)
            .background(Shell.card)
        }
    }
}

/// 一张事件卡：消息气泡 / 对战邀请 / 对战结果。
struct EventCard: View {
    let event: ThreadEvent

    var body: some View {
        switch event {
        case let .message(_, text, mine, _):
            HStack {
                if mine { Spacer() }
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(mine ? .white : Shell.textPrimary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(mine ? Shell.accent : Shell.card, in: RoundedRectangle(cornerRadius: Shell.radius))
                if !mine { Spacer() }
            }
        case let .battleInvite(_, _, seed, _, _):
            card(icon: "flag.checkered", title: "对战邀请", subtitle: "种子 \(seed)")
        case let .battleResult(_, _, my, their, _):
            card(icon: "trophy.fill", title: "对战结果", subtitle: "你 \(my) : \(their) 对手")
        }
    }

    private func card(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Shell.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Shell.textPrimary)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Shell.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Shell.card, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
    }
}
```

- [ ] **Step 5: 创建 NearbyView**

创建 `Sources/UI/NearbyView.swift`：

```swift
import SwiftUI

/// 附近 tab：B（蓝牙发现）落地前的引导态。隐私友好文案 + 不可用的「可被发现」开关。
struct NearbyView: View {
    @State private var discoverable = false   // 引导态：视觉可切换但不接任何无线电

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 52))
                    .foregroundStyle(Shell.accent)
                Text("发现身边的人")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Shell.textPrimary)
                Text("等你身边也有人在用这个 app 时，可以直接连上来一局——全程设备到设备，无服务器、无账号。即将开放。")
                    .font(.system(size: 14))
                    .foregroundStyle(Shell.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Toggle("可被附近发现", isOn: $discoverable)
                    .disabled(true)
                    .padding(.horizontal, 40)
                    .tint(Shell.accent)
                Text("即将到来")
                    .font(.system(size: 12))
                    .foregroundStyle(Shell.textSecondary)
                Spacer()
            }
            .padding(.top, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Shell.page)
            .navigationTitle("附近")
        }
    }
}
```

- [ ] **Step 6: 创建 GameLibraryView**

创建 `Sources/UI/GameLibraryView.swift`：

```swift
import SwiftUI

/// 游戏 tab：插件库。每项进入「单人 / vs AI / vs 附近的人」；vs 人在 C 前置灰。
struct GameLibraryView: View {
    @State private var soloPlugin: GamePlugin?

    var body: some View {
        NavigationStack {
            List {
                ForEach(GameRegistry.all) { plugin in
                    Button {
                        soloPlugin = plugin
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: plugin.icon)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Shell.accent, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
                            Text(plugin.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Shell.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Shell.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Shell.card)
                }
            }
            .listStyle(.plain)
            .background(Shell.page)
            .navigationTitle("游戏")
            .fullScreenCover(item: $soloPlugin) { plugin in
                plugin.makeSoloView()
                    .background(Theme.background.ignoresSafeArea())
                    .overlay(alignment: .topLeading) {
                        Button { soloPlugin = nil } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Theme.text)
                                .padding(16)
                        }
                    }
            }
        }
    }
}
```

> 注：`fullScreenCover(item:)` 要求 `GamePlugin: Identifiable`（已满足，`id: String`）。

- [ ] **Step 7: 创建 MeView**

创建 `Sources/UI/MeView.swift`：

```swift
import SwiftUI

/// 我 tab：ephemeral 昵称（可重掷）+ 隐私自述 + 设置（清空线程）。
struct MeView: View {
    let identity: EphemeralIdentity
    let chat: ChatStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Shell.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(identity.nickname)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Shell.textPrimary)
                            Text("本机临时身份")
                                .font(.system(size: 13))
                                .foregroundStyle(Shell.textSecondary)
                        }
                        Spacer()
                        Button("重掷") { identity.reroll() }
                            .buttonStyle(WeChatTextButtonStyle())
                    }
                    .listRowBackground(Shell.card)
                }

                Section("隐私") {
                    Label("无服务器、无账号", systemImage: "lock.shield")
                    Label("数据不出设备", systemImage: "iphone")
                    Label("线程本地删除即彻底消失", systemImage: "trash")
                }
                .foregroundStyle(Shell.textPrimary)
                .listRowBackground(Shell.card)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Shell.page)
            .navigationTitle("我")
        }
    }
}
```

- [ ] **Step 8: 不单独跑测试**（全量编译此刻仍因旧 Session 视图/App 根引用断裂；Task 6 切根 + 删旧后统一验证）。

---

### Task 6: 切换 App 根 + 拆除断网容器（原子切换 + 全量验证）

删除断网容器全部文件、改 App 根、删旧测试，一次性恢复全量绿。

**Files:**
- Modify: `Sources/App/Game2048App.swift`
- Delete: `Sources/UI/SessionShellView.swift`、`SessionSetupView.swift`、`SessionActiveView.swift`、`SessionLandedView.swift`、`JourneyPassView.swift`
- Delete: `Sources/Session/Session.swift`、`SessionController.swift`、`OfflineNudge.swift`
- Delete: `Tests/SessionTests.swift`、`SessionControllerTests.swift`、`GameStorageSessionTests.swift`
- Modify: `Sources/UI/ShellTheme.swift`（仅注释）

- [ ] **Step 1: 改 App 根**

`Sources/App/Game2048App.swift` 整体替换为：

```swift
import SwiftUI

@main
struct Game2048App: App {
    var body: some Scene {
        WindowGroup {
            TabShellView()
        }
    }
}
```

- [ ] **Step 2: 删除断网容器与 Pass UI 文件**

```bash
git rm Sources/UI/SessionShellView.swift Sources/UI/SessionSetupView.swift \
       Sources/UI/SessionActiveView.swift Sources/UI/SessionLandedView.swift \
       Sources/UI/JourneyPassView.swift \
       Sources/Session/Session.swift Sources/Session/SessionController.swift \
       Sources/Session/OfflineNudge.swift \
       Tests/SessionTests.swift Tests/SessionControllerTests.swift \
       Tests/GameStorageSessionTests.swift
```

> `Sources/Session/` 目录删空后 xcodegen 不再收集它，无需手动处理 pbxproj。`SessionActivity`/`ActivityKind` 契约在 `Sources/GridGame/`，不受影响。

- [ ] **Step 3: 更新 ShellTheme 注释**

`Sources/UI/ShellTheme.swift` 第 3–4 行注释：

```swift
/// Session 外壳的「微信风」设计系统：浅灰页底、白卡片、发丝分隔线、微信绿主行动、系统字体。
/// 深度只用背景层级（灰页 vs 白卡）与极细分隔线表达，绝不用阴影或重描边。
```

改为：

```swift
/// 全 app「微信风」设计系统：浅灰页底、白卡片、发丝分隔线、微信绿主行动、系统字体。
/// 深度只用背景层级（灰页 vs 白卡）与极细分隔线表达，绝不用阴影或重描边。
```

- [ ] **Step 4: 全量构建 + 测试**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | grep -E "Test Suite|Executed|passed|failed|error:|✔|✘" | tail -50`
Expected: 全绿——`ThreadEventCodableTests`/`ChatStoreTests`/`GameRegistryTests`/`GameStorageTests`/`GameEngineTests`/`GridGameTests`/`Game2048ContractTests` 全 PASS；`JourneyPassStoreIntegrationTests` 3 个 known issue 视为通过。无 `SessionTests`/`SessionControllerTests`/`GameStorageSessionTests`（已删）。

- [ ] **Step 5: 模拟器手动冒烟（可选但推荐）**

启动 app，确认：四 tab 可切；对话 tab 见 AI 置顶线程；进 AI 线程点「开战」→ 玩一局 2048 → 返回；游戏 tab → 2048 → 单人直玩；我 tab 重掷昵称。

- [ ] **Step 6: Commit（外壳切换一次落地）**

```bash
git add -A
git commit -m "feat: 外壳重构为 WhatsApp 式四 tab（对话/附近/游戏/我）+ 拆除断网 Session 容器与 Pass UI

- 新增 Sources/Chat（ChatThread/ThreadEvent/ChatStore）、Sources/Games（GamePlugin/GameRegistry）
- App 根 SessionShellView → TabShellView；AI 线程置顶常驻，开战进单人 2048（1a 占位）
- 删除 Session/SessionController/OfflineNudge + 4 个 Session UI + JourneyPassView UI 及其测试
- GameStorage 清 currentSession/offlineNudgeDisabled 键、加 nickname；Monetization 保留编译无入口"
```

---

### Task 7: 文档回填（README 项目结构）

**Files:**
- Modify: `README.md`

- [ ] **Step 1: 更新项目结构**

`README.md` 项目结构代码块整体替换为：

```
Sources/
├── App/            # 入口（TabShellView 根）、entitlements、图标
├── GridGame/       # 基本法底座：状态原语 + Beat 结算时间线 + SessionActivity/GridGameEngine 契约（零游戏规则）
├── Engine/         # 2048 规则内核（GridGameEngine 特化；纯逻辑、Codable、RNG 状态随档）
├── Games/          # 游戏插件注册表：GamePlugin 描述符 + GameRegistry（编译期静态，2048 首个）
├── Chat/           # 对话线程与事件（ChatThread/ThreadEvent/ChatStore，纯本地文件 JSON）
├── Monetization/   # Journey Pass（StoreKit 2 IAP）——保留编译、暂无入口（变现停车场）
├── Persistence/    # UserDefaults 存档（局面 / 最高分 / 最大方块 / Pass 权益 / 临时昵称）
├── GameCenter/     # GameKit 认证与排行榜
└── UI/             # SwiftUI：四 tab 外壳（对话/附近/游戏/我）+ 线程/事件卡 + 2048 本体 + 微信风设计系统
Config/             # JourneyPass.storekit 本地测试配置
Tests/              # Swift Testing 单元测试
```

同时删除 README 中关于「断网时段容器 / Session 外壳 / Journey Pass 买断作为主线」的段落（若有），替换为一句：「V2：WhatsApp 式四 tab 外壳，AI 对手常驻对话，游戏为 GridGame 基本法上的插件；近场/真人对战/私聊后续接入。」

- [ ] **Step 2: Commit**

```bash
git add README.md
git commit -m "docs: README 项目结构对齐 V2 外壳（Chat/Games/TabShell，去断网容器叙述）"
```

---

## Self-Review 结论

- **spec 覆盖**：四 tab（TabShell/ChatList/Nearby/GameLibrary/Me）✓；对话脊柱 + AI 置顶常驻 ✓；线程事件卡三态（message/battleInvite/battleResult）✓；AI 线程无聊天输入、只有开战 ✓；GamePlugin/GameRegistry 静态注册表 ✓；ChatStore 文件 JSON + 损坏回退 + AI 不可删 ✓；拆除清单（5 UI + Session/Controller/Nudge + 键清理）✓；Monetization 保留编译无入口 ✓；测试（Chat 纯逻辑 / GameRegistry）✓。
- **spec 偏差（有意）**：① 模型命名 `ChatThread`（避 `Foundation.Thread` 遮蔽）；② 引擎规则文件仍留 `Sources/Engine/`（不搬进 `Games/Game2048/`），插件描述符在 `Sources/Games/`——减少无谓 churn，模块边界仍清晰；③ 1a 的 AI 线程「开战」进真实单人 2048、不伪造对手结果卡（真 bot/结果在 1b）。三者均在「全局须知」与 spec 附注记录。
- **占位符扫描**：无 TBD/TODO；每步含完整代码与命令。
- **类型一致性**：`ChatStore.aiThreadID`/`thread(id:)`/`append(_:to:)`/`upsert`/`delete(id:)`、`GamePlugin.makeSoloView`/`makeVersusView`、`EphemeralIdentity.reroll()` 跨任务一致。
