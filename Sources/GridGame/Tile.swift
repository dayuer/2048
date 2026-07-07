import Foundation

/// 稳定标识的块：id 贯穿生命周期，供 UI 追踪动画。
/// 2048 的数字块、消消乐的宝石都是它的实例（payload 各游戏自定义）。
struct Tile<Payload: Codable & Equatable>: Codable, Identifiable, Equatable {
    let id: UUID
    var payload: Payload

    init(id: UUID = UUID(), payload: Payload) {
        self.id = id
        self.payload = payload
    }
}

extension Tile: Sendable where Payload: Sendable {}
