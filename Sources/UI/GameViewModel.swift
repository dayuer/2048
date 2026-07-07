import SwiftUI

/// 编排：输入 → 引擎 → 按 Beat 时间线两阶段动画 → 存档 → Game Center 提交。
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
    private let gameCenter: GameCenterManager
    private var isAnimating = false

    var score: Int { engine.score }

    init(storage: GameStorage = GameStorage(), gameCenter: GameCenterManager) {
        self.storage = storage
        self.gameCenter = gameCenter
        let engine = storage.gameState ?? GameEngine(seed: .random(in: .min ... .max))
        self.engine = engine
        self.displayTiles = Self.displayTiles(of: engine)
        self.bestScore = storage.bestScore
        if engine.won && !engine.keepPlaying { overlay = .won }
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
        if engine.score > bestScore {
            bestScore = engine.score
            storage.bestScore = bestScore
            gameCenter.submitBestScore(bestScore)
        }
        if engine.biggestTile > storage.biggestTile {
            storage.biggestTile = engine.biggestTile
            gameCenter.submitBiggestTile(engine.biggestTile)
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
        withAnimation(.easeOut(duration: 0.2)) {
            displayTiles = Self.displayTiles(of: engine)
        }
    }

    func keepGoing() {
        engine.continueAfterWin()
        storage.gameState = engine
        overlay = .none
    }

    func showLeaderboard() {
        gameCenter.showLeaderboard()
    }
}
