# 离线时刻伴侣（Offline Session Companion）V1 实施计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在已完成的 2048 本体之上生长出「离线 Session 外壳 + Journey Pass 买断变现」，把 2048 承载进一个有始有终、无打扰的断网时间容器。

**Architecture:** 沿用 2048 既有四层分离。新增两个纯逻辑可单测的模块 —— `Session`（断网时段状态机，注入时钟）与 `Monetization`（StoreKit 2 非消耗型 IAP，权益本地持久化）；扩展 `Persistence` 承载 Session 存档与 Pass 权益；扩展 `UI` 为 Session 外壳（setup / active / landed 三态）并把既有 `GameView` 作为 active 态的 Hero 活动嵌入。业务规则：**2048 永久免费可玩，付费解锁的是 Session 模式**（仪式容器 / 安静环境 / 落地收尾统计）。

**Tech Stack:** Swift 5 / iOS 17 / SwiftUI / `@Observable` / Swift Testing / StoreKit 2 + StoreKitTest / Network.framework（`NWPathMonitor`）/ XcodeGen。

**测试目标机：** `-destination 'platform=iOS Simulator,name=iPhone 17 Pro'`（本机可用且已 booted；Xcode 26.6）。

**设计前提（审美即产品）:** 本计划中的 SwiftUI 视图代码为**功能骨架**，确立布局与状态路由。Task 6 起的每个 UI 任务，动手前必须先调用 `superpowers:design` skill 确立「有承诺的克制美学」（极致留白 / 高对比排版 / 无红点无 badge / 安静优先），再据其产出替换骨架的视觉细节。骨架保证可运行、可验证，design skill 保证「高价值断网容器」的观感。

---

## File Structure

```
Sources/
├── Session/                        # 新增：断网时段（纯逻辑，可单测）
│   ├── Session.swift               # Codable 状态机模型 + 纯转换方法
│   └── SessionController.swift     # @Observable 编排：begin/pause/resume/land/close + 持久化 + 可选离线提示
├── Monetization/                   # 新增：Journey Pass
│   └── JourneyPassStore.swift      # @Observable，StoreKit 2 非消耗型 IAP + 权益校验
├── Persistence/
│   └── GameStorage.swift           # 扩展：currentSession 存档、journeyPassUnlocked 权益、offlineNudgeDisabled
├── UI/
│   ├── SessionShellView.swift      # 新根视图：按 SessionController 状态路由三态
│   ├── SessionSetupView.swift      # setup 态：开始一个断网时段（可选设时长）+ 直接玩 2048 入口
│   ├── SessionActiveView.swift     # active 态：安静环境，嵌入既有 GameView
│   ├── SessionLandedView.swift     # landed 态：你已落地 + 本次统计 + 可选自愿同步
│   └── JourneyPassView.swift       # 候机室购买页（在线完成，离线降级）
├── App/
│   └── Game2048App.swift           # 扩展：根视图改为 SessionShellView，注入依赖
Tests/
│   ├── SessionTests.swift          # 纯状态机单测
│   ├── SessionControllerTests.swift# 编排 + 持久化 + 不丢进度单测
│   ├── GameStorageSessionTests.swift # 存档往返单测
│   └── JourneyPassStoreTests.swift # StoreKitTest 购买→权益→恢复单测
Config/
│   └── JourneyPass.storekit        # StoreKit 本地测试配置
project.yml                         # 扩展：scheme 绑定 .storekit；测试 target 链接 StoreKitTest
```

**依赖与顺序：** Task 1→2 建立 Session 逻辑；Task 3 扩展持久化（被 2、5 依赖）；Task 4→5 建立变现；Task 6→9 建立 UI 外壳与集成。Session 逻辑（1–3）与变现（4–5）相互独立，可并行；UI（6–9）依赖前两者。

---

## Task 1: Session 状态机模型（纯逻辑）

`Session` 是断网时段的骨架：有始有终、注入时钟、pause/resume 精确扣除暂停时长、`Codable` 往返。所有转换是 `struct` 上的纯 `mutating` 方法，不依赖 UI/存储/系统时间，便于单测。

**Files:**
- Create: `Sources/Session/Session.swift`
- Test: `Tests/SessionTests.swift`

- [ ] **Step 1: 写失败测试 —— 状态机推进与暂停扣时**

Create `Tests/SessionTests.swift`:

```swift
import Foundation
import Testing
@testable import Game2048

@Suite struct SessionTests {
    /// 固定基准时刻，避免依赖 Date()。
    let t0 = Date(timeIntervalSince1970: 1_000_000)

    @Test func startsInSetup() {
        let session = Session(startedAt: t0, plannedDuration: 30 * 60)
        #expect(session.state == .setup)
        #expect(session.plannedDuration == 30.0 * 60) // Double 字面量：避免 Swift Testing 宏对 Double? == Int 的异构比较误报
        #expect(session.activityLog.isEmpty)
    }

    @Test func beginEntersActiveAndLogsHeroActivity() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        #expect(session.state == .active)
        #expect(session.activityLog.count == 1)
        #expect(session.activityLog[0].kind == .game2048)
        #expect(session.activityLog[0].startedAt == t0)
        #expect(session.activityLog[0].endedAt == nil)
    }

    @Test func elapsedActiveTimeExcludesPausedSpan() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        // 玩 10 分钟
        session.pause(at: t0.addingTimeInterval(600))
        // 暂停 5 分钟（颠簸/供餐）
        session.resume(at: t0.addingTimeInterval(900))
        // 再玩 10 分钟后落地
        session.land(at: t0.addingTimeInterval(1500))
        // 实际活跃时间 = 600 + 600 = 1200 秒，暂停的 300 秒被扣除
        #expect(session.elapsedActiveTime(at: t0.addingTimeInterval(1500)) == 1200)
    }

    @Test func landClosesOpenActivityAndEntersLanded() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        session.land(at: t0.addingTimeInterval(1200))
        #expect(session.state == .landed)
        #expect(session.activityLog[0].endedAt == t0.addingTimeInterval(1200))
    }

    @Test func closeEntersClosed() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        session.land(at: t0.addingTimeInterval(60))
        session.close()
        #expect(session.state == .closed)
    }

    @Test func pauseWhileAlreadyPausedIsNoOp() {
        var session = Session(startedAt: t0)
        session.begin(at: t0)
        session.pause(at: t0.addingTimeInterval(100))
        session.pause(at: t0.addingTimeInterval(200)) // 重复暂停不叠加
        session.resume(at: t0.addingTimeInterval(300))
        // 暂停从 100 到 300 = 200 秒；活跃 = 300 - 200 = 100
        #expect(session.elapsedActiveTime(at: t0.addingTimeInterval(300)) == 100)
    }

    @Test func codableRoundTrip() throws {
        var session = Session(startedAt: t0, plannedDuration: 45 * 60)
        session.begin(at: t0)
        session.pause(at: t0.addingTimeInterval(120))
        let data = try JSONEncoder().encode(session)
        let decoded = try JSONDecoder().decode(Session.self, from: data)
        #expect(decoded == session)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/SessionTests 2>&1 | tail -20`
Expected: 编译失败 —— `cannot find 'Session' in scope`。

- [ ] **Step 3: 实现 Session 模型**

Create `Sources/Session/Session.swift`:

```swift
import Foundation

/// Session 的生命周期状态。与设计文档一致：setup → active → landed → closed。
enum SessionState: String, Codable, Sendable {
    case setup, active, landed, closed
}

/// Session 内做过的一件事（V1 仅 2048，接口为未来程序化组件预留）。仅本地。
struct SessionActivity: Codable, Equatable, Sendable {
    enum Kind: String, Codable, Sendable {
        case game2048
    }
    let kind: Kind
    let startedAt: Date
    var endedAt: Date?
}

/// 一个有始有终的断网时段容器。纯值类型、注入时钟、进度可 Codable 往返。
struct Session: Codable, Equatable, Sendable {
    let id: UUID
    let startedAt: Date
    /// 计划时长（秒）。可空——用户可以不设时长。
    var plannedDuration: TimeInterval?
    private(set) var state: SessionState
    private(set) var activityLog: [SessionActivity]
    /// 非 nil 表示当前处于暂停中，值为暂停开始时刻。
    private(set) var pausedAt: Date?
    /// 已累计的暂停总时长（秒），用于从墙钟时间中扣除。
    private(set) var accumulatedPause: TimeInterval

    init(id: UUID = UUID(), startedAt: Date, plannedDuration: TimeInterval? = nil) {
        self.id = id
        self.startedAt = startedAt
        self.plannedDuration = plannedDuration
        self.state = .setup
        self.activityLog = []
        self.pausedAt = nil
        self.accumulatedPause = 0
    }

    /// 进入 active，并登记本次 Session 的 Hero 活动（2048）。
    mutating func begin(at now: Date) {
        guard state == .setup else { return }
        state = .active
        activityLog.append(SessionActivity(kind: .game2048, startedAt: now, endedAt: nil))
    }

    /// 应对颠簸/供餐/广播打断。重复暂停为无操作（不叠加）。
    mutating func pause(at now: Date) {
        guard state == .active, pausedAt == nil else { return }
        pausedAt = now
    }

    /// 从暂停恢复，累计本次暂停时长。
    mutating func resume(at now: Date) {
        guard state == .active, let pausedAt else { return }
        accumulatedPause += now.timeIntervalSince(pausedAt)
        self.pausedAt = nil
    }

    /// 进入 landed，收束所有未结束的活动。
    mutating func land(at now: Date) {
        guard state == .active else { return }
        if pausedAt != nil { resume(at: now) }
        for index in activityLog.indices where activityLog[index].endedAt == nil {
            activityLog[index].endedAt = now
        }
        state = .landed
    }

    /// 收尾完成，进入 closed（供 UI 清场/归档）。
    mutating func close() {
        state = .closed
    }

    /// 截至 `now` 的净活跃时长（秒），扣除全部暂停区间。
    func elapsedActiveTime(at now: Date) -> TimeInterval {
        let wall = now.timeIntervalSince(startedAt)
        let currentPause = pausedAt.map { now.timeIntervalSince($0) } ?? 0
        return max(0, wall - accumulatedPause - currentPause)
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/SessionTests 2>&1 | tail -20`
Expected: `SessionTests` 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add Sources/Session/Session.swift Tests/SessionTests.swift
git commit -m "feat: Session 状态机模型（纯逻辑、注入时钟、暂停扣时）"
```

---

## Task 2: SessionController（编排层，@Observable）

把纯 `Session` 包成可观察、可持久化的编排对象。它是 UI 的单一真相源：begin/pause/resume/land/close 每一步都**立即存档**（进度绝不丢失）。注入 `now` 时钟以便单测。

**Files:**
- Create: `Sources/Session/SessionController.swift`
- Test: `Tests/SessionControllerTests.swift`
- 依赖：Task 3 的 `GameStorage.currentSession`（先写 Task 3 或与本任务合并提交；本计划把 Task 3 排在此后，故本任务的 Step 1 测试用到的 `GameStorage.currentSession` 需 Task 3 完成。**执行顺序：先做 Task 3，再回到 Task 2。** 见下方注记。）

> **执行注记：** `SessionController` 依赖 `GameStorage.currentSession`（Task 3 新增）。请按 **Task 3 → Task 2** 的顺序执行这两个任务；此处编号保持文档结构（Session 模块相邻）。

- [ ] **Step 1: 写失败测试 —— 编排与持久化**

Create `Tests/SessionControllerTests.swift`:

```swift
import Foundation
import Testing
@testable import Game2048

@MainActor
@Suite struct SessionControllerTests {
    let defaults: UserDefaults
    let storage: GameStorage
    var clock: Date

    init() {
        defaults = UserDefaults(suiteName: "SessionControllerTests")!
        defaults.removePersistentDomain(forName: "SessionControllerTests")
        storage = GameStorage(defaults: defaults)
        clock = Date(timeIntervalSince1970: 2_000_000)
    }

    /// 构造一个时钟可控的 controller。
    func makeController(now: @escaping () -> Date) -> SessionController {
        SessionController(storage: storage, now: now)
    }

    @Test mutating func beginPersistsActiveSession() {
        let base = clock
        let controller = makeController { base }
        controller.begin(duration: 30 * 60)
        #expect(controller.session?.state == .active)
        // 立即存档
        #expect(storage.currentSession?.state == .active)
    }

    @Test mutating func restoresInFlightSessionFromStorage() {
        let base = clock
        // 先用一个 controller 制造一个进行中的 Session
        let first = makeController { base }
        first.begin(duration: nil)
        // 新 controller 应从存档恢复，进度不丢
        let restored = makeController { base }
        #expect(restored.session?.state == .active)
        #expect(restored.session?.id == first.session?.id)
    }

    @Test mutating func pauseResumePersistAndPreserveProgress() {
        var now = clock
        let controller = makeController { now }
        controller.begin(duration: nil)
        now = clock.addingTimeInterval(600)
        controller.pause()
        #expect(storage.currentSession?.pausedAt != nil)
        now = clock.addingTimeInterval(900)
        controller.resume()
        #expect(storage.currentSession?.pausedAt == nil)
    }

    @Test mutating func landMovesToLandedAndClearsOnClose() {
        var now = clock
        let controller = makeController { now }
        controller.begin(duration: nil)
        now = clock.addingTimeInterval(1200)
        controller.land()
        #expect(controller.session?.state == .landed)
        #expect(storage.currentSession?.state == .landed)
        controller.close()
        #expect(controller.session == nil)
        #expect(storage.currentSession == nil) // closed 后清场
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/SessionControllerTests 2>&1 | tail -20`
Expected: 编译失败 —— `cannot find 'SessionController' in scope`。

- [ ] **Step 3: 实现 SessionController**

Create `Sources/Session/SessionController.swift`:

```swift
import Foundation

/// 断网时段编排层。UI 的单一真相源；每次状态变更立即存档，进度绝不丢失。
@MainActor
@Observable
final class SessionController {
    private(set) var session: Session?

    private let storage: GameStorage
    private let now: () -> Date

    init(storage: GameStorage, now: @escaping () -> Date = Date.init) {
        self.storage = storage
        self.now = now
        // 启动即恢复进行中的 Session（landed 之前的都算进行中）。
        if let saved = storage.currentSession, saved.state == .active || saved.state == .setup {
            self.session = saved
        } else {
            self.session = nil
        }
    }

    /// 开始一个断网时段。可选设时长（秒）；nil = 不设时长。
    func begin(duration: TimeInterval?) {
        var new = Session(startedAt: now(), plannedDuration: duration)
        new.begin(at: now())
        session = new
        persist()
    }

    func pause() {
        session?.pause(at: now())
        persist()
    }

    func resume() {
        session?.resume(at: now())
        persist()
    }

    /// 落地：进入 landed 收尾态（展示克制的「你已落地」）。
    func land() {
        session?.land(at: now())
        persist()
    }

    /// 收尾完成：清场，回到入口态。
    func close() {
        session?.close()
        session = nil
        storage.currentSession = nil
    }

    /// 当前净活跃时长（秒），供收尾统计展示。
    func elapsedActiveTime() -> TimeInterval {
        session?.elapsedActiveTime(at: now()) ?? 0
    }

    private func persist() {
        storage.currentSession = session
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/SessionControllerTests 2>&1 | tail -20`
Expected: `SessionControllerTests` 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add Sources/Session/SessionController.swift Tests/SessionControllerTests.swift
git commit -m "feat: SessionController 编排层（每步立即存档、启动恢复进行中 Session）"
```

---

## Task 3: Persistence 扩展 —— Session 存档 + Pass 权益 + 提示开关

扩展既有 `GameStorage`，新增三项本地状态：进行中的 Session（落地保证）、Journey Pass 权益、离线轻提示的永久关闭开关。**本任务须在 Task 2 之前执行**（见 Task 2 执行注记）。

**Files:**
- Modify: `Sources/Persistence/GameStorage.swift`
- Test: `Tests/GameStorageSessionTests.swift`

- [ ] **Step 1: 写失败测试**

Create `Tests/GameStorageSessionTests.swift`:

```swift
import Foundation
import Testing
@testable import Game2048

@Suite struct GameStorageSessionTests {
    let defaults: UserDefaults
    let storage: GameStorage

    init() {
        defaults = UserDefaults(suiteName: "GameStorageSessionTests")!
        defaults.removePersistentDomain(forName: "GameStorageSessionTests")
        storage = GameStorage(defaults: defaults)
    }

    @Test func currentSessionRoundTripAndClear() {
        #expect(storage.currentSession == nil)
        var session = Session(startedAt: Date(timeIntervalSince1970: 3_000_000))
        session.begin(at: Date(timeIntervalSince1970: 3_000_000))
        storage.currentSession = session
        #expect(storage.currentSession == session)
        storage.currentSession = nil
        #expect(storage.currentSession == nil)
    }

    @Test func journeyPassDefaultsLockedAndPersists() {
        #expect(storage.journeyPassUnlocked == false)
        storage.journeyPassUnlocked = true
        #expect(storage.journeyPassUnlocked == true)
    }

    @Test func offlineNudgeDisabledDefaultsFalseAndPersists() {
        #expect(storage.offlineNudgeDisabled == false)
        storage.offlineNudgeDisabled = true
        #expect(storage.offlineNudgeDisabled == true)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/GameStorageSessionTests 2>&1 | tail -20`
Expected: 编译失败 —— `value of type 'GameStorage' has no member 'currentSession'`。

- [ ] **Step 3: 扩展 GameStorage**

在 `Sources/Persistence/GameStorage.swift` 的 `gameState` 属性之后、闭合 `}` 之前追加：

```swift
    /// 进行中的 Session 存档（落地保证：任何时刻中断进度都不丢）。
    var currentSession: Session? {
        get {
            guard let data = defaults.data(forKey: "currentSession") else { return nil }
            return try? JSONDecoder().decode(Session.self, from: data)
        }
        nonmutating set {
            if let newValue, let data = try? JSONEncoder().encode(newValue) {
                defaults.set(data, forKey: "currentSession")
            } else {
                defaults.removeObject(forKey: "currentSession")
            }
        }
    }

    /// Journey Pass 权益（离线时以此本地状态为准）。
    var journeyPassUnlocked: Bool {
        get { defaults.bool(forKey: "journeyPassUnlocked") }
        nonmutating set { defaults.set(newValue, forKey: "journeyPassUnlocked") }
    }

    /// 离线轻提示是否被用户永久关闭（关闭后绝不再骚扰）。
    var offlineNudgeDisabled: Bool {
        get { defaults.bool(forKey: "offlineNudgeDisabled") }
        nonmutating set { defaults.set(newValue, forKey: "offlineNudgeDisabled") }
    }
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/GameStorageSessionTests 2>&1 | tail -20`
Expected: `GameStorageSessionTests` 全部 PASS。

- [ ] **Step 5: 提交**

```bash
git add Sources/Persistence/GameStorage.swift Tests/GameStorageSessionTests.swift
git commit -m "feat: Persistence 扩展 Session 存档、Pass 权益、离线提示开关"
```

---

## Task 4: StoreKit 本地测试配置 + 工程绑定

新增 `JourneyPass.storekit`（一个非消耗型 IAP：永久解锁 Session 模式），并在 XcodeGen scheme 中绑定，让测试与本地运行都走本地 StoreKit 沙盒。同时让测试 target 链接 `StoreKitTest.framework`。

**Files:**
- Create: `Config/JourneyPass.storekit`
- Modify: `project.yml`

- [ ] **Step 1: 创建 StoreKit 配置**

Create `Config/JourneyPass.storekit`:

```json
{
  "identifier" : "A1B2C3D4",
  "nonRenewingSubscriptions" : [],
  "products" : [
    {
      "displayPrice" : "2.99",
      "familyShareable" : false,
      "internalID" : "JP0000000001",
      "localizations" : [
        {
          "description" : "永久解锁 Session 模式：仪式容器、安静环境、落地收尾与本地统计。2048 本体始终免费。",
          "displayName" : "Journey Pass",
          "locale" : "zh_CN"
        }
      ],
      "productID" : "com.dayuer.above.journeypass",
      "referenceName" : "Journey Pass",
      "type" : "NonConsumable"
    }
  ],
  "settings" : {
    "_applicationInternalID" : "0",
    "_developerTeamID" : "L9YRXEKYN2",
    "_failTransactionsEnabled" : false
  },
  "subscriptionGroups" : [],
  "version" : {
    "major" : 3,
    "minor" : 0
  }
}
```

- [ ] **Step 2: 在 project.yml 绑定 StoreKit 配置与测试依赖**

在 `project.yml` 的 `Game2048Tests` target 的 `dependencies` 下追加 StoreKitTest 链接，并在 `schemes.Game2048.run` 与 `.test` 下绑定 `.storekit`。修改后相关片段：

```yaml
  Game2048Tests:
    type: bundle.unit-test
    platform: iOS
    sources:
      - Tests
    dependencies:
      - target: Game2048
      - sdk: StoreKitTest.framework
schemes:
  Game2048:
    build:
      targets:
        Game2048: all
    run:
      config: Debug
      storeKitConfiguration: Config/JourneyPass.storekit
    test:
      config: Debug
      storeKitConfiguration: Config/JourneyPass.storekit
      targets:
        - Game2048Tests
```

同时把 `Config` 目录纳入工程（否则 `.storekit` 不进 build）。在 `targets.Game2048.sources` 下追加（`.storekit` 作为资源随主 target 打包便于本地运行）：

```yaml
    sources:
      - Sources
      - path: Config/JourneyPass.storekit
        buildPhase: none
```

- [ ] **Step 3: 重新生成工程并确认可构建**

Run: `xcodegen generate && xcodebuild build -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -15`
Expected: `** BUILD SUCCEEDED **`（此时尚无 StoreKit 代码，仅验证工程与配置有效）。

- [ ] **Step 4: 提交**

```bash
git add Config/JourneyPass.storekit project.yml
git commit -m "chore: StoreKit 本地测试配置与工程绑定"
```

---

## Task 5: JourneyPassStore（StoreKit 2 变现）

免费下载，2048 永不被墙。付费买断的是 **Session 模式**。`JourneyPassStore` 负责加载产品、发起购买、监听交易、把权益写入本地 `GameStorage`（离线可用），并支持恢复购买。

**Files:**
- Create: `Sources/Monetization/JourneyPassStore.swift`
- Test: `Tests/JourneyPassStoreTests.swift`

- [ ] **Step 1: 写失败测试 —— 购买→权益持久化→恢复**

Create `Tests/JourneyPassStoreTests.swift`:

```swift
import Foundation
import Testing
import StoreKitTest
@testable import Game2048

@MainActor
@Suite struct JourneyPassStoreTests {
    let defaults: UserDefaults
    let storage: GameStorage
    let session: SKTestSession

    init() throws {
        defaults = UserDefaults(suiteName: "JourneyPassStoreTests")!
        defaults.removePersistentDomain(forName: "JourneyPassStoreTests")
        storage = GameStorage(defaults: defaults)
        session = try SKTestSession(configurationFileNamed: "JourneyPass")
        session.resetToDefaultState()
        session.disableDialogs = true
        session.clearTransactions()
    }

    @Test func loadsProduct() async throws {
        let store = JourneyPassStore(storage: storage)
        try await store.loadProduct()
        #expect(store.product?.id == JourneyPassStore.productID)
    }

    @Test func purchaseUnlocksAndPersistsEntitlement() async throws {
        #expect(storage.journeyPassUnlocked == false)
        let store = JourneyPassStore(storage: storage)
        try await store.loadProduct()
        try await store.purchase()
        #expect(store.isUnlocked == true)
        // 权益本地持久化 → 此后离线可用
        #expect(storage.journeyPassUnlocked == true)
    }

    @Test func refreshEntitlementsSyncsFromStoreKit() async throws {
        // 预置一笔已购买交易
        let store1 = JourneyPassStore(storage: storage)
        try await store1.loadProduct()
        try await store1.purchase()

        // 新实例（模拟重装/新会话）：清掉本地标记，靠 StoreKit 恢复
        storage.journeyPassUnlocked = false
        let store2 = JourneyPassStore(storage: storage)
        await store2.refreshEntitlements()
        #expect(store2.isUnlocked == true)
        #expect(storage.journeyPassUnlocked == true)
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/JourneyPassStoreTests 2>&1 | tail -20`
Expected: 编译失败 —— `cannot find 'JourneyPassStore' in scope`。

- [ ] **Step 3: 实现 JourneyPassStore**

Create `Sources/Monetization/JourneyPassStore.swift`:

```swift
import Foundation
import StoreKit

/// Journey Pass：非消耗型 IAP。免费下载，2048 永不被墙；付费买断的是 Session 模式。
/// 权益本地持久化后完全离线可用；联网时以 StoreKit 当前权益校验/恢复。
@MainActor
@Observable
final class JourneyPassStore {
    static let productID = "com.dayuer.above.journeypass"

    /// 购买失败/未联网的静默降级信息（绝不打断游戏）。
    enum PurchaseError: Error, Equatable {
        case productUnavailable
        case verificationFailed
        case userCancelled
        case pending
    }

    private(set) var product: Product?
    /// UI 用的权益真相源：本地持久化优先，联网时被 StoreKit 校验同步。
    private(set) var isUnlocked: Bool

    private let storage: GameStorage
    private var updatesTask: Task<Void, Never>?

    init(storage: GameStorage) {
        self.storage = storage
        self.isUnlocked = storage.journeyPassUnlocked
        // 监听交易更新（如其它设备恢复购买）。
        updatesTask = Task { [weak self] in
            for await update in Transaction.updates {
                await self?.handle(verification: update)
            }
        }
    }

    deinit { updatesTask?.cancel() }

    /// 候机室在线加载产品。失败即静默降级（product 保持 nil）。
    func loadProduct() async throws {
        let products = try await Product.products(for: [Self.productID])
        guard let first = products.first else { throw PurchaseError.productUnavailable }
        product = first
    }

    /// 发起购买。成功→写入本地权益（离线可用）。
    func purchase() async throws {
        guard let product else { throw PurchaseError.productUnavailable }
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            try await handle(verification: verification, finishing: true)
        case .userCancelled:
            throw PurchaseError.userCancelled
        case .pending:
            throw PurchaseError.pending
        @unknown default:
            throw PurchaseError.verificationFailed
        }
    }

    /// 恢复购买/联网校验：扫描当前权益，同步本地状态。
    func refreshEntitlements() async {
        for await entitlement in Transaction.currentEntitlements {
            await handle(verification: entitlement)
        }
    }

    /// 显式恢复购买（用户点「恢复购买」）。
    func restore() async throws {
        try await AppStore.sync()
        await refreshEntitlements()
    }

    /// 校验一笔交易并落地权益。
    private func handle(verification: VerificationResult<Transaction>, finishing: Bool = false) async {
        guard case .verified(let transaction) = verification,
              transaction.productID == Self.productID,
              transaction.revocationDate == nil else { return }
        setUnlocked(true)
        if finishing { await transaction.finish() }
    }

    /// throwing 版本，供购买路径区分校验失败。
    private func handle(verification: VerificationResult<Transaction>, finishing: Bool) async throws {
        guard case .verified(let transaction) = verification else {
            throw PurchaseError.verificationFailed
        }
        guard transaction.productID == Self.productID else { return }
        setUnlocked(true)
        if finishing { await transaction.finish() }
    }

    private func setUnlocked(_ value: Bool) {
        isUnlocked = value
        storage.journeyPassUnlocked = value
    }
}
```

- [ ] **Step 4: 运行测试确认通过**

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:Game2048Tests/JourneyPassStoreTests 2>&1 | tail -20`
Expected: `JourneyPassStoreTests` 全部 PASS。

> 若 StoreKitTest 在命令行环境不稳定，先确认 `-destination` 模拟器可用；`SKTestSession` 需要与 scheme 绑定的 `.storekit` 同名（`configurationFileNamed: "JourneyPass"`）。

- [ ] **Step 5: 提交**

```bash
git add Sources/Monetization/JourneyPassStore.swift Tests/JourneyPassStoreTests.swift
git commit -m "feat: JourneyPassStore（StoreKit 2 买断，权益本地持久化，支持恢复）"
```

---

## Task 6: Session 外壳根视图 + setup 态

**动手前先调用 `superpowers:design` skill**，确立 Session 外壳的克制美学（极致留白、高对比排版、无红点无 badge、安静优先），再据其产出细化下列骨架的视觉。本任务建立根视图路由与 setup 入口。

**Files:**
- Create: `Sources/UI/SessionShellView.swift`
- Create: `Sources/UI/SessionSetupView.swift`

- [ ] **Step 1: 调用 design skill 确立美学**

调用 `superpowers:design`，产出：配色/留白/排版承诺、setup 与 landed 两态的视觉规范。把结论落到 `Sources/UI/Theme.swift`（如需新增语义色）与下列视图。

- [ ] **Step 2: 实现根视图路由**

Create `Sources/UI/SessionShellView.swift`:

```swift
import SwiftUI

/// 应用根视图：按 SessionController 的状态在三态间路由。
/// 无 Session → setup；active → 安静环境（GameView）；landed → 收尾。
struct SessionShellView: View {
    @State private var storage = GameStorage()
    @State private var gameCenter = GameCenterManager()
    @State private var sessionController: SessionController
    @State private var passStore: JourneyPassStore

    init() {
        let storage = GameStorage()
        let controller = SessionController(storage: storage)
        let pass = JourneyPassStore(storage: storage)
        _storage = State(initialValue: storage)
        _sessionController = State(initialValue: controller)
        _passStore = State(initialValue: pass)
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()
            switch sessionController.session?.state {
            case .active:
                SessionActiveView(controller: sessionController, gameCenter: gameCenter, storage: storage)
            case .landed:
                SessionLandedView(controller: sessionController, gameCenter: gameCenter)
            case .setup, .closed, nil:
                SessionSetupView(
                    controller: sessionController,
                    passStore: passStore,
                    gameCenter: gameCenter,
                    storage: storage
                )
            }
        }
        .animation(.easeInOut(duration: 0.35), value: sessionController.session?.state)
        .task {
            gameCenter.authenticate()
            await passStore.refreshEntitlements()
        }
    }
}
```

- [ ] **Step 3: 实现 setup 态**

Create `Sources/UI/SessionSetupView.swift`:

```swift
import SwiftUI

/// setup 态：安静的「开始一个断网时段」入口。
/// - 已解锁 Session 模式：可选时长后「开始断网时段」。
/// - 未解锁：仍可「直接玩 2048」（本体永久免费），并提供候机室购买入口。
struct SessionSetupView: View {
    let controller: SessionController
    let passStore: JourneyPassStore
    let gameCenter: GameCenterManager
    let storage: GameStorage

    @State private var showPass = false
    @State private var playFreely = false

    /// 可选时长档位（秒）；nil = 不设时长。
    private let durations: [(label: LocalizedStringKey, value: TimeInterval?)] = [
        ("不设时长", nil),
        ("30 分钟", 30 * 60),
        ("1 小时", 60 * 60),
        ("2 小时", 120 * 60)
    ]
    @State private var selected: TimeInterval? = nil

    var body: some View {
        VStack(spacing: 32) {
            Spacer()
            Text("离线时刻")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(Theme.text)

            if passStore.isUnlocked {
                durationPicker
                Button {
                    controller.begin(duration: selected)
                } label: {
                    Text("开始断网时段")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.button, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Theme.lightText)
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    showPass = true
                } label: {
                    Text("解锁 Session 模式")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.button, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(Theme.lightText)
                }
                .buttonStyle(.plain)
            }

            Button("直接玩 2048") { playFreely = true }
                .font(.subheadline)
                .foregroundStyle(Theme.text.opacity(0.7))
            Spacer()
        }
        .padding(28)
        .frame(maxWidth: 480)
        .sheet(isPresented: $showPass) {
            JourneyPassView(passStore: passStore)
        }
        .fullScreenCover(isPresented: $playFreely) {
            // 本体免费：不经过 Session，直接进入 2048。
            FreePlayContainer(gameCenter: gameCenter, storage: storage) { playFreely = false }
        }
    }

    private var durationPicker: some View {
        HStack(spacing: 8) {
            ForEach(durations.indices, id: \.self) { i in
                let option = durations[i]
                Button {
                    selected = option.value
                } label: {
                    Text(option.label)
                        .font(.footnote.weight(.medium))
                        .padding(.horizontal, 12).padding(.vertical, 10)
                        .background(
                            selected == option.value ? Theme.button : Theme.button.opacity(0.15),
                            in: RoundedRectangle(cornerRadius: 8)
                        )
                        .foregroundStyle(selected == option.value ? Theme.lightText : Theme.text)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

/// 免费直玩容器：把既有 GameView 包一层可返回的外壳。
private struct FreePlayContainer: View {
    let gameCenter: GameCenterManager
    let storage: GameStorage
    let onExit: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            GameView()
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .padding(12)
                    .foregroundStyle(Theme.text)
            }
            .buttonStyle(.plain)
            .padding(8)
        }
    }
}
```

> 注：`FreePlayContainer` 复用既有 `GameView()`（其自带 `GameCenterManager`/`GameViewModel`）。若后续要共享同一 `GameCenterManager` 实例，可在 Task 9 统一注入，V1 先保持简单。

- [ ] **Step 4: 构建确认（暂不接入 App 入口，避免引用未实现视图）**

Run: `xcodegen generate && xcodebuild build -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`
Expected: 编译失败 —— 引用了尚未实现的 `SessionActiveView` / `SessionLandedView` / `JourneyPassView`。这是预期的；它们在 Task 7、8 实现，届时整体构建通过。**本步仅用于捕捉 setup/shell 自身的语法错误**：确认报错只来自「未定义的三个视图」，无其它编译错误。

- [ ] **Step 5: 提交**

```bash
git add Sources/UI/SessionShellView.swift Sources/UI/SessionSetupView.swift Sources/UI/Theme.swift
git commit -m "feat: Session 外壳根视图与 setup 态（design skill 定稿美学）"
```

---

## Task 7: JourneyPassView 购买页（候机室在线，离线降级）

购买发生在候机室（设备仍在线）——注意力与购买意图的峰值。购买失败/未联网静默降级，绝不打断，2048 免费部分始终可玩。

**Files:**
- Create: `Sources/UI/JourneyPassView.swift`

- [ ] **Step 1: 动手前调用 design skill 细化购买页视觉**（诚实、克制、无 FOMO、无倒计时、无诱导）。

- [ ] **Step 2: 实现购买页**

Create `Sources/UI/JourneyPassView.swift`:

```swift
import SwiftUI

/// Journey Pass 购买页。诚实变现：一次性买断、无倒计时、无 dark pattern。
struct JourneyPassView: View {
    let passStore: JourneyPassStore
    @Environment(\.dismiss) private var dismiss

    @State private var message: LocalizedStringKey?
    @State private var busy = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()
            Text("Journey Pass")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.text)
            Text("永久解锁 Session 模式：仪式容器、安静环境、落地收尾与本地统计。\n2048 本体始终免费。")
                .font(.subheadline)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.text.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task { await buy() }
            } label: {
                Text(purchaseLabel)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.button, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Theme.lightText)
            }
            .buttonStyle(.plain)
            .disabled(busy)

            Button("恢复购买") { Task { await restore() } }
                .font(.footnote)
                .foregroundStyle(Theme.text.opacity(0.7))

            if let message {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(Theme.text.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            Spacer()
            Button("以后再说") { dismiss() }
                .font(.subheadline)
                .foregroundStyle(Theme.text.opacity(0.6))
        }
        .padding(28)
        .frame(maxWidth: 480)
        .task { await load() }
        .onChange(of: passStore.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private var purchaseLabel: LocalizedStringKey {
        if let price = passStore.product?.displayPrice {
            return "\(price) 解锁"
        }
        return "解锁"
    }

    private func load() async {
        do { try await passStore.loadProduct() }
        catch { message = "需要联网完成购买" } // 静默降级
    }

    private func buy() async {
        busy = true; defer { busy = false }
        do { try await passStore.purchase() }
        catch JourneyPassStore.PurchaseError.userCancelled { /* 静默 */ }
        catch JourneyPassStore.PurchaseError.pending { message = "购买待确认" }
        catch { message = "需要联网完成购买" }
    }

    private func restore() async {
        do { try await passStore.restore() }
        catch { message = "恢复失败，请检查网络" }
    }
}
```

- [ ] **Step 3: 构建确认（仍缺 active/landed 视图，预期报错收敛为两项）**

Run: `xcodebuild build -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -20`
Expected: 报错只剩 `SessionActiveView` / `SessionLandedView` 未定义。

- [ ] **Step 4: 提交**

```bash
git add Sources/UI/JourneyPassView.swift
git commit -m "feat: Journey Pass 购买页（诚实变现、离线静默降级）"
```

---

## Task 8: active 态与 landed 态 + 接入 App 入口

active 态是安静环境，把既有 2048 承载其中，并提供暂停/落地入口；landed 态是克制的「你已落地」收尾（本次时长/最高分，本地）+ 可选自愿同步 Game Center。最后把 App 根视图切到 `SessionShellView`。

**Files:**
- Create: `Sources/UI/SessionActiveView.swift`
- Create: `Sources/UI/SessionLandedView.swift`
- Modify: `Sources/App/Game2048App.swift`

- [ ] **Step 1: 动手前调用 design skill 细化 active/landed 视觉**（active 只在极小角落放暂停/落地，主体是安静棋盘；landed 展示克制统计，同步按钮弱化、绝不弹窗骚扰）。

- [ ] **Step 2: 实现 active 态**

Create `Sources/UI/SessionActiveView.swift`:

```swift
import SwiftUI

/// active 态：安静环境。大面积留白、无红点无 badge，把 2048 承载其中。
/// 切后台/来电由系统触发，进度已在每步存档；此处提供显式暂停与落地。
struct SessionActiveView: View {
    let controller: SessionController
    let gameCenter: GameCenterManager
    let storage: GameStorage

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Button {
                    controller.land()
                } label: {
                    Text("落地")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.text.opacity(0.7))
                }
                .buttonStyle(.plain)
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)

            // 既有 2048 作为 Session 内的 Hero 活动。
            GameView()
        }
        .onChange(of: scenePhase) { _, phase in
            // 颠簸/供餐/来电切后台：暂停并存档（进度绝不丢）。
            switch phase {
            case .active: controller.resume()
            case .inactive, .background: controller.pause()
            @unknown default: break
            }
        }
    }
}
```

- [ ] **Step 3: 实现 landed 态**

Create `Sources/UI/SessionLandedView.swift`:

```swift
import SwiftUI

/// landed 态：克制的「你已落地」。展示本次 Session 做了什么（本地），
/// 并提供**自愿**同步 Game Center（永不强制、不弹窗骚扰）。
struct SessionLandedView: View {
    let controller: SessionController
    let gameCenter: GameCenterManager

    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            Text("你已落地")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Theme.text)

            Text(durationText)
                .font(.title3)
                .foregroundStyle(Theme.text.opacity(0.8))

            Button("同步这次成绩") {
                gameCenter.showLeaderboard()
            }
            .font(.footnote)
            .foregroundStyle(Theme.text.opacity(0.6))

            Spacer()
            Button {
                controller.close()
            } label: {
                Text("结束")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Theme.button, in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(Theme.lightText)
            }
            .buttonStyle(.plain)
        }
        .padding(28)
        .frame(maxWidth: 480)
    }

    private var durationText: String {
        let seconds = Int(controller.elapsedActiveTime())
        let minutes = seconds / 60
        return "这次断网时段：\(minutes) 分钟"
    }
}
```

- [ ] **Step 4: 接入 App 入口**

Modify `Sources/App/Game2048App.swift`:

```swift
import SwiftUI

@main
struct Game2048App: App {
    var body: some Scene {
        WindowGroup {
            SessionShellView()
        }
    }
}
```

- [ ] **Step 5: 整体构建 + 全量测试**

Run: `xcodegen generate && xcodebuild build -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -15`
Expected: `** BUILD SUCCEEDED **`。

Run: `xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -25`
Expected: 所有 Suite（GameEngineTests / GameStorageTests / SessionTests / SessionControllerTests / GameStorageSessionTests / JourneyPassStoreTests）PASS。

- [ ] **Step 6: 提交**

```bash
git add Sources/UI/SessionActiveView.swift Sources/UI/SessionLandedView.swift Sources/App/Game2048App.swift
git commit -m "feat: active/landed 态与 App 入口切换到 Session 外壳"
```

---

## Task 9: 可选离线轻提示（NWPathMonitor）

以**手动**进入 Session 为主。可选地用系统网络状态做一次「检测到你离线了，要开始一个 Session 吗？」的轻提示——**绝不强依赖飞行检测，可被永久关闭**。

**Files:**
- Create: `Sources/Session/OfflineNudge.swift`
- Modify: `Sources/UI/SessionSetupView.swift`

- [ ] **Step 1: 实现离线监测（无测试；系统 API 薄封装，手动验证）**

Create `Sources/Session/OfflineNudge.swift`:

```swift
import Foundation
import Network

/// 轻量离线监测：仅在 setup 态、且用户未永久关闭时，提示「要开始一个 Session 吗？」。
/// 绝不强依赖、绝不强制、可永久关闭。
@MainActor
@Observable
final class OfflineNudge {
    private(set) var isOffline = false
    private let monitor = NWPathMonitor()
    private let storage: GameStorage

    init(storage: GameStorage) {
        self.storage = storage
        monitor.pathUpdateHandler = { [weak self] path in
            Task { @MainActor in
                self?.isOffline = (path.status != .satisfied)
            }
        }
        monitor.start(queue: DispatchQueue(label: "OfflineNudge"))
    }

    deinit { monitor.cancel() }

    /// 是否应展示提示：离线 且 用户未永久关闭。
    var shouldPrompt: Bool { isOffline && !storage.offlineNudgeDisabled }

    /// 用户永久关闭提示（此后绝不再骚扰）。
    func disableForever() { storage.offlineNudgeDisabled = true }
}
```

- [ ] **Step 2: 在 setup 态挂接轻提示**

在 `SessionSetupView` 中新增 `@State private var offlineNudge: OfflineNudge`（由 `SessionShellView` 注入，或在 `init` 用 `storage` 构造），并在 `passStore.isUnlocked` 且 `offlineNudge.shouldPrompt` 时，于「开始断网时段」按钮上方展示一行克制文案与「不再提示」按钮。在 `SessionShellView.init` 中构造并传入：

```swift
// SessionShellView.init 内新增：
let nudge = OfflineNudge(storage: storage)
// 并在 SessionSetupView(...) 调用处传入 offlineNudge: nudge
```

`SessionSetupView` 中，在 `body` 顶部（`if passStore.isUnlocked` 分支内、`durationPicker` 之上）插入：

```swift
if offlineNudge.shouldPrompt {
    VStack(spacing: 8) {
        Text("检测到你已离线。要开始一个断网时段吗？")
            .font(.footnote)
            .foregroundStyle(Theme.text.opacity(0.7))
        Button("不再提示") { offlineNudge.disableForever() }
            .font(.caption)
            .foregroundStyle(Theme.text.opacity(0.5))
    }
}
```

（对应给 `SessionSetupView` 增加 `let offlineNudge: OfflineNudge` 存储属性，并在 `SessionShellView` 里加 `@State private var offlineNudge` 与 `init` 构造，传入 `SessionSetupView`。）

- [ ] **Step 3: 构建 + 手动验证**

Run: `xcodegen generate && xcodebuild build -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -15`
Expected: `** BUILD SUCCEEDED **`。手动：模拟器开飞行模式，setup 态应出现克制提示；点「不再提示」后不再出现。

- [ ] **Step 4: 提交**

```bash
git add Sources/Session/OfflineNudge.swift Sources/UI/SessionShellView.swift Sources/UI/SessionSetupView.swift
git commit -m "feat: 可选离线轻提示（可永久关闭，绝不强依赖飞行检测）"
```

---

## Task 10: 本地化、收尾与全量验证

**Files:**
- Modify: `Sources/App/Localizable.xcstrings`（补齐新增中文文案键，如已用中文字面量则确认无缺项）
- Modify: `README.md`

- [ ] **Step 1: 补齐本地化与文案一致性**

检查新增视图中的 `LocalizedStringKey` 文案是否都在 `Localizable.xcstrings` 有条目（沿用既有中文本地化机制）。若采用直接中文字面量，确认与既有风格一致。

- [ ] **Step 2: 更新 README**

在 `README.md` 增补一段「离线 Session 伴侣 V1」说明：Session 外壳（setup/active/landed）、Journey Pass 买断解锁 Session 模式、2048 永久免费、隐私/本地优先。

- [ ] **Step 3: 全量测试 + 构建（最终验证）**

Run: `xcodegen generate && xcodebuild test -project Game2048.xcodeproj -scheme Game2048 -destination 'platform=iOS Simulator,name=iPhone 17 Pro' 2>&1 | tail -30`
Expected: `** TEST SUCCEEDED **`，六个 Suite 全绿。

- [ ] **Step 4: 手动冒烟（模拟器）**

- setup 态：未解锁时可「直接玩 2048」；点「解锁 Session 模式」→ 购买页 → `.storekit` 沙盒购买成功 → 回到 setup，出现「开始断网时段」。
- active 态：进入安静环境玩 2048；切后台再回前台，进度不丢。
- landed 态：点「落地」→ 展示时长 → 「结束」清场回 setup。

- [ ] **Step 5: 提交**

```bash
git add Sources/App/Localizable.xcstrings README.md
git commit -m "docs: V1 离线 Session 伴侣本地化与 README 收尾"
```

---

## Self-Review 记录

- **Spec 覆盖**：Session 状态机（T1）、SessionController begin/pause/resume/land（T2）、进度绝不丢失/存档（T2/T3）、Journey Pass 买断+权益本地持久化+恢复（T4/T5）、2048 永不被墙（setup「直接玩」+ FreePlay，T6）、候机室在线购买/离线降级（T7）、active 安静环境/landed 收尾/自愿同步（T8）、离线轻提示可永久关闭（T9）、审美即产品（每个 UI 任务前置 design skill，T6–T8）、测试策略（Swift Testing + StoreKitTest，各 Suite）。V1 YAGNI 项（激励视频/强制云端/SLM/按次通行证）均未引入。
- **类型一致性**：`Session.state/plannedDuration/activityLog/pausedAt/accumulatedPause`、`SessionActivity.Kind.game2048`、`SessionController.begin(duration:)/pause()/resume()/land()/close()/elapsedActiveTime()`、`GameStorage.currentSession/journeyPassUnlocked/offlineNudgeDisabled`、`JourneyPassStore.productID/product/isUnlocked/loadProduct()/purchase()/refreshEntitlements()/restore()/PurchaseError` 在各任务间签名一致。
- **执行顺序提醒**：Task 3 必须先于 Task 2（`SessionController` 依赖 `GameStorage.currentSession`）。UI 任务（T6–T9）动手前先调用 `superpowers:design`。
```
