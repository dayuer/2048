import Foundation

/// 把 PersonaChatRequest 组装成「系统提示 + 用户提示」两段。
/// 系统段 = 军规 + 人设五维 + 世界观语感（所有场景共享）；
/// 用户段 = 近期对话誊本 + 按 intent 分板块的场景指令。
/// 本地直连各家 LLM 时共用这一份组装；后台接入（第二步）可在服务端复刻同一结构。
enum ScenarioPrompts {
    struct Prompt: Equatable, Sendable {
        let system: String
        let user: String
    }

    static func build(for request: PersonaChatRequest) -> Prompt {
        Prompt(system: systemPrompt(for: request), user: userPrompt(for: request))
    }

    // MARK: - 系统段：你是谁 + 怎么说话

    private static func systemPrompt(for request: PersonaChatRequest) -> String {
        let npc = request.npc
        let p = npc.persona
        return """
        你在一部以北京金融圈为舞台的沉浸式实战剧中扮演一个真实人物，正通过微信和一位独立财务顾问（FA）对话。\
        铁律：任何时候都不能让对方看出这是游戏或 AI——你就是这个人。

        【你是谁】\(npc.name)，\(npc.role)。
        · 背景：\(p.background)
        · 声线：\(p.voice)
        · 在意：\(p.values)
        · 癖好：\(p.quirks)
        · 谈判风格：\(p.negotiationStance)

        【语感】金装律师式的优雅施压，术语要真实金融圈的；微信短消息口吻，一到两句话，别写长段。

        【输出】只输出你要发的那条微信消息本身：不加引号、不加动作或心理描写、不解释、不列点、不出戏。
        """
    }

    // MARK: - 用户段：对话誊本 + 场景指令

    private static func userPrompt(for request: PersonaChatRequest) -> String {
        var sections: [String] = []
        if !request.history.isEmpty {
            let transcript = request.history
                .map { turn in
                    (turn.role == .npc ? "你" : "对方（FA）") + "：" + turn.text
                }
                .joined(separator: "\n")
            sections.append("【最近对话】\n\(transcript)")
        }
        sections.append("【当前场景】\n\(sceneInstruction(for: request))")
        sections.append("现在发出你的下一条微信消息：")
        return sections.joined(separator: "\n\n")
    }

    private static func sceneInstruction(for request: PersonaChatRequest) -> String {
        let ctx = request.negotiation
        let title = ctx?.dealTitle ?? request.deal?.title ?? "这单生意"
        switch request.intent {
        case .greeting:
            return "新的一天，你主动给对方发一句寒暄开场，带上你的近况或口头禅，别提任何具体项目数字。"
        case .dealIntro:
            var line = "你手上有个项目想请对方牵线操盘：《\(title)》"
            if let deal = request.deal {
                line += "，估值约 \(deal.valuation) 万，佣金 \(deal.commission) 万"
            }
            line += "。先发一句铺垫勾起兴趣——数字别一次全抖出来，项目单随后会正式发过去。"
            return line
        case .reply:
            return "对方刚发来：「\(request.playerMessage ?? "")」。用你的方式回一句。"
        case .ambient:
            return "没什么特别的事，随口发一句你这个人会发的闲话。"
        case .negotiationOpen:
            return "谈判桌：对方要就《\(title)》跟你当面谈条款。你应战，放一句话表明你的底线不好压。"
        case .negotiationHurt:
            var line = "条款谈判中，对方打出【\(ctx?.cardName ?? "一记策略")】命中了你的软肋"
            if let damage = ctx?.damage {
                line += "，压掉你 \(damage) 点底线"
            }
            if let remaining = ctx?.defenseRemainingPercent {
                line += "（还剩 \(remaining)%）"
            }
            line += "。你吃痛但不失身段，回一句。"
            return line
        case .negotiationTaunt:
            var line = "对方在谈判桌打出【\(ctx?.cardName ?? "一记策略")】，但这招对你这类人完全无效"
            if let knowledge = ctx?.cardKnowledge, !knowledge.isEmpty {
                line += "（行内常识：\(knowledge)）"
            }
            line += "。用你的方式嘲讽他不懂行。"
            return line
        case .negotiationSign:
            return "《\(title)》的条款谈判里对方压价压得有分寸，你决定见好就收、按当前条件签约。说句签约收尾的场面话。"
        case .negotiationBreak:
            return "《\(title)》谈判中你的底线被彻底击穿，只能认输、全按对方条件办。服气又有点不甘，说一句。"
        case .negotiationBust:
            return "对方筹码打光也没能撼动你，《\(title)》谈崩了。翻脸下逐客令，这单到此为止。"
        }
    }
}
