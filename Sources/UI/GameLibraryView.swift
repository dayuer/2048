import SwiftUI

/// 游戏 tab：插件库，行样式对齐 WhatsApp 列表（圆角方图标 + 名称 + chevron）。
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
                                .font(.system(size: 22))
                                .foregroundStyle(.white)
                                .frame(width: 48, height: 48)
                                .background(WA.accent, in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 2) {
                                Text(plugin.name)
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(WA.textPrimary)
                                Text(plugin.supportsVersus ? "单人 · 对战" : "单人")
                                    .font(.system(size: 15))
                                    .foregroundStyle(WA.textSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(WA.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                    .listRowBackground(WA.listBg)
                    .listRowSeparatorTint(WA.separator)
                }
            }
            .listStyle(.plain)
            .background(WA.listBg)
            .scrollContentBackground(.hidden)
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
