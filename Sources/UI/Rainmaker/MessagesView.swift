import SwiftUI

/// 主视图：顶部资源条 + NPC 消息列表 + 底部【结束今日】。
struct MessagesView: View {
    @Bindable var store: RainmakerStore
    @State private var confirmEndDay = false

    private var sortedThreads: [NPCThread] {
        store.state.threads.sorted { $0.lastEventAt > $1.lastEventAt }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ResourceBar(state: store.state)
                List(sortedThreads) { thread in
                    NavigationLink {
                        RainmakerThreadView(store: store, npcID: thread.id)
                    } label: {
                        ThreadRow(store: store, npcID: thread.id)
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .listRowSeparatorTint(WA.separator)
                }
                .listStyle(.plain)
                .background(WA.listBg)

                endDayBar
            }
            .background(WA.listBg)
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.inline)
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

    /// 结束今日：AP 用尽时高亮催促（PRD：AP 耗尽必须结束今日）。
    private var endDayBar: some View {
        Button {
            confirmEndDay = true
        } label: {
            HStack {
                Image(systemName: "moon.zzz.fill")
                Text(store.state.ap == 0 ? "工时用尽 · 结束今日" : "结束今日（剩 \(store.state.ap) 工时）")
            }
        }
        .buttonStyle(WAPrimaryButtonStyle())
        .opacity(store.state.ap == 0 ? 1 : 0.85)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(WA.listBg)
        .overlay(alignment: .top) { WA.separator.frame(height: 0.5) }
    }
}

/// WhatsApp 式线程行：头像 + 名字 + 最后一条预览 + 时间 + 未读角标。
/// 预览/角标只看「已送达」的消息——投递中的不剧透。
private struct ThreadRow: View {
    @Bindable var store: RainmakerStore
    let npcID: String

    private var profile: NPCProfile? { NPCCatalog.profile(id: npcID) }
    private var lastVisible: RainmakerEvent? { store.visibleEvents(npcID: npcID).last }
    private var unread: Int { store.unreadCount(npcID: npcID) }
    private var isTyping: Bool { store.typingNPCIDs.contains(npcID) }

    var body: some View {
        HStack(spacing: 12) {
            WAAvatar(
                systemImage: profile?.icon ?? "person.fill",
                background: RainmakerUI.tint(for: npcID)
            )
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(profile?.name ?? npcID)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(WA.textPrimary)
                    Spacer()
                    if let last = lastVisible {
                        Text(RainmakerUI.timeLabel(last.at))
                            .font(.system(size: 13))
                            .foregroundStyle(unread > 0 ? WA.accent : WA.textSecondary)
                    }
                }
                HStack {
                    if isTyping {
                        Text("正在输入…")
                            .font(.system(size: 15))
                            .foregroundStyle(WA.accent)
                            .lineLimit(1)
                    } else if let last = lastVisible {
                        Text(RainmakerUI.preview(for: last, in: store.state))
                            .font(.system(size: 15))
                            .foregroundStyle(WA.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer()
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(WA.accent, in: Capsule())
                    }
                }
            }
        }
    }
}
