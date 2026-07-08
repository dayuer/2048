import SwiftUI

/// 主视图：WhatsApp 式列表页——大标题 + 搜索 + 筛选 chips + 无箭头行，
/// 叠加经营 chrome（顶部资源条 + 底部结束今日）。
struct MessagesView: View {
    @Bindable var store: RainmakerStore
    @State private var query = ""
    @State private var filter: RainmakerStore.ThreadFilter = .all
    @State private var showNewChat = false
    @State private var showTravel = false
    @State private var path = NavigationPath()

    private var threads: [NPCThread] {
        store.filteredThreads(query: query, filter: filter)
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                List {
                    filterChips
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                        .listRowSeparator(.hidden)

                    // 置顶「系统通知」入口（微信服务通知形态）：旁白不进聊天，都归这里
                    ZStack {
                        NavigationLink(value: NoticeRoute.center) { EmptyView() }.opacity(0)
                        NoticeCenterRow(store: store)
                    }
                    .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
                    .listRowSeparatorTint(WA.separator)

                    ForEach(threads) { thread in
                        ZStack {
                            // 隐形跳转层：去掉系统 chevron（WhatsApp 行没有箭头）
                            NavigationLink(value: thread.id) { EmptyView() }.opacity(0)
                            ThreadRow(store: store, npcID: thread.id)
                        }
                        // WhatsApp 行规格：头像 52 + 上下 12 ≈ 76pt 行高
                        .listRowInsets(EdgeInsets(top: 12, leading: 16, bottom: 12, trailing: 16))
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
            }
            .background(WA.listBg)
            .navigationTitle("消息")
            .navigationBarTitleDisplayMode(.large)
            .navigationDestination(for: String.self) { npcID in
                RainmakerThreadView(store: store, npcID: npcID)
            }
            .navigationDestination(for: NoticeRoute.self) { _ in
                NoticeCenterView(store: store)
            }
            .toolbar {
                // 右上两枚按钮：跑市场（航班）+ 新对话（加号）。
                // 同一 Group 内各自独立 hit 区，避免相邻 toolbar 按钮点按互相触发。
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showTravel = true
                    } label: {
                        Image(systemName: "airplane.departure")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(WA.textPrimary)
                            .frame(width: 34, height: 34)
                            .background(WA.separator.opacity(0.6), in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)

                    Button {
                        showNewChat = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 34, height: 34)
                            .background(WA.accent, in: Circle())
                            .contentShape(Circle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .sheet(isPresented: $showNewChat) {
                NewChatSheet { npcID in
                    showNewChat = false
                    path.append(npcID)
                }
            }
            .sheet(isPresented: $showTravel) {
                TravelSheet(store: store)
            }
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
                            .font(.subheadline.weight(.medium))
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
        // WhatsApp 对齐：头像垂直居中；名字与时间同基线；预览最多两行、时间与预览同级字号
        HStack(spacing: 12) {
            NPCAvatar(npcID: npcID)
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(profile?.name ?? npcID)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(WA.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 8)
                    if let last = lastVisible {
                        Text(RainmakerUI.listTimeLabel(last.at))
                            .font(.subheadline)
                            .foregroundStyle(unread > 0 ? WA.accent : WA.textSecondary)
                    }
                }
                HStack(alignment: .top, spacing: 4) {
                    if isTyping {
                        Text("正在输入…")
                            .font(.subheadline)
                            .foregroundStyle(WA.accent)
                            .lineLimit(1)
                    } else if let last = lastVisible {
                        if last.isMine {
                            WADoubleTick()
                                .padding(.top, 3)
                        }
                        Text(RainmakerUI.preview(for: last, in: store.state))
                            .font(.subheadline)
                            .foregroundStyle(WA.textSecondary)
                            .lineLimit(2)
                    }
                    Spacer(minLength: 8)
                    if unread > 0 {
                        Text("\(unread)")
                            .font(.caption.weight(.semibold))
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
        [NPCCatalog.assistant, NPCCatalog.creditor] + NPCCatalog.contacts + NPCCatalog.dealers
    }

    var body: some View {
        NavigationStack {
            List(allProfiles) { profile in
                Button {
                    onSelect(profile.id)
                } label: {
                    HStack(spacing: 12) {
                        NPCAvatar(npcID: profile.id, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(profile.name)
                                .font(.body)
                                .foregroundStyle(WA.textPrimary)
                            Text(profile.role)
                                .font(.footnote)
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
