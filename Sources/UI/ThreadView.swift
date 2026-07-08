import SwiftUI

/// 线程详情：WhatsApp 会话页复刻。涂鸦画布 + 带尾气泡 + 气泡内时间戳；
/// 导航栏 = 头像 + 名字/副题。AI 线程底部「开战」（进入单人 2048，1a 占位）；
/// 真人线程底部 = 复刻输入条的禁用引导态（D/C 前）。
struct ThreadView: View {
    let chat: ChatStore
    let threadID: String

    @State private var playing = false

    private var thread: ChatThread? { chat.thread(id: threadID) }
    private var isAI: Bool { threadID == ChatStore.aiThreadID }

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                WADoodleWallpaper()
                ScrollView {
                    LazyVStack(spacing: 4) {
                        if let events = thread?.events, !events.isEmpty {
                            ForEach(events) { event in
                                EventCard(event: event)
                            }
                        } else {
                            // 复刻 WhatsApp 中置系统提示条的形态，承载我们的引导文案
                            Text(isAI ? "跟本地 AI 对手来一局——永远不用等人。" : "还没有消息。")
                                .font(.system(size: 13))
                                .foregroundStyle(WA.textSecondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(WA.bubbleIn, in: RoundedRectangle(cornerRadius: 8))
                                .padding(.top, 16)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                }
            }

            footer
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    WAAvatar(
                        systemImage: isAI ? "cpu.fill" : "person.fill",
                        background: isAI ? WA.accent : WA.avatarBg,
                        size: 34
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(thread?.nickname ?? "对话")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(WA.textPrimary)
                        Text(isAI ? "本地 AI · 随时在线" : "附近的人")
                            .font(.system(size: 12))
                            .foregroundStyle(WA.textSecondary)
                    }
                    Spacer()
                }
            }
        }
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
            .buttonStyle(WAPrimaryButtonStyle())
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(WA.listBg)
        } else {
            // 真人线程：复刻 WhatsApp 输入条形态，D/C 落地前整体禁用
            HStack(spacing: 10) {
                Image(systemName: "plus")
                    .font(.system(size: 22))
                    .foregroundStyle(WA.textSecondary)
                Text("消息与对战即将开放")
                    .font(.system(size: 16))
                    .foregroundStyle(WA.textSecondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(WA.bubbleIn, in: Capsule())
                Image(systemName: "mic")
                    .font(.system(size: 22))
                    .foregroundStyle(WA.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(WA.listBg)
        }
    }
}

/// 一条事件的渲染：消息气泡（带尾）/ 对战邀请气泡 / 对战结果中置卡。
struct EventCard: View {
    let event: ThreadEvent

    var body: some View {
        switch event {
        case let .message(_, text, mine, at):
            bubble(mine: mine, at: at) {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(WA.textPrimary)
            }
        case let .battleInvite(_, _, seed, mine, at):
            bubble(mine: mine, at: at) {
                HStack(spacing: 10) {
                    Image(systemName: "flag.checkered")
                        .font(.system(size: 22))
                        .foregroundStyle(WA.accent)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("对战邀请")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(WA.textPrimary)
                        Text("种子 \(seed)")
                            .font(.system(size: 13))
                            .foregroundStyle(WA.textSecondary)
                    }
                }
            }
        case let .battleResult(_, _, my, their, at):
            // 复刻 WhatsApp 中置系统卡（如加密提示/日期条）承载结果
            VStack(spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(WA.accent)
                    Text("对战结束 · 你 \(my) : \(their) 对手")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(WA.textPrimary)
                }
                Text(at, format: .dateTime.hour().minute())
                    .font(.system(size: 11))
                    .foregroundStyle(WA.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(WA.bubbleIn, in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
        }
    }

    /// WhatsApp 气泡：内容 + 右下角时间戳，带顶部外侧尾巴，最大宽度 75%。
    private func bubble(mine: Bool, at: Date, @ViewBuilder content: () -> some View) -> some View {
        HStack {
            if mine { Spacer(minLength: 60) }
            VStack(alignment: .trailing, spacing: 2) {
                content()
                Text(at, format: .dateTime.hour().minute())
                    .font(.system(size: 11))
                    .foregroundStyle(WA.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .padding(mine ? .trailing : .leading, 6)   // 尾巴占位
            .background(BubbleShape(mine: mine).fill(mine ? WA.bubbleOut : WA.bubbleIn))
            .shadow(color: .black.opacity(0.06), radius: 0.5, y: 0.5)
            if !mine { Spacer(minLength: 60) }
        }
    }
}
