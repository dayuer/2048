import SwiftUI

/// App 根：微信式四 tab（消息 / 通讯录 / 发现 / 我的）。
/// RainmakerStore 在此持有，向下注入；破产时全屏覆盖结算页。
struct RainmakerRootView: View {
    @State private var store = RainmakerStore()
    @State private var gameCenter = GameCenterManager()

    var body: some View {
        TabView {
            MessagesView(store: store)
                .tabItem { Label("消息", systemImage: "message.fill") }

            ContactsView(store: store)
                .tabItem { Label("通讯录", systemImage: "person.2.fill") }

            DiscoverView(store: store)
                .tabItem { Label("发现", systemImage: "safari.fill") }

            ProfileView(store: store)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(WA.accent)
        .task { gameCenter.authenticate() }
        .task {
            // 生成式对话接入：Info.plist 配了才接（默认关闭 = 台词池）。
            if store.personaChat == nil {
                store.personaChat = PersonaChatConfig.fromInfoPlist().makeClient()
            }
        }
        .overlay {
            if store.state.isGameOver {
                GameOverView(store: store)
            }
        }
    }
}

/// 终局结算：浮生记四结局（上岸登榜 / 债未清被处理 / 街头倒下 / 破产），全屏覆盖。
struct GameOverView: View {
    let store: RainmakerStore

    private var outcome: RunOutcome { store.state.outcome ?? .bankrupt }
    private var isVictory: Bool { outcome == .victory }

    private var icon: String {
        switch outcome {
        case .victory: "trophy.fill"
        case .debtUnpaid: "person.2.slash.fill"
        case .beaten: "cross.case.fill"
        case .bankrupt: "chart.line.downtrend.xyaxis"
        }
    }

    private var title: String {
        switch outcome {
        case .victory: "上岸！荣登浮生排行榜"
        case .debtUnpaid: "债未还清，老乡们来了"
        case .beaten: "你倒在了北京街头"
        case .bankrupt: "职场信用破产"
        }
    }

    private var subtitle: String {
        switch outcome {
        case .victory: "四十天两清，净资产 \(store.state.netWorth) 万。北京，俺征服你了。"
        case .debtUnpaid: "还差 \(store.state.currentDebt) 万。村长说：别怪他心狠。"
        case .beaten: "健康归零。北京的日子，比想象中硬。"
        case .bankrupt: "现金流断裂，本期实战评估终止。复盘后再来。"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: icon)
                    .font(.system(size: 56))
                    .foregroundStyle(isVictory ? .yellow : .red)
                Text(title)
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                Text("浮生 \(store.state.day) 天 · 信誉 \(store.state.reputation) · 净资产 \(store.state.netWorth) 万")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
                Button(isVictory ? "再闯一次北京" : "重新开始实战") { store.restart() }
                    .buttonStyle(WAPrimaryButtonStyle())
                    .padding(.horizontal, 48)
                    .padding(.top, 12)
            }
            .padding()
        }
        .transition(.opacity)
    }
}
