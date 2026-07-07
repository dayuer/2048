import SwiftUI

/// landed 态：克制的「你已落地」（微信风）。展示本次 Session 做了什么（本地），
/// 并提供**自愿**同步 Game Center（永不强制、不弹窗骚扰）。
struct SessionLandedView: View {
    let controller: SessionController
    let gameCenter: GameCenterManager

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text("你已落地")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Shell.textPrimary)
            Text("这段断网时间，已经好好地过完了。")
                .font(.system(size: 15))
                .foregroundStyle(Shell.textSecondary)
                .padding(.top, 10)

            // 本次时间统计——白卡片。
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("\(minutes)")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Shell.accent)
                Text("分钟离线")
                    .font(.system(size: 16))
                    .foregroundStyle(Shell.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(20)
            .background(Shell.card, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
            .padding(.top, 28)

            Spacer(minLength: 40)

            Button("完成") { controller.close() }
                .buttonStyle(WeChatPrimaryButtonStyle())

            Button("同步这次成绩") { gameCenter.showLeaderboard() }
                .buttonStyle(WeChatTextButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, 16)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 480)
    }

    private var minutes: Int {
        Int(controller.elapsedWallTime()) / 60
    }
}
