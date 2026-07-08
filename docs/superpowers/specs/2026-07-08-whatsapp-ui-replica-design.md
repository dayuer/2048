# WhatsApp iOS UI 原样复刻（外壳视觉层）设计文档

日期：2026-07-08
上位：`2026-07-08-whatsapp-shell-ia-design.md`（IA 不变，本文档只改视觉层）。
决策（用户已确认）：**保留 4 tab IA、样式按 WhatsApp iOS 复刻**；聊天背景 = **米色底 + 自绘涂鸦**（不用 WhatsApp 版权素材）；**浅色 + 深色**双模式。

## 一句话概念

**把外壳的「微信风」设计系统整体替换为「WhatsApp iOS」复刻：绿主行动、大标题列表 + 圆形头像、米色涂鸦聊天画布、带尾巴的气泡、iOS 分组设置页；IA（对话/附近/游戏/我）与全部逻辑不动。**

## 设计系统（`WA` token，全部深浅色自适应）

| Token | 浅色 | 深色 | 用途 |
|---|---|---|---|
| accent | `#1DAB61` | `#21C063` | 主行动绿（按钮/选中 tab/开关） |
| chatCanvas | `#EFEAE2` | `#0B141A` | 聊天页画布（米色/近黑） |
| doodle | `#C5BCAD` | `#233138` | 自绘涂鸦纹理色（极淡） |
| bubbleOut | `#D9FDD3` | `#005C4B` | 发出气泡 |
| bubbleIn | `#FFFFFF` | `#202C33` | 收到气泡 / 中置卡片 |
| listBg | `#FFFFFF` | `#111B21` | 列表页底 |
| textPrimary | `#111B21` | `#E9EDEF` | 主文字 |
| textSecondary | `#667781` | `#8696A0` | 次要文字 / 时间戳 |
| separator | `#E9EDEF` | `#222D34` | 发丝分隔线 |
| avatarBg | `#DFE5E7` | `#6A7175` | 默认头像底（灰圆 + 白剪影） |

- 分组页（我 tab）直接用系统 `systemGroupedBackground` / `secondarySystemGroupedBackground`（WhatsApp iOS 设置页即系统分组样式）。
- 自适应实现：`Color(UIColor { traits in ... })`。
- 按钮：`WAPrimaryButtonStyle`（绿填充整宽 pill，按压压暗微缩）、`WATextButtonStyle`（绿文字链）。
- 头像：`WAAvatar` 圆形（52pt 列表 / 32pt 线程导航），灰底白剪影；AI 线程用绿底 `cpu.fill`。

## 组件复刻要点

- **对话列表（Chats 复刻）**：大标题「对话」+ `.searchable` 搜索框；行 = 52pt 圆头像 + 名字（17 semibold）+ 最近事件摘要（15 gray，单行）+ 右上时间戳（15 gray）；分隔线从文字列起缩进；真人线程左滑删除（红），AI 线程不可删。
- **线程页（Conversation 复刻）**：导航栏 principal = 32pt 头像 + 名字/副题；背景 = `WADoodleWallpaper`（chatCanvas 底 + Canvas 自绘涂鸦：游戏/飞机/星星等 SF Symbols 网格微抖动平铺，`SeededGenerator` 定种子确定性布局，观感极淡）；气泡 = `BubbleShape` 圆角 8 + 顶部外侧小尾巴，时间戳在气泡内右下（11pt）；`battleInvite` 按 mine 走气泡样式（旗帜图标 + 种子），`battleResult` 走 WhatsApp 中置系统 pill 卡（如原版加密提示条）；AI 线程底部 = 绿整宽「开战」pill；真人线程底部 = 复刻 WhatsApp 输入条的禁用态（＋ / 圆角输入框占位文案 / 麦克风，全灰禁用）。
- **附近**：结构不变，token 换 WA（绿 accent、系统分组底、灰圆大图标底）。
- **游戏**：行样式对齐对话列表（48pt 圆角方图标 + 名称 + chevron）。
- **我（Settings 复刻）**：`insetGrouped`；顶部个人行（58pt 头像 + 昵称 20pt + 「本机临时身份」副题 + 「重掷」绿文字钮）；「隐私」组每行 28pt 圆角方彩色图标（绿锁/蓝手机/红垃圾桶）+ 文案。
- **TabShell**：系统 TabView + `WA.accent` tint（WhatsApp iOS 即系统 tab bar + 绿选中）。
- **诚实原则不破**：不加任何假功能入口（不加打不开的相机/新建会话按钮）。
- **2048 棋盘不动**：`Theme.swift`（经典橙棕）是游戏本体的皮肤，非外壳。

## 拆改清单

- 删除 `Sources/UI/ShellTheme.swift`（`Shell` token + WeChat 按钮样式）→ 新增 `Sources/UI/WhatsAppTheme.swift`（`WA` token + `WAPrimaryButtonStyle`/`WATextButtonStyle` + `WAAvatar` + `WADoodleWallpaper` + `BubbleShape`）。
- 改 5 个消费视图（ChatList/Thread/Nearby/GameLibrary/Me）+ TabShell 的全部 `Shell.` 引用与按钮样式名。
- 逻辑零变更：`ChatStore`/`GameRegistry`/`EphemeralIdentity`/引擎/存储全部不动。

## 测试与验收

- 全量既有单测保持绿（纯视觉层，无逻辑变更；不为颜色写单测）。
- 模拟器冒烟：浅色 + 深色各截屏验证四 tab、AI 线程气泡/涂鸦画布、我 tab 分组样式。
- 验收基准：对照 WhatsApp iOS 截图，色板/气泡形态/列表行结构一眼可辨为同款。

## 不做的事

- 不做已读回执双勾、语音/相机真功能、未读角标（无真消息源，不造假数据）。
- 不引入任何 WhatsApp 版权素材（涂鸦全自绘、图标全 SF Symbols）。
- 不改 IA、导航结构、数据模型。
