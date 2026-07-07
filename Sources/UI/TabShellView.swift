import SwiftUI

/// App 根：四 tab 外壳（对话 / 附近 / 游戏 / 我）。取代 SessionShellView。
/// ChatStore / EphemeralIdentity 在此持有，向下注入。
struct TabShellView: View {
    @State private var chat = ChatStore()
    @State private var identity = EphemeralIdentity()
    @State private var gameCenter = GameCenterManager()

    var body: some View {
        TabView {
            ChatListView(chat: chat)
                .tabItem { Label("对话", systemImage: "bubble.left.and.bubble.right.fill") }

            NearbyView()
                .tabItem { Label("附近", systemImage: "dot.radiowaves.left.and.right") }

            GameLibraryView()
                .tabItem { Label("游戏", systemImage: "gamecontroller.fill") }

            MeView(identity: identity, chat: chat)
                .tabItem { Label("我", systemImage: "person.crop.circle") }
        }
        .tint(Shell.accent)
        .task { gameCenter.authenticate() }
    }
}
