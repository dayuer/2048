import Foundation

/// 一次操作的确定性结算时间线：UI 按拍回放即为动画。
/// 不合法/无变化的操作 = beats 为空。
struct Resolution<Payload: Codable & Equatable>: Codable, Equatable {
    var beats: [Beat<Payload>]
    var scoreDelta: Int

    init(beats: [Beat<Payload>] = [], scoreDelta: Int = 0) {
        self.beats = beats
        self.scoreDelta = scoreDelta
    }
}

/// 一拍内同时发生的原子块变化（四类封闭词汇，不泄漏任何游戏机制）。
struct Beat<Payload: Codable & Equatable>: Codable, Equatable {
    var moves: [Move]
    var spawns: [Spawn<Payload>]
    var removals: [Removal]
    var transforms: [Transform<Payload>]

    init(
        moves: [Move] = [],
        spawns: [Spawn<Payload>] = [],
        removals: [Removal] = [],
        transforms: [Transform<Payload>] = []
    ) {
        self.moves = moves
        self.spawns = spawns
        self.removals = removals
        self.transforms = transforms
    }
}

/// 位移：块从 A 移到 B。
struct Move: Codable, Equatable {
    let id: UUID
    let from: Coord
    let to: Coord
}

/// 无中生有（0→1）：新块出现。
struct Spawn<Payload: Codable & Equatable>: Codable, Equatable {
    let id: UUID
    let at: Coord
    let payload: Payload
}

/// 彻底消失（N→0）：块消失且不留下任何东西。
struct Removal: Codable, Equatable {
    let id: UUID
    let at: Coord
}

/// 合成/升级（N→1）：consumed 全部消失，产出物 produced 出现在 at、携带新 payload。
struct Transform<Payload: Codable & Equatable>: Codable, Equatable {
    let consumed: [UUID]
    let produced: UUID
    let at: Coord
    let payload: Payload
}
