import SwiftUI

/// 线程详情：事件卡流。AI 线程底部是「开战」主按钮（进入单人 2048，1a 占位对战屏）；
/// 真人线程底部是禁用的输入框 + 「＋」（D/C 前引导态）。
struct ThreadView: View {
    let chat: ChatStore
    let threadID: String

    @State private var playing = false

    private var thread: ChatThread? { chat.thread(id: threadID) }
    private var isAI: Bool { threadID == ChatStore.aiThreadID }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                LazyVStack(spacing: 10) {
                    if let events = thread?.events, !events.isEmpty {
                        ForEach(events) { event in
                            EventCard(event: event)
                        }
                    } else {
                        Text(isAI ? "跟本地 AI 对手来一局——永远不用等人。" : "还没有消息。")
                            .font(.system(size: 14))
                            .foregroundStyle(Shell.textSecondary)
                            .padding(.top, 40)
                    }
                }
                .padding(16)
            }
            .background(Shell.page)

            Divider().background(Shell.separator)
            footer
        }
        .navigationTitle(thread?.nickname ?? "对话")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $playing) {
            // 1a：AI 线程「开战」= 真实可玩单人 2048。不伪造对手结果（Phase 1b 接真 bot）。
            GameView(onExit: { playing = false })
                .background(Theme.background.ignoresSafeArea())
        }
    }

    @ViewBuilder
    private var footer: some View {
        if isAI {
            Button {
                playing = true
            } label: {
                Text("开战")
            }
            .buttonStyle(WeChatPrimaryButtonStyle())
            .padding(16)
        } else {
            // 真人线程：D/C 落地前禁用引导态
            HStack(spacing: 10) {
                Image(systemName: "plus.circle")
                    .foregroundStyle(Shell.textSecondary)
                Text("消息与对战即将开放")
                    .font(.system(size: 15))
                    .foregroundStyle(Shell.textSecondary)
                Spacer()
            }
            .padding(16)
            .background(Shell.card)
        }
    }
}

/// 一张事件卡：消息气泡 / 对战邀请 / 对战结果。
struct EventCard: View {
    let event: ThreadEvent

    var body: some View {
        switch event {
        case let .message(_, text, mine, _):
            HStack {
                if mine { Spacer() }
                Text(text)
                    .font(.system(size: 15))
                    .foregroundStyle(mine ? .white : Shell.textPrimary)
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(mine ? Shell.accent : Shell.card, in: RoundedRectangle(cornerRadius: Shell.radius))
                if !mine { Spacer() }
            }
        case let .battleInvite(_, _, seed, _, _):
            card(icon: "flag.checkered", title: "对战邀请", subtitle: "种子 \(seed)")
        case let .battleResult(_, _, my, their, _):
            card(icon: "trophy.fill", title: "对战结果", subtitle: "你 \(my) : \(their) 对手")
        }
    }

    private func card(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon).foregroundStyle(Shell.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 15, weight: .medium)).foregroundStyle(Shell.textPrimary)
                Text(subtitle).font(.system(size: 13)).foregroundStyle(Shell.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(Shell.card, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
    }
}
