# WhatsApp iOS UI 复刻 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 按 [复刻 spec](../specs/2026-07-08-whatsapp-ui-replica-design.md) 把外壳视觉从微信风整体替换为 WhatsApp iOS 复刻（深浅色自适应），IA 与全部逻辑不动。

**Architecture:** 一个新设计系统文件 `WhatsAppTheme.swift`（`WA` token + 按钮样式 + `WAAvatar` + `WADoodleWallpaper` + `BubbleShape`）取代 `ShellTheme.swift`，随后 6 个视图文件换 token 与结构（列表行/气泡/输入条/分组设置）。纯视觉层：不碰 Chat/Games/引擎/存储。

**Tech Stack:** SwiftUI（Canvas 自绘涂鸦、`Color(UIColor{traits})` 深浅色自适应）、复用 `SeededGenerator` 做确定性涂鸦布局。

---

## 全局须知

- 新增/删除文件后 `xcodegen generate` 再 xcodebuild。
- 纯视觉层无新单测；验证 = 全量既有测试保持绿 + 模拟器浅/深双截屏对照。
- known-issue：`JourneyPassStoreIntegrationTests` CLI 下 3 个 StoreKit known issue，视为通过。

### Task 1: WhatsAppTheme 设计系统（删 ShellTheme，建 WA token + 组件）

**Files:**
- Delete: `Sources/UI/ShellTheme.swift`
- Create: `Sources/UI/WhatsAppTheme.swift`

内容：`WA` enum（spec 色板表全部 token，`adaptive(light:dark:)` 用 `Color(UIColor{traits})`；分组底直接用系统色）；`WAPrimaryButtonStyle`（绿整宽 pill、按压压暗 + `scaleEffect(0.98)`）；`WATextButtonStyle`；`WAAvatar(systemImage:background:size:)` 圆形头像；`WADoodleWallpaper`（chatCanvas 底 + Canvas 平铺 SF Symbols，`SeededGenerator(seed: 2048)` 定种子抖动，doodle 色）；`BubbleShape(mine:)`（圆角 8 + 顶部外侧尾巴的 Path）。中间态编译断裂（5 个视图仍引用 `Shell.`）——Task 2 一起修复后统一验证。

### Task 2: 六视图换装

**Files:**
- Modify: `Sources/UI/ChatListView.swift`、`ThreadView.swift`、`NearbyView.swift`、`GameLibraryView.swift`、`MeView.swift`、`TabShellView.swift`

按 spec「组件复刻要点」逐一：ChatList（大标题 + searchable + 52pt 圆头像行 + 右上时间戳 + 真人线程左滑删除）；Thread（principal 头像标题、涂鸦画布、带尾气泡 + 气泡内时间戳、battleResult 中置 pill、AI 绿「开战」/真人禁用输入条）；Nearby/GameLibrary token 换装；Me 复刻 Settings（insetGrouped + 个人行 + 彩色图标行）；TabShell tint `WA.accent`。

### Task 3: 全量验证 + 双模式截屏 + Commit

- `xcodegen generate` + 全量 xcodebuild test：全绿（53 tests，3 known issues）。
- 模拟器安装启动：浅色截屏对话列表 + AI 线程 + 我 tab；`simctl ui ... appearance dark` 后再截线程页。
- Commit：`feat: 外壳视觉复刻 WhatsApp iOS（WA 设计系统/涂鸦画布/带尾气泡/深浅色），替换微信风`
