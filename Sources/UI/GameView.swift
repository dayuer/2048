import SwiftUI

struct GameView: View {
    @State private var gameCenter: GameCenterManager
    @State private var viewModel: GameViewModel
    private let onExit: (() -> Void)?

    init(onExit: (() -> Void)? = nil) {
        let gameCenter = GameCenterManager()
        _gameCenter = State(initialValue: gameCenter)
        _viewModel = State(initialValue: GameViewModel(gameCenter: gameCenter))
        self.onExit = onExit
    }

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 14) {
                header
                toolbar
                ZStack {
                    BoardView(tiles: viewModel.displayTiles)
                    GameOverlayView(
                        state: viewModel.overlay,
                        onKeepGoing: { viewModel.keepGoing() },
                        onNewGame: { viewModel.newGame() }
                    )
                    .animation(.easeIn(duration: 0.2), value: viewModel.overlay)
                }
                .aspectRatio(1, contentMode: .fit)
                Text("Join the numbers and get to the **2048** tile!")
                    .font(.footnote)
                    .foregroundStyle(Theme.text.opacity(0.8))
                Spacer(minLength: 0)
            }
            .padding(20)
            .frame(maxWidth: 480)
        }
        .contentShape(Rectangle())
        .gesture(swipeGesture)
        .focusable()
        .focusEffectDisabled()
        .onKeyPress(phases: .down) { press in
            switch press.key {
            case .upArrow: viewModel.move(.up)
            case .downArrow: viewModel.move(.down)
            case .leftArrow: viewModel.move(.left)
            case .rightArrow: viewModel.move(.right)
            default: return .ignored
            }
            return .handled
        }
        .task { gameCenter.authenticate() }
    }

    private var header: some View {
        HStack(alignment: .top) {
            Text(verbatim: "2048")
                .font(.system(size: 52, weight: .heavy))
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .layoutPriority(-1)
            Spacer()
            HStack(spacing: 8) {
                ScoreBoxView(
                    label: "SCORE", value: viewModel.score,
                    delta: viewModel.scoreDelta, deltaID: viewModel.scoreDeltaID
                )
                ScoreBoxView(label: "BEST", value: viewModel.bestScore)
            }
        }
    }

    private var toolbar: some View {
        HStack {
            if let onExit {
                Button(action: onExit) {
                    Image(systemName: "chevron.left")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Theme.lightText)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Theme.button, in: RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }
            Spacer()
            Button {
                viewModel.showLeaderboard()
            } label: {
                Image(systemName: "trophy.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.lightText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.button, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            Button {
                viewModel.newGame()
            } label: {
                Text("New Game")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(Theme.lightText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Theme.button, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
        }
    }

    private var swipeGesture: some Gesture {
        DragGesture(minimumDistance: 24)
            .onEnded { value in
                let dx = value.translation.width
                let dy = value.translation.height
                let direction: Direction =
                    abs(dx) > abs(dy) ? (dx > 0 ? .right : .left) : (dy > 0 ? .down : .up)
                viewModel.move(direction)
            }
    }
}
