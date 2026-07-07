import SwiftUI

/// 游戏 tab：插件库。每项进入「单人 / vs AI / vs 附近的人」；vs 人在 C 前置灰。
struct GameLibraryView: View {
    @State private var soloPlugin: GamePlugin?

    var body: some View {
        NavigationStack {
            List {
                ForEach(GameRegistry.all) { plugin in
                    Button {
                        soloPlugin = plugin
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: plugin.icon)
                                .foregroundStyle(.white)
                                .frame(width: 44, height: 44)
                                .background(Shell.accent, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
                            Text(plugin.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Shell.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Shell.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(Shell.card)
                }
            }
            .listStyle(.plain)
            .background(Shell.page)
            .navigationTitle("游戏")
            .fullScreenCover(item: $soloPlugin) { plugin in
                plugin.makeSoloView()
                    .background(Theme.background.ignoresSafeArea())
                    .overlay(alignment: .topLeading) {
                        Button { soloPlugin = nil } label: {
                            Image(systemName: "chevron.left")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(Theme.text)
                                .padding(16)
                        }
                    }
            }
        }
    }
}
