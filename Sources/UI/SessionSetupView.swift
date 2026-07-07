import SwiftUI

/// setup 态：安静的「开始一个断网时段」入口。
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
        ("不设时长", nil),
        ("30 分", 30 * 60),
        ("1 时", 60 * 60),
        ("2 时", 120 * 60)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer(minLength: 0)

            Text("OFFLINE SESSION")
                .shellMonoLabel()

            Text("离线时刻")
                .font(.shellDisplay(52))
                .foregroundStyle(Shell.ink)
                .padding(.top, 10)

            // 单一黄铜点缀：一条测量时间的极短 hairline。
            Rectangle()
                .fill(Shell.accent)
                .frame(width: 40, height: 2)
                .padding(.top, 22)

            Text("把这段没有信号的时间，好好地过完。")
                .font(.system(size: 15))
                .foregroundStyle(Shell.mutedInk)
                .padding(.top, 22)

            Spacer(minLength: 40)

            if offlineNudge.shouldPrompt {
                offlineHint
                    .padding(.bottom, 20)
            }

            if passStore.isUnlocked {
                durationPicker
                    .padding(.bottom, 18)
                Button("开始断网时段") { controller.begin(duration: selected) }
                    .buttonStyle(ShellPrimaryButtonStyle())
            } else {
                Button("解锁 Session 模式") { showPass = true }
                    .buttonStyle(ShellPrimaryButtonStyle())
            }

            Button("直接玩 2048") { playFreely = true }
                .buttonStyle(ShellGhostButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(.top, 18)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 32)
        .frame(maxWidth: 480)
        .sheet(isPresented: $showPass) {
            JourneyPassView(passStore: passStore)
        }
        .fullScreenCover(isPresented: $playFreely) {
            FreePlayContainer { playFreely = false }
        }
    }

    private var offlineHint: some View {
        HStack(spacing: 12) {
            Text("检测到你已离线。要开始一个断网时段吗？")
                .font(.system(size: 13))
                .foregroundStyle(Shell.mutedInk)
            Spacer(minLength: 0)
            Button("不再提示") { offlineNudge.disableForever() }
                .buttonStyle(ShellGhostButtonStyle())
                .font(.system(size: 12))
        }
        .padding(14)
        .background(Shell.surface, in: RoundedRectangle(cornerRadius: Shell.radius))
    }

    private var durationPicker: some View {
        HStack(spacing: 0) {
            ForEach(durations.indices, id: \.self) { i in
                let option = durations[i]
                let isSelected = selected == option.value
                Button {
                    selected = option.value
                } label: {
                    VStack(spacing: 8) {
                        Text(option.label)
                            .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                            .foregroundStyle(isSelected ? Shell.ink : Shell.mutedInk)
                        Rectangle()
                            .fill(isSelected ? Shell.accent : .clear)
                            .frame(height: 1.5)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeOut(duration: 0.2), value: selected)
    }
}

/// 免费直玩容器：把既有 GameView 包一层可返回的深墨外壳。本体永久免费，不经过 Session。
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
