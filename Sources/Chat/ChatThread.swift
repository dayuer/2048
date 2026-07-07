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
