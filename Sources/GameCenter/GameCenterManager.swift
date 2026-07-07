import GameKit
import SwiftUI

/// Game Center 认证与排行榜提交。未登录/失败一律静默降级，不打断游戏。
@MainActor
@Observable
final class GameCenterManager {
    enum LeaderboardID {
        static let bestScore = "best_score"
        static let biggestTile = "biggest_tile"
    }

    private(set) var isAuthenticated = false

    func authenticate() {
        GKLocalPlayer.local.authenticateHandler = { viewController, _ in
            Task { @MainActor [weak self] in
                if let viewController {
                    Self.rootViewController?.present(viewController, animated: true)
                }
                self?.isAuthenticated = GKLocalPlayer.local.isAuthenticated
            }
        }
    }

    func submitBestScore(_ score: Int) {
        submit(score, to: LeaderboardID.bestScore)
    }

    func submitBiggestTile(_ value: Int) {
        submit(value, to: LeaderboardID.biggestTile)
    }

    private func submit(_ value: Int, to leaderboardID: String) {
        guard isAuthenticated else { return }
        Task {
            try? await GKLeaderboard.submitScore(
                value, context: 0, player: GKLocalPlayer.local,
                leaderboardIDs: [leaderboardID]
            )
        }
    }

    func showLeaderboard() {
        guard isAuthenticated else { return }
        let controller = GKGameCenterViewController(
            leaderboardID: LeaderboardID.bestScore, playerScope: .global, timeScope: .allTime
        )
        controller.gameCenterDelegate = LeaderboardDismisser.shared
        Self.rootViewController?.present(controller, animated: true)
    }

    private static var rootViewController: UIViewController? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .rootViewController
    }
}

private final class LeaderboardDismisser: NSObject, GKGameCenterControllerDelegate {
    static let shared = LeaderboardDismisser()

    func gameCenterViewControllerDidFinish(_ gameCenterViewController: GKGameCenterViewController) {
        gameCenterViewController.dismiss(animated: true)
    }
}
