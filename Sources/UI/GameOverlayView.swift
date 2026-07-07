import SwiftUI

struct GameOverlayView: View {
    let state: GameViewModel.Overlay
    let onKeepGoing: () -> Void
    let onNewGame: () -> Void

    var body: some View {
        if state != .none {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(state == .won ? Theme.winOverlay : Theme.loseOverlay)
                VStack(spacing: 20) {
                    Text(state == .won ? "You win!" : "Game over!")
                        .font(.system(size: 44, weight: .bold))
                        .foregroundStyle(state == .won ? Theme.lightText : Theme.text)
                    HStack(spacing: 12) {
                        if state == .won {
                            OverlayButton(title: "Keep going", action: onKeepGoing)
                        }
                        OverlayButton(title: "Try again", action: onNewGame)
                    }
                }
            }
            .transition(.opacity)
        }
    }
}

private struct OverlayButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.lightText)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Theme.button, in: RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
