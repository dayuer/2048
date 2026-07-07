import SwiftUI

struct ScoreBoxView: View {
    let label: LocalizedStringKey
    let value: Int
    var delta: Int = 0
    var deltaID: Int = 0

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.scoreLabel)
                .lineLimit(1)
            // verbatim：不走本地化/千分位格式，单行 + 缩字防溢出
            Text(verbatim: String(value))
                .font(.title3.weight(.bold))
                .monospacedDigit()
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
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
        Text(verbatim: "+\(value)")
            .font(.headline.bold())
            .foregroundStyle(Theme.text.opacity(0.7))
            .lineLimit(1)
            .offset(y: animate ? -26 : 0)
            .opacity(animate ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.9)) { animate = true }
            }
            .allowsHitTesting(false)
    }
}
