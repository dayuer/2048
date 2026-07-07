import SwiftUI

/// 应用根视图：按 SessionController 的状态在三态间路由。
/// 无 Session → setup；active → 安静环境（GameView）；landed → 收尾。
/// 状态切换用缓慢的交叉淡入 + 向上微移，无弹跳（沿用本仓库既定的沉稳动效语言）。
struct SessionShellView: View {
    @State private var gameCenter: GameCenterManager
    @State private var sessionController: SessionController
    @State private var passStore: JourneyPassStore
    @State private var offlineNudge: OfflineNudge
    private let storage: GameStorage

    init() {
        let storage = GameStorage()
        self.storage = storage
        _gameCenter = State(initialValue: GameCenterManager())
        _sessionController = State(initialValue: SessionController(storage: storage))
        _passStore = State(initialValue: JourneyPassStore(storage: storage))
        _offlineNudge = State(initialValue: OfflineNudge(storage: storage))
    }

    private var state: SessionState? { sessionController.session?.state }

    var body: some View {
        ZStack {
            Shell.ground.ignoresSafeArea()

            Group {
                switch state {
                case .active:
                    SessionActiveView(controller: sessionController)
                        .transition(shellTransition)
                case .landed:
                    SessionLandedView(controller: sessionController, gameCenter: gameCenter)
                        .transition(shellTransition)
                case .setup, .closed, nil:
                    SessionSetupView(
                        controller: sessionController,
                        passStore: passStore,
                        gameCenter: gameCenter,
                        offlineNudge: offlineNudge
                    )
                    .transition(shellTransition)
                }
            }
        }
        .animation(.easeInOut(duration: 0.5), value: state)
        .task {
            gameCenter.authenticate()
            await passStore.refreshEntitlements()
        }
    }

    /// 交叉淡入 + 向上 12pt 微移。
    private var shellTransition: AnyTransition {
        .opacity.combined(with: .offset(y: 12))
    }
}
