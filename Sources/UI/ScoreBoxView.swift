import SwiftUI

struct ScoreBoxView: View {
    let label: String
    let value: Int
    var delta: Int = 0
    var deltaID: Int = 0

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.scoreLabel)
            Text("\(value)")
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
                .contentTransition(.numericText(value: Double(value)))
        }
        .frame(minWidth: 72)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Theme.scoreBox, in: RoundedRectangle(cornerRadius: 6))
        .overlay(alignment: .top) {
            if delta > 0 {
                FloatingScoreView(value: delta)
                    .id(deltaID)
            }
        }
    }
}

/// 合并得分时向上飘出的 "+N"。
private struct FloatingScoreView: View {
    let value: Int
    @State private var animate = false

    var body: some View {
        Text("+\(value)")
            .font(.headline.bold())
            .foregroundStyle(Theme.text.opacity(0.9))
            .offset(y: animate ? -38 : 0)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.6)) { animate = true }
            }
            .allowsHitTesting(false)
    }
}
