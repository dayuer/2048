import SwiftUI

/// 对话列表：WhatsApp Chats 复刻。大标题 + 搜索框 + 圆头像行 + 右上时间戳；
/// AI 置顶不可删，真人线程左滑删除。
struct ChatListView: View {
    let chat: ChatStore

    @State private var query = ""

    private var visibleThreads: [ChatThread] {
        guard !query.isEmpty else { return chat.threads }
        return chat.threads.filter { $0.nickname.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(visibleThreads) { thread in
                    NavigationLink {
                        ThreadView(chat: chat, threadID: thread.id)
                    } label: {
                        row(for: thread)
                    }
                    .listRowBackground(WA.listBg)
                    .listRowSeparatorTint(WA.separator)
                    .alignmentGuide(.listRowSeparatorLeading) { _ in 64 }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if thread.id != ChatStore.aiThreadID {
                            Button(role: .destructive) {
                                chat.delete(id: thread.id)
                            } label: {
                                Label("删除", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .listStyle(.plain)
            .background(WA.listBg)
            .scrollContentBackground(.hidden)
            .searchable(text: $query, prompt: "搜索")
            .navigationTitle("对话")
        }
    }

    @ViewBuilder
    private func row(for thread: ChatThread) -> some View {
        let isAI = thread.id == ChatStore.aiThreadID
        HStack(spacing: 12) {
            WAAvatar(
                systemImage: isAI ? "cpu.fill" : "person.fill",
                background: isAI ? WA.accent : WA.avatarBg
            )
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(thread.nickname)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(WA.textPrimary)
                    Spacer()
                    if let at = thread.events.last?.at {
                        Text(at, format: .dateTime.hour().minute())
                            .font(.system(size: 15))
                            .foregroundStyle(WA.textSecondary)
                    }
                }
                Text(isAI ? "随时开战" : subtitle(for: thread))
                    .font(.system(size: 15))
                    .foregroundStyle(WA.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }

    private func subtitle(for thread: ChatThread) -> String {
        switch thread.events.last {
        case let .message(_, text, _, _): return text
        case .battleInvite: return "发起了一局对战"
        case let .battleResult(_, _, my, their, _): return "对战结束 \(my) : \(their)"
        case nil: return "开始一段对话"
        }
    }
}
