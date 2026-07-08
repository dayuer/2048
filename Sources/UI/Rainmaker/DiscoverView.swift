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
                            .navigationTitle("财务数据重组沙盘")
                            .navigationBarTitleDisplayMode(.inline)
                    } label: {
                        row(
                            icon: "brain.head.profile",
                            tint: Color(red: 0.95, green: 0.60, blue: 0.28),
                            title: "财务数据重组沙盘",
                            subtitle: "逻辑推演训练 · 不耗尽调工时"
                        )
                    }
                } footer: {
                    Text("在数字重组中训练结构化思维。达成高阶重组解锁「商业绝密档案」与谈判策略——即将开放。")
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
