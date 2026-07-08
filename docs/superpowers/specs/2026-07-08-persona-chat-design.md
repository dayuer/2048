# 生成式对话拟真层（Persona Chat）设计

> 状态：app 端实现中；survival 端点本文只定契约，日后实现。
> 关联：把 `~/sproot/survival` 的「AI 数字人沟通模式」精华挪进 Rainmaker。

## 背景与目标

survival 的数字人本质是**生成式对话架构**：Agent 人设（persona system-prompt）+ 分层模型路由（Tier R 读意图 → Tier S/F 人设体回话）+ RAG 知识检索 + 实时画像。让数字人「像活人」：一致声线、记忆连续、按意图回应、先想后说。

Rainmaker 现状：NPC 是静态台词池（`NPCCatalog` 的 `greetings`/`smallTalk`），`RainmakerEngine.sendMessage` 随机抽一句，无记忆、无意图。唯一「活」的是 `RainmakerStore` 的投递表现层（「正在输入…」节奏）。

**本设计**：引入联网 LLM，让**联系人 NPC 的对话文本**（自由闲聊 + 每日寒暄 + 项目单开场铺垫）生成式、拟真为主。项目推进仍走确定性谈判卡（`NegotiationEngine`，不动）。链路：`2048 app → survival OpenClaw 后端 → LLM`，Key 在服务端。

## 核心纪律：生成式 = 显示层覆盖

纯 `RainmakerEngine` 保持确定性、同步、可回放、离线单测全绿。生成式回复是**表现层叠加**，与 `revealedCounts`/`typingNPCIDs` 同一性质：

- **真相层**（持久化的 `RainmakerState.threads`）永远存确定性台词池文本，测试与离线看这层，永不变、不进存档、不影响回放与既有断言。
- LLM 文本只存在于 `RainmakerStore.generatedText: [UUID: String]`（事件 id → 生成文本，**不持久化**）。
- UI 渲染 `store.displayText(for: event) == generatedText[id] ?? 事件原文`。
- 默认未配置 client → 行为与今天逐字节一致（默认关闭）。

## 数据流

```
玩家发消息 / 新的一天生成寒暄+项目卡  →  纯 Engine 同步写台词池 npcText 进真相层
  → commit → scheduleDelivery → Store.deliver() 逐条揭示
    → 下一条若为「联系人 npcText」且 personaChat 已配置：
        typingNPCIDs.insert → await personaChat.reply(request)
          成功 → generatedText[id] = 文本；失败/断网 → 落既有 900ms + 台词池文本
      → reveal
  → UI 渲染 displayText(for:)
```

网络延迟天然充当「正在输入…」的「先想后说」节奏。`instantDelivery`（测试快路径）跳过 `deliver()`，因而跳过增强——增强只在真实投递路径发生。

## app 端组件

- `Sources/Rainmaker/PersonaChat/PersonaChatClient.swift`：协议 + Codable DTO。
- `Sources/Rainmaker/PersonaChat/OpenClawChatClient.swift`：`URLSession` async 实现，超时即 throw（触发回退）。
- `Sources/Rainmaker/PersonaChat/MockPersonaChatClient.swift`：确定性桩，供单测/离线预览，且证明契约自洽。
- `Sources/Rainmaker/PersonaChat/PersonaChatConfig.swift`：`baseURL` + `enabled`（默认关闭）+ `makeClient()`；从 Info.plist 读取；在 `RainmakerRootView` 注入 `store.personaChat`。
- `NPCCatalog`：新增 `NPCPersona`（Codable）并给 5 位角色补人设——survival「Agent 人设」的落地。
- `RainmakerStore`：`personaChat`、`generatedText`、`deliver()` 增强、`displayText(for:)`、`buildRequest`。
- `RainmakerEngine`：抽 `poolReply(for:using:)` 供回退复用（行为等价）。
- `RainmakerThreadView`：npc 气泡改用 `store.displayText(for: event)`。

## 意图推断（Store 端，零成本）

对第 `index` 条联系人 `npcText`：

- 前驱是 `playerText` → `intent = .reply`，`playerMessage` = 该文本。
- 后继是 `dealOffer` → `intent = .dealIntro`，`deal` = 该 offer 的 title/valuation/commission。
- 否则 → `intent = .greeting`。
- `.ambient` 保留在契约里，本期不主动产出。

`history` = 该线程该事件之前的可见事件（npcText/playerText），npc 侧取 `displayText`（含已生成文本，保证记忆连续）。

## survival 端契约（本文只定，不实现）

`POST {baseURL}/openclaw/rainmaker-chat`

请求体（= app 端 `PersonaChatRequest` 的 JSON）：

```json
{
  "npc": {
    "id": "chen",
    "name": "陈总",
    "role": "SaaS 创始人",
    "persona": {
      "background": "...",
      "voice": "...",
      "values": "...",
      "quirks": "...",
      "negotiationStance": "..."
    }
  },
  "history": [{ "role": "npc|player", "text": "..." }],
  "intent": "greeting|deal_intro|reply|ambient",
  "deal": { "title": "...", "valuation": 12000, "commission": 24 },
  "playerMessage": "玩家刚发的话（intent=reply 时）"
}
```

响应：`{ "reply": "一句符合人设、读懂意图的中文回复" }`（v1）。

服务端职责（对应 survival 精华）：
1. 按 `npc.persona` 组 system-prompt（人设一致声线）。
2. 选 **Tier F**（`deepseek-chat`，聊天低延迟低成本，见 `survival/.env.example`）。
3. 可选：对 Rainmaker Glossary 词条做 RAG grounding，让术语用得地道。
4. 调 LLM，返回单句中文回复。

当前 `survival/routers/openclaw.py` 的 `/openclaw/chat` 是占位；日后按此契约新增 `/openclaw/rainmaker-chat`。

## 验证

- 既有 `RainmakerEngineTests`/`ChatFlowTests`/`RainmakerStoreTests` 全绿（真相层不变）= 离线确定性未被破坏的硬证据。
- 新增 `PersonaChatTests`：
  1. 注入 `MockPersonaChatClient` + 真实投递路径 → `displayText` 返回 mock 文本、`generatedText` 被填充。
  2. 注入必抛错 client → `displayText` 回退台词池原文；真相层文本不变。
  3. `personaChat == nil`（默认）→ 与现状逐字节一致。

## 显式不做（本期外）

- 不动谈判卡算分；谈判杆子台词保持确定性。
- 不做关系/情绪数值演化（记忆先用最近 N 轮 history，情绪标量留后续 Phase）。
- 不实现 survival 端点（只契约）；ATS/LAN http 例外等真实端点落地时再处理。
- app 内不存 Key（Key 在服务端），app 只需 baseURL。
