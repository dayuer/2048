import SwiftUI

/// 发现：微信式功能入口页。【深度工作】= 2048 复盘（Phase 3 挂顿悟掉落）；
/// 【闭门会】近场联机 Phase 4 才接入，先占位。
struct DiscoverView: View {
    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        GameView()
                            .navigationTitle("深度工作")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        row(
                            icon: "brain.head.profile",
                            tint: Color(red: 0.95, green: 0.60, blue: 0.28),
                            title: "深度工作",
                            subtitle: "2048 复盘 · 不耗精力"
                        )
                    }
                } footer: {
                    Text("在棋盘里深度思考。合成高级数字触发「顿悟」，掉落谈判话术——即将开放。")
                }

                Section {
                    row(
                        icon: "person.3.fill",
                        tint: .gray,
                        title: "闭门私董会",
                        subtitle: "检测附近同行 · 联机拼单（未开放）"
                    )
                    .opacity(0.45)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("发现")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(icon: String, tint: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 8)
                .fill(tint)
                .frame(width: 36, height: 36)
                .overlay(
                    Image(systemName: icon)
                        .font(.system(size: 18))
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 16))
                    .foregroundStyle(WA.textPrimary)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(WA.textSecondary)
            }
        }
    }
}
