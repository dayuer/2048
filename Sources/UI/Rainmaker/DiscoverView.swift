import SwiftUI

/// 发现：微信式功能入口页。【沙盘】挂顿悟掉落（Phase 3 已接线）；
/// 【闭门会】近场联机 Phase 4 才接入，先占位。
struct DiscoverView: View {
    @Bindable var store: RainmakerStore

    private var unlockedArchiveCount: Int { store.state.unlockedArchives?.count ?? 0 }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    NavigationLink {
                        DeepWorkScreen(store: store)
                    } label: {
                        row(
                            icon: "brain.head.profile",
                            tint: Color(red: 0.95, green: 0.60, blue: 0.28),
                            title: "财务数据重组沙盘",
                            subtitle: "逻辑推演训练 · 不耗尽调工时"
                        )
                    }
                } footer: {
                    Text("在数字重组中训练结构化思维。首次合成 128/256/512/1024/2048 触发「顿悟」：掉落谈判话术、解锁商业绝密档案、提升圈内声望。")
                }

                Section {
                    NavigationLink {
                        ArchivesView(store: store)
                    } label: {
                        row(
                            icon: "newspaper.fill",
                            tint: Color(red: 0.63, green: 0.51, blue: 0.36),
                            title: "商业绝密档案",
                            subtitle: "已解锁 \(unlockedArchiveCount)/\(ArchiveCatalog.all.count) · 真实商业史图鉴"
                        )
                    }
                    NavigationLink {
                        GlossaryView()
                    } label: {
                        row(
                            icon: "character.book.closed.fill",
                            tint: Color(red: 0.29, green: 0.46, blue: 0.90),
                            title: "创投百科词典",
                            subtitle: "估值方法 · Term Sheet 条款 · 谈判战术"
                        )
                    }
                } footer: {
                    Text("谈判里用到的每个专业概念都能在这里查——策略包卡面的 ⓘ 直达对应词条。")
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
                        .font(.title3)
                        .foregroundStyle(.white)
                )
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout)
                    .foregroundStyle(WA.textPrimary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(WA.textSecondary)
            }
        }
    }
}

/// 2048 沙盘的承载页：隐藏系统导航栏，退出只走 GameView 自绘的左上角返回按钮。
/// 顿悟里程碑在此转发进 Rainmaker，并弹 toast。
private struct DeepWorkScreen: View {
    @Bindable var store: RainmakerStore
    @Environment(\.dismiss) private var dismiss
    @State private var epiphany: EpiphanyReward?
    @State private var toastTask: Task<Void, Never>?

    var body: some View {
        GameView(
            onExit: { dismiss() },
            onMilestone: { value in
                guard let reward = store.recordMilestone(value) else { return }
                toastTask?.cancel()
                withAnimation(.spring(duration: 0.35)) { epiphany = reward }
                toastTask = Task {
                    try? await Task.sleep(for: .seconds(5))
                    if !Task.isCancelled {
                        withAnimation(.easeOut(duration: 0.3)) { epiphany = nil }
                    }
                }
            }
        )
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .overlay(alignment: .top) {
            if let epiphany {
                EpiphanyToast(reward: epiphany) {
                    toastTask?.cancel()
                    withAnimation(.easeOut(duration: 0.2)) { self.epiphany = nil }
                }
            }
        }
    }
}

/// 顿悟横幅：里程碑奖励摘要，点击关闭。
private struct EpiphanyToast: View {
    let reward: EpiphanyReward
    let onDismiss: () -> Void

    var body: some View {
        Button(action: onDismiss) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lightbulb.max.fill")
                    .font(.title2)
                    .foregroundStyle(.yellow)
                Text(reward.summary)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(WA.textPrimary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(WA.accent.opacity(0.4), lineWidth: 1)
            )
            .padding(.horizontal, 16)
        }
        .buttonStyle(.plain)
        .transition(.move(edge: .top).combined(with: .opacity))
    }
}

/// 商业绝密档案图鉴：解锁的展示泛黄档案卡，未解锁的留悬念。
private struct ArchivesView: View {
    @Bindable var store: RainmakerStore

    /// 泛黄纸张色（深浅色自适应交给透明度）。
    private let parchment = Color(red: 0.96, green: 0.92, blue: 0.82)

    var body: some View {
        List(ArchiveCatalog.all) { entry in
            if store.state.unlockedArchives?.contains(entry.id) == true {
                unlockedCard(entry)
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } else {
                lockedRow(entry)
                    .listRowSeparatorTint(WA.separator)
            }
        }
        .listStyle(.plain)
        .navigationTitle("商业绝密档案")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func unlockedCard(_ entry: ArchiveEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("绝密档案 · \(entry.year)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.red.opacity(0.75))
                Spacer()
                Image(systemName: "newspaper")
                    .foregroundStyle(.black.opacity(0.4))
            }
            Text(entry.title)
                .font(.system(.title3, design: .serif).weight(.bold))
                .foregroundStyle(.black.opacity(0.85))
            Text(entry.body)
                .font(.system(.subheadline, design: .serif))
                .foregroundStyle(.black.opacity(0.75))
                .lineSpacing(4)
            HStack {
                Text(entry.source)
                    .font(.system(.caption, design: .serif))
                    .foregroundStyle(.black.opacity(0.5))
                Spacer()
                if let cardID = entry.rewardCardID, let card = CardCatalog.card(id: cardID) {
                    Label("已获【\(card.name)】", systemImage: "rectangle.stack.fill")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WA.accent)
                }
            }
        }
        .padding(16)
        .background(parchment, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.black.opacity(0.15), lineWidth: 0.5)
        )
    }

    private func lockedRow(_ entry: ArchiveEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "lock.fill")
                .font(.title3)
                .foregroundStyle(WA.textSecondary)
                .frame(width: 36, height: 36)
                .background(WA.separator.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 2) {
                Text("？？？")
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WA.textPrimary)
                Text("在沙盘中合成 \(entry.milestone) 解锁")
                    .font(.caption)
                    .foregroundStyle(WA.textSecondary)
            }
        }
    }
}
