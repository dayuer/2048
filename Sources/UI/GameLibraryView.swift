import SwiftUI

/// 游戏 tab：小游戏中心（App Store 式双分区）。
/// 「游戏安利站」= 全部游戏大行列表（agent 拟人陈列：头像 + 安利语 + 标签）；
/// 「回合小游戏」= 支持对战的游戏横滑封面卡。点击一律直接进单人游戏。
struct GameLibraryView: View {
    @State private var soloPlugin: GamePlugin?

    private var versusPlugins: [GamePlugin] { GameRegistry.all.filter(\.supportsVersus) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    recommendSection
                    if !versusPlugins.isEmpty {
                        versusSection
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
            }
            .background(Color(.systemGroupedBackground))
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

    // MARK: - 分区一：游戏安利站（agent 大行列表）

    private var recommendSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("游戏安利站")
            VStack(spacing: 0) {
                ForEach(GameRegistry.all) { plugin in
                    Button {
                        soloPlugin = plugin
                    } label: {
                        agentRow(plugin)
                    }
                    if plugin.id != GameRegistry.all.last?.id {
                        Divider()
                            .overlay(WA.separator)
                            .padding(.leading, 88)
                    }
                }
            }
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
    }

    private func agentRow(_ plugin: GamePlugin) -> some View {
        HStack(spacing: 16) {
            WAAvatar(systemImage: plugin.icon, background: plugin.tint, size: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(plugin.name)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(WA.textPrimary)
                Text(plugin.tagline)
                    .font(.system(size: 15))
                    .foregroundStyle(WA.textSecondary)
                    .lineLimit(1)
                Text(plugin.tags.joined(separator: "   "))
                    .font(.system(size: 14))
                    .foregroundStyle(WA.textSecondary.opacity(0.8))
                    .padding(.top, 2)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .contentShape(Rectangle())
    }

    // MARK: - 分区二：回合小游戏（横滑封面卡）

    private var versusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("回合小游戏")
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(versusPlugins) { plugin in
                        Button {
                            soloPlugin = plugin
                        } label: {
                            versusCard(plugin)
                        }
                    }
                }
                .padding(16)
            }
            .background(
                Color(.secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 16)
            )
        }
    }

    private func versusCard(_ plugin: GamePlugin) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [plugin.tint.opacity(0.75), plugin.tint],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: 110, height: 150)
                .overlay(
                    Image(systemName: plugin.icon)
                        .font(.system(size: 44, weight: .medium))
                        .foregroundStyle(.white.opacity(0.9))
                )
                .overlay(alignment: .bottomLeading) {
                    WAAvatar(systemImage: plugin.icon, background: plugin.tint, size: 28)
                        .overlay(Circle().stroke(.white, lineWidth: 2))
                        .padding(8)
                }
            Text(plugin.name)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(WA.textPrimary)
            Text("单人 · 对战")
                .font(.system(size: 13))
                .foregroundStyle(WA.textSecondary)
        }
        .frame(width: 110, alignment: .leading)
    }

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 20, weight: .bold))
            .foregroundStyle(WA.textPrimary)
    }
}
