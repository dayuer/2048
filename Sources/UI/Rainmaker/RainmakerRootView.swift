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

            DiscoverView()
                .tabItem { Label("发现", systemImage: "safari.fill") }

            ProfileView(store: store)
                .tabItem { Label("我的", systemImage: "person.crop.circle") }
        }
        .tint(WA.accent)
        .task { gameCenter.authenticate() }
        .overlay {
            if store.state.isGameOver {
                GameOverView(store: store)
            }
        }
    }
}

/// 破产结算：全屏覆盖，只留【重新开局】一条出路。
struct GameOverView: View {
    let store: RainmakerStore

    var body: some View {
        ZStack {
            Color.black.opacity(0.92).ignoresSafeArea()
            VStack(spacing: 20) {
                Image(systemName: "chart.line.downtrend.xyaxis")
                    .font(.system(size: 56))
                    .foregroundStyle(.red)
                Text("破产出局")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)
                Text("撑到第 \(store.state.day) 天 · 信誉 \(store.state.reputation)")
                    .font(.headline)
                    .foregroundStyle(.white.opacity(0.7))
                Text("现金流断了，这个圈子不再有你的位置。")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.5))
                Button("重新开局") { store.restart() }
                    .buttonStyle(WAPrimaryButtonStyle())
                    .padding(.horizontal, 48)
                    .padding(.top, 12)
            }
            .padding()
        }
        .transition(.opacity)
    }
}
