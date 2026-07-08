import SwiftUI

/// 聊天详情页：米色涂鸦画布 + 气泡 + 项目卡片（Deal Card）。
struct RainmakerThreadView: View {
    @Bindable var store: RainmakerStore
    let npcID: String

    private var profile: NPCProfile? { NPCCatalog.profile(id: npcID) }
    /// 只渲染已送达的事件（投递节奏在 Store）。
    private var events: [RainmakerEvent] {
        store.visibleEvents(npcID: npcID)
    }
    private var isTyping: Bool { store.typingNPCIDs.contains(npcID) }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(events) { event in
                        eventView(event)
                            .id(event.id)
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }
                    if isTyping {
                        TypingBubble().id("typing")
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .animation(.easeOut(duration: 0.2), value: events.count)
            }
            .background(WADoodleWallpaper())
            .defaultScrollAnchor(.bottom)
            .onChange(of: events.count) {
                store.markRead(npcID: npcID)
                if let last = events.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
            .onChange(of: isTyping) {
                if isTyping { withAnimation { proxy.scrollTo("typing", anchor: .bottom) } }
            }
            .onAppear { store.markRead(npcID: npcID) }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 0) {
                if store.state.activeNegotiation?.npcID == npcID {
                    NegotiationPanel(store: store)
                }
                ComposerBar { text in
                    store.sendMessage(text, to: npcID)
                }
            }
        }
        .navigationTitle(profile.map { "\($0.name) · \($0.role)" } ?? npcID)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Label("\(store.state.ap)", systemImage: "bolt.fill")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(store.state.ap > 0 ? .yellow : .gray)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    @ViewBuilder
    private func eventView(_ event: RainmakerEvent) -> some View {
        switch event {
        case let .npcText(_, _, at):
            TextBubble(text: store.displayText(for: event), at: at, mine: false)
        case let .playerText(_, text, at):
            TextBubble(text: text, at: at, mine: true)
        case let .systemNotice(_, text, _):
            SystemNoticePill(text: text)
        case let .dealOffer(_, dealID, _):
            if let deal = store.state.deals.first(where: { $0.id == dealID }) {
                DealCardBubble(
                    deal: deal,
                    canStart: store.state.ap >= deal.apCost
                        && store.state.reputation >= RainmakerBalance.negotiationRepStake
                        && store.state.activeNegotiation == nil
                ) {
                    store.startNegotiation(dealID: deal.id)
                }
            }
        }
    }
}

/// WhatsApp 式文字气泡（带尾巴）；我方消息带已读双勾。
private struct TextBubble: View {
    let text: String
    let at: Date
    let mine: Bool

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: .trailing, spacing: 2) {
                Text(text)
                    .font(.callout)
                    .foregroundStyle(WA.textPrimary)
                HStack(spacing: 3) {
                    Text(RainmakerUI.timeLabel(at))
                        .font(.caption2)
                        .foregroundStyle(WA.textSecondary)
                    if mine {
                        WADoubleTick()
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(mine ? WA.bubbleOut : WA.bubbleIn)
            .clipShape(BubbleShape(mine: mine))
            if !mine { Spacer(minLength: 48) }
        }
    }
}

/// 「正在输入…」气泡：三点相位闪烁。
private struct TypingBubble: View {
    @State private var phase = 0

    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(WA.textSecondary)
                        .frame(width: 6, height: 6)
                        .opacity(phase == index ? 1 : 0.3)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(WA.bubbleIn)
            .clipShape(BubbleShape(mine: false))
            Spacer(minLength: 48)
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(300))
                phase = (phase + 1) % 3
            }
        }
    }
}

/// WhatsApp 式输入条：＋ / 圆角输入框 / 发送键。
private struct ComposerBar: View {
    let onSend: (String) -> Void
    @State private var text = ""

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.title3)
                .foregroundStyle(WA.textSecondary)
                .frame(width: 32, height: 32)

            TextField("消息", text: $text, axis: .vertical)
                .font(.callout)
                .lineLimit(1...4)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(WA.bubbleIn, in: RoundedRectangle(cornerRadius: 18))
                .overlay(
                    RoundedRectangle(cornerRadius: 18)
                        .stroke(WA.separator, lineWidth: 0.5)
                )

            Button {
                let message = text
                text = ""
                onSend(message)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title)
                    .foregroundStyle(canSend ? WA.accent : WA.textSecondary.opacity(0.5))
            }
            .disabled(!canSend)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.thinMaterial)
    }
}

/// 中置系统通知（结算简报/佣金到账）。
private struct SystemNoticePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(WA.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(WA.bubbleIn.opacity(0.9), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity)
    }
}

/// 项目卡片气泡：商业计划书 + 开始尽调按钮。状态直接显示在卡上。
private struct DealCardBubble: View {
    let deal: DealOffer
    let canStart: Bool
    let onStart: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text.fill")
                        .foregroundStyle(WA.accent)
                    Text("商业计划书")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WA.textSecondary)
                }
                Text(deal.title)
                    .font(.callout.weight(.semibold))
                    .foregroundStyle(WA.textPrimary)
                HStack(spacing: 14) {
                    metric(label: "目标估值", value: "\(deal.valuation) 万")
                    metric(label: "最高佣金", value: "\(deal.commission) 万")
                    metric(label: "工时", value: "-\(deal.apCost)")
                    metric(label: "押信誉", value: "\(RainmakerBalance.negotiationRepStake)")
                }
                actionArea
            }
            .padding(12)
            .frame(maxWidth: 300, alignment: .leading)
            .background(WA.bubbleIn)
            .clipShape(BubbleShape(mine: false))
            Spacer(minLength: 40)
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(WA.textSecondary)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WA.textPrimary)
                .monospacedDigit()
        }
    }

    @ViewBuilder
    private var actionArea: some View {
        switch deal.status {
        case .offered:
            Button(action: onStart) {
                Text(canStart ? "开始尽调谈判" : "工时/信誉不足或另有谈判")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(WA.accent)
            .disabled(!canStart)
        case .negotiating:
            statusLabel("谈判进行中", icon: "bubble.left.and.exclamationmark.bubble.right.fill", tint: .orange)
        case .won:
            statusLabel("已成交 · 佣金到账", icon: "checkmark.seal.fill", tint: WA.accent)
        case .busted:
            statusLabel("交易流产", icon: "xmark.circle.fill", tint: .red)
        case .expired:
            statusLabel("已过期", icon: "xmark.circle.fill", tint: .gray)
        }
    }

    private func statusLabel(_ text: String, icon: String, tint: Color) -> some View {
        Label(text, systemImage: icon)
            .font(.footnote.weight(.medium))
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }
}

/// 谈判面板：对方底线估值条 + 手上的策略包 + 同意签约。
/// PRD 4.2/4.3：出牌算分 chips × mult，见好就收 vs 继续压价（爆仓风险）。
private struct NegotiationPanel: View {
    @Bindable var store: RainmakerStore
    @State private var glossaryEntry: GlossaryEntry?

    private var session: NegotiationSession? { store.state.activeNegotiation }

    var body: some View {
        if let session {
            VStack(spacing: 10) {
                // 底线估值条（越低压得越狠、佣金越高）
                VStack(spacing: 4) {
                    HStack {
                        Text("对方底线估值")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(WA.textSecondary)
                        Spacer()
                        Text("\(session.defense) / \(session.defenseMax)")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(WA.textPrimary)
                            .monospacedDigit()
                    }
                    ProgressView(value: Double(session.defense), total: Double(session.defenseMax))
                        .tint(session.defense <= Int(Double(session.defenseMax) * RainmakerBalance.signUnlockRatio) ? WA.accent : .orange)
                }

                // 手牌：横滑策略包
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(session.hand, id: \.self) { cardID in
                            if let card = CardCatalog.card(id: cardID) {
                                Button {
                                    store.play(cardID: cardID)
                                } label: {
                                    StrategyCardFace(card: card) {
                                        glossaryEntry = Glossary.entry(id: card.glossaryID)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                // 见好就收
                Button {
                    store.sign()
                } label: {
                    Text(NegotiationEngine.canSign(state: store.state)
                         ? "同意签约 · 预计佣金 \(NegotiationEngine.estimatedPayout(state: store.state) ?? 0) 万"
                         : "还压不动对方——继续出牌或认栽")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.borderedProminent)
                .tint(WA.accent)
                .disabled(!NegotiationEngine.canSign(state: store.state))
            }
            .padding(12)
            .background(.thinMaterial)
            .sheet(item: $glossaryEntry) { entry in
                GlossarySheet(entry: entry)
            }
        }
    }
}

/// 策略包卡面：名称 + 筹码×倍率 + 特效角标 + ⓘ 词条入口。
private struct StrategyCardFace: View {
    let card: TalkCard
    let onInfo: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                Text(card.name)
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WA.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .font(.footnote)
                        .foregroundStyle(WA.textSecondary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 4) {
                Text("\(card.chips)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.blue)
                Text("× \(String(format: "%.1f", card.mult))")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.red)
            }
            .monospacedDigit()
            if let effect = card.effect {
                Text(effect == .vamHighRisk ? "⚠️ 高危" : "🛡 保本")
                    .font(.caption2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(width: 118, alignment: .leading)
        .background(WA.bubbleIn, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(WA.separator, lineWidth: 0.5)
        )
    }
}
