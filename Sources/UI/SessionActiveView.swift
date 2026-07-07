import SwiftUI

/// active 态：安静环境。2048 作为 Hero 活动承载其中，Session 外壳退到背景。
/// 唯一的会话操作是一个克制的「落地」——样式与暖色棋盘世界和谐，不喧宾夺主。
/// 切后台 / 来电由系统触发 scenePhase：暂停并存档（进度绝不丢）。
struct SessionActiveView: View {
    let controller: SessionController

    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        ZStack(alignment: .bottom) {
            GameView()

            Button {
                controller.land()
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: "airplane.arrival")
                    Text("落地")
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Shell.accent, in: Capsule())
                .shadow(color: .black.opacity(0.12), radius: 6, y: 2)
            }
            .buttonStyle(.plain)
            .padding(.bottom, 18)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active: controller.resume()
            case .inactive, .background: controller.pause()
            @unknown default: break
            }
        }
    }
}
