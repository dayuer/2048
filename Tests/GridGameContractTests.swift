import Foundation
import Testing
@testable import Game2048

/// 基本法契约一致性断言：任何 GridGameEngine 都应通过。
enum GridGameContract {
    /// 网格形状（坐标→payload）。UUID 非种子派生，不参与确定性比较。
    static func shape<E: GridGameEngine>(_ engine: E) -> [Coord: E.Payload] {
        Dictionary(uniqueKeysWithValues: engine.grid.occupied.map { ($0.coord, $0.tile.payload) })
    }

    /// 同种子开局形状一致。
    static func assertDeterministicStart<E: GridGameEngine>(_ type: E.Type, seed: UInt64) {
        #expect(shape(E(seed: seed)) == shape(E(seed: seed)))
    }

    /// Codable 往返后施加同一操作，形状与得分一致（RNG 状态随档恢复）。
    static func assertCodableRoundTripPreservesApply<E: GridGameEngine>(_ engine: E, action: E.Action) throws {
        var original = engine
        let data = try JSONEncoder().encode(engine)
        var restored = try JSONDecoder().decode(E.self, from: data)
        let a = original.apply(action)
        let b = restored.apply(action)
        #expect(shape(original) == shape(restored))
        #expect(a.scoreDelta == b.scoreDelta)
        #expect(a.beats.count == b.beats.count)
    }

    /// 时间线 id 自洽：moves/removals/consumed 引用当拍已知的块；
    /// spawns/produced 是新块；回放完毕后的存活集合 == 结算后棋盘上的块。
    static func assertTimelineIDsConsistent<E: GridGameEngine>(_ start: E, action: E.Action) {
        var engine = start
        var known = Set(engine.grid.occupied.map(\.tile.id))
        let resolution = engine.apply(action)
        for beat in resolution.beats {
            for move in beat.moves { #expect(known.contains(move.id)) }
            for removal in beat.removals {
                #expect(known.contains(removal.id))
                known.remove(removal.id)
            }
            for transform in beat.transforms {
                for consumed in transform.consumed {
                    #expect(known.contains(consumed))
                    known.remove(consumed)
                }
                #expect(!known.contains(transform.produced))
                known.insert(transform.produced)
            }
            for spawn in beat.spawns {
                #expect(!known.contains(spawn.id))
                known.insert(spawn.id)
            }
        }
        #expect(Set(engine.grid.occupied.map(\.tile.id)) == known)
    }
}

@Suite struct Game2048ContractTests {
    /// 从种子局面走几步，得到一个"棋局中段"引擎（比开局更能暴露契约问题）。
    private func midGameEngine() -> GameEngine {
        var engine = GameEngine(seed: 99)
        _ = engine.apply(.left)
        _ = engine.apply(.up)
        return engine
    }

    @Test func deterministicStart() {
        GridGameContract.assertDeterministicStart(GameEngine.self, seed: 2048)
    }

    @Test func codableRoundTripPreservesApply() throws {
        try GridGameContract.assertCodableRoundTripPreservesApply(midGameEngine(), action: .down)
    }

    @Test func timelineIDsConsistent() {
        for direction in Direction.allCases {
            GridGameContract.assertTimelineIDsConsistent(midGameEngine(), action: direction)
        }
    }

    @Test func sessionActivityConformance() {
        #expect(GameEngine.kind == .grid2048)
        let engine = midGameEngine()
        #expect(engine.summary.headline == "2048")
        #expect(engine.summary.score == engine.score)
    }
}
