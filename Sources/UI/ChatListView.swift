import SwiftUI

/// 对话列表：AI 置顶行 + 真人线程行。微信风白行 + 发丝分隔。
struct ChatListView: View {
    let chat: ChatStore

    var body: some View {
        NavigationStack {
            List {
                ForEach(chat.threads) { thread in
                    NavigationLink {
                        ThreadView(chat: chat, threadID: thread.id)
                    } label: {
                        row(for: thread)
                    }
                    .listRowBackground(Shell.card)
                }
            }
            .listStyle(.plain)
            .background(Shell.page)
            .navigationTitle("对话")
        }
    }

    @ViewBuilder
    private func row(for thread: ChatThread) -> some View {
        let isAI = thread.id == ChatStore.aiThreadID
        HStack(spacing: 12) {
            Image(systemName: isAI ? "cpu.fill" : "person.fill")
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(isAI ? Shell.accent : Shell.textSecondary, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
            VStack(alignment: .leading, spacing: 3) {
                Text(thread.nickname)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(Shell.textPrimary)
                Text(isAI ? "随时开战" : subtitle(for: thread))
                    .font(.system(size: 13))
                    .foregroundStyle(Shell.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
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
