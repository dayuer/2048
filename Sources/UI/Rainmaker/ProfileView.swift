import SwiftUI

/// 我的：掮客档案 + 本局数据 + 重开局。
struct ProfileView: View {
    @Bindable var store: RainmakerStore
    @State private var confirmRestart = false
    @State private var confirmEndDay = false

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
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(WA.textPrimary)
                            Text("独立财务顾问 · 实战第 \(store.state.day) 天")
                                .font(.footnote)
                                .foregroundStyle(WA.textSecondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // 经营面板：核心资源全在这里（消息页保持纯聊天）
                Section("经营面板") {
                    ResourceBar(state: store.state)
                        .listRowInsets(EdgeInsets())

                    Button {
                        confirmEndDay = true
                    } label: {
                        HStack {
                            Image(systemName: "moon.zzz.fill")
                            Text(store.state.ap == 0 ? "工时用尽 · 结束今日" : "结束今日（剩 \(store.state.ap) 工时）")
                        }
                    }
                    .buttonStyle(WAPrimaryButtonStyle())
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
                }

                // 浮生面板：债务/健康/仓位/银行/医院——浮生记生存系统
                Section("北京浮生") {
                    LabeledContent("欠村长") {
                        Text("\(store.state.currentDebt) 万 · 日息一成")
                            .foregroundStyle(store.state.currentDebt > 0 ? .red : WA.textSecondary)
                            .monospacedDigit()
                    }
                    LabeledContent("大限", value: "第 \(store.state.day)/\(RainmakerBalance.deadlineDay) 天")
                    LabeledContent("健康") {
                        Text("\(store.state.currentHealth)/\(RainmakerBalance.startHealth)")
                            .foregroundStyle(store.state.currentHealth < 40 ? .red : WA.textPrimary)
                            .monospacedDigit()
                    }
                    LabeledContent("托管仓位", value: "\(store.state.usedCapacity)/\(store.state.currentCapacity) 手")
                    LabeledContent("银行存款", value: "\(store.state.currentBankDeposit) 万 · 日息 1%")
                    LabeledContent("净资产") {
                        Text("\(store.state.netWorth) 万")
                            .foregroundStyle(store.state.netWorth >= 0 ? WA.accent : .red)
                            .monospacedDigit()
                    }

                    if store.state.currentHealth < RainmakerBalance.startHealth {
                        Button("去私立医院（\(RainmakerBalance.healCostPerPoint) 万/点，尽力治）") {
                            store.heal()
                        }
                        .disabled(store.state.cash < RainmakerBalance.healCostPerPoint)
                    }
                    HStack {
                        Button("现金全存银行") { store.deposit(amount: store.state.cash) }
                            .disabled(store.state.cash <= 0)
                        Spacer()
                        Button("存款全取") { store.withdraw(amount: store.state.currentBankDeposit) }
                            .disabled(store.state.currentBankDeposit <= 0)
                    }
                    .buttonStyle(.borderless)
                    Button("托管扩容 +\(RainmakerBalance.capacityUpgradeGain) 手（\(RainmakerBalance.capacityUpgradeCost) 万）") {
                        store.upgradeCapacity()
                    }
                    .disabled(store.state.cash < RainmakerBalance.capacityUpgradeCost)
                }

                Section("本局") {
                    LabeledContent("已成交项目", value: "\(store.state.deals.filter { $0.status == .won }.count) 单")
                    LabeledContent("话术卡库", value: "\(store.state.cardInventory?.count ?? 0)/\(RainmakerBalance.cardInventoryCap)")
                    LabeledContent("绝密档案", value: "\(store.state.unlockedArchives?.count ?? 0)/\(ArchiveCatalog.all.count)")
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
        .confirmationDialog(
            "结束第 \(store.state.day) 天？未接的项目会作废，固定开销 \(RainmakerBalance.burnRate) 万照扣。",
            isPresented: $confirmEndDay,
            titleVisibility: .visible
        ) {
            Button("结束今日并结算", role: .destructive) { store.endDay() }
            Button("再想想", role: .cancel) {}
        }
    }
}
