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
        }
    }
}
