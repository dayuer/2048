import SwiftUI

/// landed 态：克制的「你已落地」。回到深墨外壳，展示本次 Session 做了什么（本地），
/// 并提供**自愿**同步 Game Center（永不强制、不弹窗骚扰）。
struct SessionLandedView: View {
    let controller: SessionController
    let gameCenter: GameCenterManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text("SESSION · LANDED")
                .shellMonoLabel()

            Text("你已落地")
                .font(.shellDisplay(48))
                .foregroundStyle(Shell.ink)
                .padding(.top, 12)

            Rectangle()
                .fill(Shell.accent)
                .frame(width: 40, height: 2)
                .padding(.top, 22)

            // 本次时间统计——用签名的「大衬线数字 + 等宽微标签」呈现。
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("\(minutes)")
                    .font(.shellDisplay(64, weight: .medium))
                    .foregroundStyle(Shell.ink)
                Text("分钟离线")
                    .font(.system(size: 16))
                    .foregroundStyle(Shell.mutedInk)
            }
            .padding(.top, 36)

            Text("MINUTES OFFLINE")
                .shellMonoLabel()
                .padding(.top, 6)

            Spacer(minLength: 40)

            Button("同步这次成绩") { gameCenter.showLeaderboard() }
                .buttonStyle(ShellGhostButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.bottom, 18)

            Button("结束") { controller.close() }
                .buttonStyle(ShellPrimaryButtonStyle())

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 480)
    }

    private var minutes: Int {
        Int(controller.elapsedWallTime()) / 60
    }
}
