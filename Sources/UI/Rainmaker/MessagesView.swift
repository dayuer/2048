import SwiftUI

/// 主视图：WhatsApp 式列表页——大标题 + 搜索 + 筛选 chips + 无箭头行，
/// 叠加经营 chrome（顶部资源条 + 底部结束今日）。
struct MessagesView: View {
    @Bindable var store: RainmakerStore
    @State private var confirmEndDay = false
    @State private var confirmRestart = false
    @State private var query = ""
    @State private var filter: RainmakerStore.ThreadFilter = .all
    @State private var showNewChat = false
    @State private var path = NavigationPath()

    private var threads: [NPCThread] {
        store.filteredThreads(query: query, filter: filter)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                ResourceBar(state: store.state)

                List {
                    filterChips
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)

                    ForEach(threads) { thread in
                        ZStack {
                            // 隐形跳转层：去掉系统 chevron（WhatsApp 行没有箭头）
                            NavigationLink(value: thread.id) { EmptyView() }.opacity(0)
                            ThreadRow(store: store, npcID: thread.id)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparatorTint(WA.separator)
                    }
                }
                .listStyle(.plain)
                .background(WA.listBg)
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: "搜索"
                )

                endDayBar
            }
            .background(WA.listBg)
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { npcID in
                RainmakerThreadView(store: store, npcID: npcID)
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button("结束今日", systemImage: "moon.zzz") { confirmEndDay = true }
                        Button("重新开局", systemImage: "arrow.counterclockwise", role: .destructive) {
                            confirmRestart = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(WA.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(WA.separator.opacity(0.6), in: Circle())
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(WA.accent, in: Circle())
                    }
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatSheet { npcID in
                    showNewChat = false
                    path.append(npcID)
                }
            }
        }
        .confirmationDialog(
            "结束第 \(store.state.day) 天？未接的项目会作废，固定开销 \(RainmakerBalance.burnRate) 万照扣。",
            isPresented: $confirmEndDay,
            titleVisibility: .visible
        ) {
            Button("结束今日并结算", role: .destructive) { store.endDay() }
            Button("再想想", role: .cancel) {}
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

    /// WhatsApp 式筛选 chips：全部 / 未读 / 项目。
    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(RainmakerStore.ThreadFilter.allCases, id: \.self) { item in
                    Button {
                        filter = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(filter == item ? WA.accent : WA.textSecondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                filter == item ? WA.accent.opacity(0.15) : WA.separator.opacity(0.5),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    /// 结束今日：工时用尽时高亮催促（PRD：工时耗尽必须结束今日）。
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

/// WhatsApp 式线程行：头像 + 名字 + 最后一条预览（我方带 ✓✓）+ 时间 + 未读角标。
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
                        Text(RainmakerUI.listTimeLabel(last.at))
                            .font(.system(size: 13))
                            .foregroundStyle(unread > 0 ? WA.accent : WA.textSecondary)
                    }
                }
                HStack(spacing: 4) {
                    if isTyping {
                        Text("正在输入…")
                            .font(.system(size: 15))
                            .foregroundStyle(WA.accent)
                            .lineLimit(1)
                    } else if let last = lastVisible {
                        if last.isMine {
                            WADoubleTick()
                        }
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

/// 「+」新对话：选联系人直接进线程（WhatsApp 的 New Chat 形态）。
private struct NewChatSheet: View {
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var allProfiles: [NPCProfile] {
        [NPCCatalog.assistant] + NPCCatalog.contacts
    }

    var body: some View {
        NavigationStack {
            List(allProfiles) { profile in
                Button {
                    onSelect(profile.id)
                } label: {
                    HStack(spacing: 12) {
                        WAAvatar(
                            systemImage: profile.icon,
                            background: RainmakerUI.tint(for: profile.id),
                            size: 44
                        )
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.system(size: 17))
                                .foregroundStyle(WA.textPrimary)
                            Text(profile.role)
                                .font(.system(size: 13))
                                .foregroundStyle(WA.textSecondary)
                        }
                    }
                }
                .listRowSeparatorTint(WA.separator)
            }
            .listStyle(.plain)
            .navigationTitle("新对话")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
