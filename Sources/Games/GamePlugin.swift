import SwiftUI

/// 对手类型。peer 在 C 落地后携带连接。
enum OpponentKind: Equatable {
    case ai
    case peer
}

/// 一个可插拔游戏的 app 层描述符（引擎侧已由 GridGame 基本法 GridGameEngine 约束）。
/// 只补齐「库里怎么陈列、怎么开局」。
struct GamePlugin: Identifiable {
    let id: String              // "game2048"
    let name: String            // "2048"
    let icon: String            // SF Symbol
    let tagline: String         // agent 拟人安利语（单行）
    let tags: [String]          // 分类标签，如 ["休闲", "益智"]
    let tint: Color             // 头像/封面底色
    let supportsVersus: Bool
    let makeSoloView: () -> AnyView
    let makeVersusView: (_ seed: UInt64, _ opponent: OpponentKind) -> AnyView
}

/// 编译期静态注册表。V2 起步只有 2048。
enum GameRegistry {
    static let all: [GamePlugin] = [
        GamePlugin(
            id: "game2048",
            name: "2048",
            icon: "square.grid.2x2.fill",
            tagline: "滑到 2048 算你赢，我在棋盘里等你",
            tags: ["休闲", "益智"],
            tint: Color(red: 0.95, green: 0.60, blue: 0.28),   // 呼应 2048 棋盘橙
            supportsVersus: true,
            makeSoloView: { AnyView(GameView()) },
            // 1a：versus 暂用同一单人棋盘占位；真 AI 对手/对战屏在 Phase 1b 替换。
            makeVersusView: { _, _ in AnyView(GameView()) }
        ),
    ]

    static func plugin(id: String) -> GamePlugin? { all.first { $0.id == id } }
}
