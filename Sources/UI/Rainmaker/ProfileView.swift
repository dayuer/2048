import SwiftUI

/// 我的：掮客档案 + 本局数据 + 重开局。
struct ProfileView: View {
    @Bindable var store: RainmakerStore
    @State private var confirmRestart = false

    /// 职场进阶线：信誉决定职级（后续按职级解锁卡池与高阶对手）。
    private var rankTitle: String {
        switch store.state.reputation {
        case ..<60: "青铜 FA"
        case ..<90: "白银 FA"
        case ..<130: "黄金 FA"
        default: "王者 FA"
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        WAAvatar(systemImage: "briefcase.fill", background: .indigo, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rankTitle)
                                .font(.system(size: 19, weight: .semibold))
                                .foregroundStyle(WA.textPrimary)
                            Text("独立财务顾问 · 实战第 \(store.state.day) 天")
                                .font(.system(size: 13))
                                .foregroundStyle(WA.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                Section("本局") {
                    LabeledContent("资金", value: "\(store.state.cash) 万")
                    LabeledContent("信誉", value: "\(store.state.reputation)")
                    LabeledContent("已成交项目", value: "\(store.state.deals.filter { $0.status == .won }.count) 单")
                    LabeledContent("每日开销", value: "\(RainmakerBalance.burnRate) 万")
                }

                Section {
                    Button("重新开局", role: .destructive) { confirmRestart = true }
                } footer: {
                    Text("数据只存在本机，无账号、无云端。")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
        }
        .confirmationDialog(
            "确定重新开局？当前进度将清空。",
            isPresented: $confirmRestart,
            titleVisibility: .visible
        ) {
            Button("重新开局", role: .destructive) { store.restart() }
            Button("取消", role: .cancel) {}
        }
    }
}
