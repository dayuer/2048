import SwiftUI

/// 编排：输入 → 引擎 → 按 Beat 时间线两阶段动画 → 存档。
@MainActor
@Observable
final class GameViewModel {
    enum Overlay {
        case none, won, lost
    }

    private(set) var engine: GameEngine
    /// BoardView 渲染的方块（滑动阶段与引擎最终状态之间的过渡帧）。
    private(set) var displayTiles: [DisplayTile]
    private(set) var bestScore: Int
    private(set) var overlay: Overlay = .none
    private(set) var scoreDelta = 0
    private(set) var scoreDeltaID = 0

    private let storage: GameStorage
    private var isAnimating = false

    /// 顿悟钩子：单局内首次合成里程碑数字时回调（沙盘零依赖 Rainmaker，由外壳注入）。
    var onMilestone: ((Int) -> Void)?
    /// 本局已触发过的里程碑（续档时按当前最大方块回填，避免恢复即重触发）。
    private var reachedMilestones: Set<Int>

    var score: Int { engine.score }

    /// 顿悟里程碑数值表。
    static let milestoneValues: Set<Int> = [128, 256, 512, 1024, 2048]

    init(storage: GameStorage = GameStorage()) {
        self.storage = storage
        let engine = storage.gameState ?? GameEngine(seed: .random(in: .min ... .max))
        self.engine = engine
        self.displayTiles = Self.displayTiles(of: engine)
        self.bestScore = storage.bestScore
        self.reachedMilestones = Self.milestoneValues.filter { $0 <= engine.biggestTile }
        if engine.won && !engine.keepPlaying { overlay = .won }
    }

    /// 本次 Resolution 里新达成的里程碑（纯函数，可测）。
    nonisolated static func newMilestones(in resolution: Resolution<Int>, reached: Set<Int>) -> [Int] {
        let merged = resolution.beats.flatMap(\.transforms).map(\.payload)
        return merged
            .filter { milestoneValues.contains($0) && !reached.contains($0) }
            .sorted()
    }

    private static func displayTiles(of engine: GameEngine) -> [DisplayTile] {
        engine.grid.occupied.map { DisplayTile(id: $0.tile.id, value: $0.tile.payload, coord: $0.coord) }
    }

    func move(_ direction: Direction) {
        guard !isAnimating else { return }
        let resolution = engine.apply(direction)
        guard let slideBeat = resolution.beats.first else { return }
        isAnimating = true

        // 滑动拍：按 moves 更新位置（合并双方都汇聚到目标格）
        let targets = Dictionary(uniqueKeysWithValues: slideBeat.moves.map { ($0.id, $0.to) })
        var slid = displayTiles
        for index in slid.indices {
            if let to = targets[slid[index].id] { slid[index].coord = to }
        }
        // easeOut：减速滑入、平稳到位
        withAnimation(.easeOut(duration: 0.1)) {
            displayTiles = slid
        }

        Task {
            try? await Task.sleep(for: .milliseconds(100))
            // 落定拍：合并产物与新方块纯淡入，无弹跳
            withAnimation(.easeOut(duration: 0.12)) {
                displayTiles = Self.displayTiles(of: engine)
            }
            finishMove(resolution)
            isAnimating = false
        }
    }

    private func finishMove(_ resolution: Resolution<Int>) {
        if resolution.scoreDelta > 0 {
            scoreDelta = resolution.scoreDelta
            scoreDeltaID += 1
        }
        for milestone in Self.newMilestones(in: resolution, reached: reachedMilestones) {
            reachedMilestones.insert(milestone)
            onMilestone?(milestone)
        }
        if engine.score > bestScore {
            bestScore = engine.score
            storage.bestScore = bestScore
        }
        if engine.biggestTile > storage.biggestTile {
            storage.biggestTile = engine.biggestTile
        }
        if engine.isTerminal {
            storage.gameState = nil
            overlay = .lost
        } else {
            storage.gameState = engine
            if engine.won && !engine.keepPlaying { overlay = .won }
        }
    }

    func newGame() {
        storage.gameState = nil
        engine = GameEngine(seed: .random(in: .min ... .max))
        overlay = .none
        reachedMilestones = []
        withAnimation(.easeOut(duration: 0.2)) {
            displayTiles = Self.displayTiles(of: engine)
        }
    }

    func keepGoing() {
        engine.continueAfterWin()
        storage.gameState = engine
        overlay = .none
    }
}
