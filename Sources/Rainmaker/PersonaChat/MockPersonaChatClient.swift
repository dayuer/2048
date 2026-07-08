import Foundation

/// 确定性桩：不联网，按 intent/人设返回可预期文本。
/// 供单测、离线预览，也证明请求契约自洽（各意图分支都拿得到需要的字段）。
struct MockPersonaChatClient: PersonaChatClient {
    /// 自定义变换（测试可注入以断言请求内容）。为空则走默认套路。
    var transform: (@Sendable (PersonaChatRequest) -> String)?

    init(transform: (@Sendable (PersonaChatRequest) -> String)? = nil) {
        self.transform = transform
    }

    func reply(for request: PersonaChatRequest) async throws -> String {
        if let transform {
            return transform(request)
        }
        let name = request.npc.name
        switch request.intent {
        case .greeting:
            return "【\(name)·人设】\(request.npc.role)跟你寒暄了一句。"
        case .dealIntro:
            return "【\(name)·人设】有个「\(request.deal?.title ?? "项目")」想请你操盘。"
        case .reply:
            return "【\(name)·人设】收到：\(request.playerMessage ?? "")"
        case .ambient:
            return "【\(name)·人设】随口聊两句。"
        case .negotiationOpen:
            return "【\(name)·谈判】应战：底线不好压。"
        case .negotiationHurt:
            return "【\(name)·谈判】被【\(request.negotiation?.cardName ?? "?")】打痛，底线剩 \(request.negotiation?.defenseRemainingPercent ?? -1)%。"
        case .negotiationTaunt:
            return "【\(name)·谈判】嘲讽：【\(request.negotiation?.cardName ?? "?")】对我没用。"
        case .negotiationSign:
            return "【\(name)·谈判】签约成交。"
        case .negotiationBreak:
            return "【\(name)·谈判】底线击穿，认输。"
        case .negotiationBust:
            return "【\(name)·谈判】谈崩翻脸。"
        }
    }
}
