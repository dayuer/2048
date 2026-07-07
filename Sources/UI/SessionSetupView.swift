import SwiftUI

/// setup 态：安静的「开始一个断网时段」入口（微信风）。
/// - 已解锁 Session 模式：可选时长后「开始断网时段」。
/// - 未解锁：仍可「直接玩 2048」（本体永久免费），并提供候机室购买入口。
struct SessionSetupView: View {
    let controller: SessionController
    let passStore: JourneyPassStore
    let gameCenter: GameCenterManager
    let offlineNudge: OfflineNudge

    @State private var showPass = false
    @State private var playFreely = false
    @State private var selected: TimeInterval? = nil

    private let durations: [(label: String, value: TimeInterval?)] = [
        ("不限", nil),
        ("30 分钟", 30 * 60),
        ("1 小时", 60 * 60),
        ("2 小时", 120 * 60)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text("离线时刻")
                .font(.system(size: 30, weight: .semibold))
                .foregroundStyle(Shell.textPrimary)
            Text("把这段没有信号的时间，好好地过完。")
                .font(.system(size: 15))
                .foregroundStyle(Shell.textSecondary)
                .padding(.top, 10)

            Spacer(minLength: 36)

            if offlineNudge.shouldPrompt {
                offlineCard.padding(.bottom, 16)
            }

            if passStore.isUnlocked {
                durationCard.padding(.bottom, 20)
                Button("开始断网时段") { controller.begin(duration: selected) }
                    .buttonStyle(WeChatPrimaryButtonStyle())
            } else {
                Button("解锁 Session 模式") { showPass = true }
                    .buttonStyle(WeChatPrimaryButtonStyle())
                Text("2048 本体始终免费")
                    .font(.system(size: 13))
                    .foregroundStyle(Shell.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 12)
            }

            Button("直接玩 2048") { playFreely = true }
                .buttonStyle(WeChatTextButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: 480)
        .sheet(isPresented: $showPass) {
            JourneyPassView(passStore: passStore)
        }
        .fullScreenCover(isPresented: $playFreely) {
            FreePlayContainer { playFreely = false }
        }
    }

    private var durationCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("计划时长")
                .font(.system(size: 13))
                .foregroundStyle(Shell.textSecondary)
            HStack(spacing: 10) {
                ForEach(durations.indices, id: \.self) { i in
                    let option = durations[i]
                    let isSelected = selected == option.value
                    Button {
                        selected = option.value
                    } label: {
                        Text(option.label)
                            .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(isSelected ? .white : Shell.textPrimary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 9)
                            .background(
                                isSelected ? Shell.accent : Shell.page,
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Shell.card, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
        .animation(.easeOut(duration: 0.15), value: selected)
    }

    private var offlineCard: some View {
        HStack(spacing: 12) {
            Text("检测到你已离线。要开始一个断网时段吗？")
                .font(.system(size: 14))
                .foregroundStyle(Shell.textPrimary)
            Spacer(minLength: 0)
            Button("不再提示") { offlineNudge.disableForever() }
                .buttonStyle(WeChatTextButtonStyle(color: Shell.textSecondary))
                .font(.system(size: 13))
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .background(Shell.card, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
    }
}

/// 免费直玩容器：把既有 GameView 包一层可返回的外壳。本体永久免费，不经过 Session。
private struct FreePlayContainer: View {
    let onExit: () -> Void

    var body: some View {
        ZStack(alignment: .topLeading) {
            GameView()
            Button(action: onExit) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.text)
                    .padding(14)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 6)
            .padding(.top, 4)
        }
    }
}
