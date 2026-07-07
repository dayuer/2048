/// 真正的普遍法：任何玩法 conform 即可作为一个「活动」进入断网 Session，
/// 并自动获得存档/恢复（因 Codable）。Session 外壳只认识本协议，不认识具体游戏。
protocol SessionActivity: Codable {
    /// 供 Session 路由与 UI 选择渲染器。
    static var kind: ActivityKind { get }
    /// 落地收尾展示的本地只读摘要。
    var summary: ActivitySummary { get }
}

enum ActivityKind: String, Codable, Sendable {
    case grid2048, match3
}

struct ActivitySummary: Codable, Equatable, Sendable {
    let headline: String
    let score: Int?
}
