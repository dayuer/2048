import SwiftUI

/// 聊天详情页：米色涂鸦画布 + 气泡 + 项目卡片（Deal Card）。
struct RainmakerThreadView: View {
    @Bindable var store: RainmakerStore
    let npcID: String

    private var profile: NPCProfile? { NPCCatalog.profile(id: npcID) }
    private var events: [RainmakerEvent] {
        store.state.threads.first { $0.id == npcID }?.events ?? []
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(events) { event in
                        eventView(event)
                            .id(event.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(WADoodleWallpaper())
            .defaultScrollAnchor(.bottom)
            .onChange(of: events.count) {
                if let last = events.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if store.state.activeNegotiation?.npcID == npcID {
                NegotiationPanel(store: store)
            }
        }
        .navigationTitle(profile.map { "\($0.name) · \($0.role)" } ?? npcID)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Label("\(store.state.ap)", systemImage: "bolt.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(store.state.ap > 0 ? .yellow : .gray)
                    .labelStyle(.titleAndIcon)
            }
        }
    }

    @ViewBuilder
    private func eventView(_ event: RainmakerEvent) -> some View {
        switch event {
        case let .npcText(_, text, at):
            TextBubble(text: text, at: at, mine: false)
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

/// WhatsApp 式文字气泡（带尾巴）。
private struct TextBubble: View {
    let text: String
    let at: Date
    let mine: Bool

    var body: some View {
        HStack {
            if mine { Spacer(minLength: 48) }
            VStack(alignment: .trailing, spacing: 2) {
                Text(text)
                    .font(.system(size: 16))
                    .foregroundStyle(WA.textPrimary)
                Text(RainmakerUI.timeLabel(at))
                    .font(.system(size: 11))
                    .foregroundStyle(WA.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(mine ? WA.bubbleOut : WA.bubbleIn)
            .clipShape(BubbleShape(mine: mine))
            if !mine { Spacer(minLength: 48) }
        }
    }
}

/// 中置系统通知（结算简报/佣金到账）。
private struct SystemNoticePill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.system(size: 13))
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
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(WA.textSecondary)
                }
                Text(deal.title)
                    .font(.system(size: 16, weight: .semibold))
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
                .font(.system(size: 11))
                .foregroundStyle(WA.textSecondary)
            Text(value)
                .font(.system(size: 14, weight: .semibold))
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
                    .font(.system(size: 15, weight: .semibold))
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
            .font(.system(size: 13, weight: .medium))
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
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(WA.textSecondary)
                        Spacer()
                        Text("\(session.defense) / \(session.defenseMax)")
                            .font(.system(size: 12, weight: .semibold))
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
                        .font(.system(size: 15, weight: .semibold))
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
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(WA.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Button(action: onInfo) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 13))
                        .foregroundStyle(WA.textSecondary)
                }
                .buttonStyle(.plain)
            }
            HStack(spacing: 4) {
                Text("\(card.chips)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.blue)
                Text("× \(String(format: "%.1f", card.mult))")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.red)
            }
            .monospacedDigit()
            if let effect = card.effect {
                Text(effect == .vamHighRisk ? "⚠️ 高危" : "🛡 保本")
                    .font(.system(size: 10))
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
