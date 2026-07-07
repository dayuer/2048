import SwiftUI

/// 编排：输入 → 引擎 → 两阶段动画 → 存档 → Game Center 提交。
@MainActor
@Observable
final class GameViewModel {
    enum Overlay {
        case none, won, lost
    }

    private(set) var engine: GameEngine
    /// BoardView 渲染的方块（滑动阶段与引擎最终状态之间的过渡帧）。
    private(set) var displayTiles: [Tile]
    private(set) var bestScore: Int
    private(set) var overlay: Overlay = .none
    private(set) var scoreDelta = 0
    private(set) var scoreDeltaID = 0

    private let storage: GameStorage
    private let gameCenter: GameCenterManager
    private var rng = SystemRandomNumberGenerator()
    private var isAnimating = false

    var score: Int { engine.score }

    init(storage: GameStorage = GameStorage(), gameCenter: GameCenterManager) {
        self.storage = storage
        self.gameCenter = gameCenter
        var rng = SystemRandomNumberGenerator()
        let engine = storage.gameState ?? GameEngine.newGame(using: &rng)
        self.engine = engine
        self.displayTiles = engine.tiles
        self.bestScore = storage.bestScore
        if engine.won && !engine.keepPlaying { overlay = .won }
    }

    func move(_ direction: Direction) {
        guard !isAnimating, let result = engine.move(direction, using: &rng) else { return }
        isAnimating = true

        // easeOut：减速滑入、平稳到位
        withAnimation(.easeOut(duration: 0.1)) {
            displayTiles = result.slidTiles
        }

        Task {
            try? await Task.sleep(for: .milliseconds(100))
            // 合并/新方块纯淡入，无弹跳
            withAnimation(.easeOut(duration: 0.12)) {
                displayTiles = engine.tiles
            }
            finishMove(result)
            isAnimating = false
        }
    }

    private func finishMove(_ result: MoveResult) {
        if result.scoreGained > 0 {
            scoreDelta = result.scoreGained
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
        if engine.over {
            storage.gameState = nil
            overlay = .lost
        } else {
            storage.gameState = engine
            if engine.won && !engine.keepPlaying { overlay = .won }
        }
    }

    func newGame() {
        storage.gameState = nil
        engine = GameEngine.newGame(using: &rng)
        overlay = .none
        withAnimation(.easeOut(duration: 0.2)) {
            displayTiles = engine.tiles
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
