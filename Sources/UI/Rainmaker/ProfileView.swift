import SwiftUI

/// 「我」= 掮客操作台：本人档案 + 今日战况仪表 + 经营操作。
/// 简洁专业、无游戏味标签；设置类（对话引擎/重开局）收进下一级「设置」页。
struct ProfileView: View {
    @Bindable var store: RainmakerStore
    @Bindable var llmSettings: LLMSettingsStore
    @State private var confirmEndDay = false
    @State private var showBank = false

    /// 职级：信誉决定（后续按职级解锁卡池与高阶对手）。
    private var rankTitle: String {
        switch store.state.reputation {
        case ..<60: "青铜 FA"
        case ..<90: "白银 FA"
        case ..<130: "黄金 FA"
        default: "王者 FA"
        }
    }

    private var debtColor: Color { store.state.currentDebt > 0 ? .red : WA.textSecondary }
    private var healthColor: Color { store.state.currentHealth < 40 ? .red : WA.textPrimary }

    var body: some View {
        NavigationStack {
            List {
                // 档案卡：身份 + 净资产（操作台的抬头）
                Section {
                    HStack(spacing: 14) {
                        WAAvatar(systemImage: "briefcase.fill", background: WA.accent, size: 56)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(rankTitle)
                                .font(.title3.weight(.semibold))
                                .foregroundStyle(WA.textPrimary)
                            Text("独立财务顾问 · 第 \(store.state.day)/\(RainmakerBalance.deadlineDay) 天")
                                .font(.footnote)
                                .foregroundStyle(WA.textSecondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("净资产")
                                .font(.caption2)
                                .foregroundStyle(WA.textSecondary)
                            Text("\(store.state.netWorth) 万")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(store.state.netWorth >= 0 ? WA.accent : .red)
                                .monospacedDigit()
                        }
                    }
                    .padding(.vertical, 6)
                }

                // 今日战况：核心数值仪表（无游戏味分区名）
                Section("今日战况") {
                    metric("现金", "\(store.state.cash) 万")
                    metric("信誉", "\(store.state.reputation)")
                    metric("尽调工时", "\(store.state.ap)/\(RainmakerBalance.apPerDay)")
                    metric("待偿", "\(store.state.currentDebt) 万 · 日息一成", tint: debtColor)
                    metric("健康", "\(store.state.currentHealth)/\(RainmakerBalance.startHealth)", tint: healthColor)
                    metric("托管仓位", "\(store.state.usedCapacity)/\(store.state.currentCapacity) 手")
                    metric("银行存款", "\(store.state.currentBankDeposit) 万 · 日息 1%")
                    metric("每日固定开销", "\(RainmakerBalance.burnRate) 万")
                }

                // 经营操作：操作台的动作区
                Section("经营") {
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

                    Button("银行存取") { showBank = true }
                        .disabled(store.state.cash <= 0 && store.state.currentBankDeposit <= 0)
                    if store.state.currentHealth < RainmakerBalance.startHealth {
                        Button("私立医院回血（\(RainmakerBalance.healCostPerPoint) 万/点）") {
                            store.heal()
                        }
                        .disabled(store.state.cash < RainmakerBalance.healCostPerPoint)
                    }
                    Button("托管扩容 +\(RainmakerBalance.capacityUpgradeGain) 手（\(RainmakerBalance.capacityUpgradeCost) 万）") {
                        store.upgradeCapacity()
                    }
                    .disabled(store.state.cash < RainmakerBalance.capacityUpgradeCost)
                }

                // 战绩
                Section("战绩") {
                    metric("已成交项目", "\(store.state.deals.filter { $0.status == .won }.count) 单")
                    metric("话术卡库", "\(store.state.cardInventory?.count ?? 0)/\(RainmakerBalance.cardInventoryCap)")
                    metric("绝密档案", "\(store.state.unlockedArchives?.count ?? 0)/\(ArchiveCatalog.all.count)")
                }

                // 设置收进下一级
                Section {
                    NavigationLink {
                        SettingsView(store: store, llm: llmSettings)
                    } label: {
                        Label("设置", systemImage: "gearshape")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我")
            .navigationBarTitleDisplayMode(.inline)
        }
        .sheet(isPresented: $showBank) {
            BankSheet(store: store)
                .presentationDetents([.medium])
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

    /// 仪表行：标签左、值右，值可染色。
    private func metric(_ label: String, _ value: String, tint: Color = WA.textPrimary) -> some View {
        LabeledContent(label) {
            Text(value)
                .foregroundStyle(tint)
                .monospacedDigit()
        }
    }
}

/// 设置（下一级）：对话引擎 + 重新开局 + 数据说明。集中收纳，操作台保持干净。
struct SettingsView: View {
    @Bindable var store: RainmakerStore
    @Bindable var llm: LLMSettingsStore
    @State private var confirmRestart = false

    var body: some View {
        List {
            Section {
                NavigationLink {
                    LLMSettingsView(llm: llm)
                } label: {
                    LabeledContent("对话引擎") {
                        Text(llm.activeConfig?.name ?? "内置台词池")
                    }
                }
            } header: {
                Text("AI 引擎")
            } footer: {
                Text("接入大模型后，联系人聊天与谈判桌台词按人设实时生成；未接入走内置台词池。")
            }

            Section {
                Button("重新开局", role: .destructive) { confirmRestart = true }
            } footer: {
                Text("数据只存在本机，无账号、无云端。")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("设置")
        .navigationBarTitleDisplayMode(.inline)
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
