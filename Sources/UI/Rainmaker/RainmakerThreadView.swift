import SwiftUI

/// 聊天详情页：1:1 复刻 WhatsApp iOS——自定义导航头（头像+在线状态+音视频钮）、
/// 日期分隔 pill、带尾气泡、文档卡（项目单伪装成 .docx）、原版 composer。
/// 军规：任何时候看不出是游戏——玩法入口全部长成聊天附件的样子。
struct RainmakerThreadView: View {
    @Bindable var store: RainmakerStore
    let npcID: String
    @State private var openedDealID: UUID?
    @State private var showMarket = false
    @State private var showRepay = false

    private var profile: NPCProfile? { NPCCatalog.profile(id: npcID) }
    /// 只渲染已送达的事件（投递节奏在 Store）。
    private var events: [RainmakerEvent] {
        store.visibleEvents(npcID: npcID)
    }
    private var isTyping: Bool { store.typingNPCIDs.contains(npcID) }

    /// 在线状态副标题：正在输入 > 最后一条对方消息时间（确定性，取自状态）。
    private var presenceText: String {
        if isTyping { return "正在输入…" }
        if npcID == NPCCatalog.assistant.id { return "在线" }
        if let lastIncoming = events.last(where: { !$0.isMine }) {
            return "最后上线于\(RainmakerUI.presenceLabel(lastIncoming.at))"
        }
        return "点击查看联系人信息"
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(Array(events.enumerated()), id: \.element.id) { index, event in
                        // 跨天插入日期分隔 pill（「6月5日 周五」）
                        if index == 0 || !Calendar.current.isDate(events[index - 1].at, inSameDayAs: event.at) {
                            DayPill(date: event.at)
                        }
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
                ComposerBar(
                    onSend: { text in store.sendMessage(text, to: npcID) },
                    onPlus: plusAction
                )
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // WhatsApp 导航头：头像 + 名字 + 在线状态副标题
            ToolbarItem(placement: .principal) {
                HStack(spacing: 10) {
                    WAAvatar(
                        systemImage: profile?.icon ?? "person.fill",
                        background: RainmakerUI.tint(for: npcID),
                        size: 36
                    )
                    VStack(alignment: .leading, spacing: 1) {
                        Text(profile?.name ?? npcID)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(WA.textPrimary)
                        Text(presenceText)
                            .font(.caption)
                            .foregroundStyle(isTyping ? WA.accent : WA.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            // 音视频按钮（WhatsApp 常驻元素，观感装饰）
            ToolbarItem(placement: .topBarTrailing) {
                HStack(spacing: 18) {
                    Image(systemName: "video")
                    Image(systemName: "phone")
                }
                .font(.body.weight(.medium))
                .foregroundStyle(WA.textPrimary)
            }
        }
        .sheet(item: Binding(
            get: { openedDealID.map(DealSheetID.init) },
            set: { openedDealID = $0?.id }
        )) { opened in
            if let deal = store.state.deals.first(where: { $0.id == opened.id }) {
                DealDetailSheet(store: store, deal: deal)
                    .presentationDetents([.medium])
            }
        }
        .sheet(isPresented: $showMarket) {
            MarketSheet(store: store, dealerID: npcID)
        }
        .sheet(isPresented: $showRepay) {
            RepaySheet(store: store)
                .presentationDetents([.medium])
        }
    }

    /// 「+」附件入口：玩法藏在这里——贩子线程开行情、资方线程开还款，其余无附件。
    private var plusAction: (() -> Void)? {
        if TradeCatalog.venueOfDealer(npcID) != nil {
            return { showMarket = true }
        }
        if npcID == NPCCatalog.creditor.id {
            return { showRepay = true }
        }
        return nil
    }

    @ViewBuilder
    private func eventView(_ event: RainmakerEvent) -> some View {
        switch event {
        case let .npcText(_, _, at):
            TextBubble(text: store.displayText(for: event), at: at, mine: false)
        case let .playerText(_, text, at):
            TextBubble(text: text, at: at, mine: true)
        case .systemNotice:
            // 已废弃：旁白改走通知横幅/通知中心；旧存档事件在 Store 加载时已迁移
            EmptyView()
        case let .dealOffer(_, dealID, at):
            if let deal = store.state.deals.first(where: { $0.id == dealID }) {
                DealDocBubble(deal: deal, at: at) {
                    openedDealID = deal.id
                }
            }
        }
    }
}

/// sheet(item:) 的 Identifiable 包装。
private struct DealSheetID: Identifiable {
    let id: UUID
}

/// 日期分隔 pill：中置圆角 chip（今天 / 昨天 / 「6月5日 周五」）。
private struct DayPill: View {
    let date: Date

    private var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "今天" }
        if calendar.isDateInYesterday(date) { return "昨天" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "M月d日 EEE"
        return formatter.string(from: date)
    }

    var body: some View {
        Text(label)
            .font(.footnote)
            .foregroundStyle(WA.textSecondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 5)
            .background(WA.bubbleIn.opacity(0.92), in: RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 4)
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

/// WhatsApp 原版输入条：＋ / 圆角输入框（内嵌贴纸钮）/ 相机 / 麦克风；
/// 输入中换成绿色发送键。＋ 是玩法的伪装入口（行情/还款），无附件线程点击无响应。
private struct ComposerBar: View {
    let onSend: (String) -> Void
    /// nil = 该线程无附件功能（＋ 仅作观感）。
    let onPlus: (() -> Void)?
    @State private var text = ""

    private var isEmpty: Bool {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack(spacing: 12) {
            Button {
                onPlus?()
            } label: {
                Image(systemName: "plus")
                    .font(.title2)
                    .foregroundStyle(WA.textPrimary)
            }
            .frame(width: 30, height: 32)

            // 圆角输入框，右侧内嵌贴纸按钮（WhatsApp 形态）
            HStack(spacing: 6) {
                TextField("", text: $text, axis: .vertical)
                    .font(.callout)
                    .lineLimit(1...4)
                Image(systemName: "face.smiling")
                    .font(.body)
                    .foregroundStyle(WA.textSecondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(WA.bubbleIn, in: RoundedRectangle(cornerRadius: 18))
            .overlay(
                RoundedRectangle(cornerRadius: 18)
                    .stroke(WA.separator, lineWidth: 0.5)
            )

            if isEmpty {
                // 空输入：相机 + 麦克风（观感装饰）
                Image(systemName: "camera")
                    .font(.title3)
                    .foregroundStyle(WA.textPrimary)
                Image(systemName: "mic")
                    .font(.title3)
                    .foregroundStyle(WA.textPrimary)
            } else {
                Button {
                    let message = text
                    text = ""
                    onSend(message)
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.body.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(WA.accent, in: Circle())
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(.thinMaterial)
        .animation(.easeOut(duration: 0.15), value: isEmpty)
    }
}

/// 项目单伪装成文档消息（截图同款）：文件图标 + 「XX·商业计划书.docx」+
/// 大小 · docx + 侧边转发圆钮 + 时间。点卡打开 BP 详情（指标与开始尽调都在 sheet 里）。
private struct DealDocBubble: View {
    let deal: DealOffer
    let at: Date
    let onOpen: () -> Void

    /// 文件大小观感字段（确定性：由估值派生，同档同值）。
    private var fileSize: String { "\(48 + deal.valuation % 150) KB" }

    private var statusHint: String? {
        switch deal.status {
        case .offered: nil
        case .negotiating: "会谈进行中"
        case .won: "已签约"
        case .busted: "已终止"
        case .expired: "已撤回"
        }
    }

    var body: some View {
        HStack(alignment: .center, spacing: 8) {
            Button(action: onOpen) {
                VStack(alignment: .trailing, spacing: 4) {
                    HStack(spacing: 10) {
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color(red: 0.26, green: 0.45, blue: 0.91))
                            .frame(width: 36, height: 36)
                            .overlay(
                                Image(systemName: "doc.fill")
                                    .font(.body)
                                    .foregroundStyle(.white)
                            )
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(deal.title)·商业计划书.docx")
                                .font(.callout)
                                .foregroundStyle(WA.textPrimary)
                                .multilineTextAlignment(.leading)
                            HStack(spacing: 4) {
                                Text("\(fileSize) · docx")
                                    .font(.caption)
                                    .foregroundStyle(WA.textSecondary)
                                if let statusHint {
                                    Text("· \(statusHint)")
                                        .font(.caption)
                                        .foregroundStyle(WA.textSecondary)
                                }
                            }
                        }
                    }
                    Text(RainmakerUI.timeLabel(at))
                        .font(.caption2)
                        .foregroundStyle(WA.textSecondary)
                }
                .padding(12)
                .frame(maxWidth: 300, alignment: .leading)
                .background(WA.bubbleIn)
                .clipShape(BubbleShape(mine: false))
            }
            .buttonStyle(.plain)

            // 转发圆钮（WhatsApp 文档消息旁的观感元素）
            Image(systemName: "arrowshape.turn.up.right.fill")
                .font(.footnote)
                .foregroundStyle(WA.textSecondary)
                .frame(width: 34, height: 34)
                .background(WA.bubbleIn.opacity(0.8), in: Circle())

            Spacer(minLength: 6)
        }
    }
}

/// 商业计划书详情：原项目卡的指标、说明与「开始尽调」都收在这里——
/// 聊天流里只留一张干净的文档卡。
private struct DealDetailSheet: View {
    @Bindable var store: RainmakerStore
    let deal: DealOffer
    @Environment(\.dismiss) private var dismiss

    private var canStart: Bool {
        store.state.ap >= deal.apCost
            && store.state.reputation >= RainmakerBalance.negotiationRepStake
            && store.state.activeNegotiation == nil
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 16) {
                Text(deal.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(WA.textPrimary)
                HStack(spacing: 20) {
                    metric(label: "项目估值", value: "\(deal.valuation) 万")
                    metric(label: "佣金上限", value: "\(deal.commission) 万")
                    metric(label: "工时", value: "-\(deal.apCost)")
                    metric(label: "押信誉", value: "\(RainmakerBalance.negotiationRepStake)")
                }
                Text("估值＝项目规模（决定谈判难度）。佣金按压价深度浮动：击破对方底线拿满上限，见好就收只拿一部分。")
                    .font(.footnote)
                    .foregroundStyle(WA.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                actionArea
            }
            .padding(20)
            .navigationTitle("商业计划书")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func metric(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
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
            Button {
                store.startNegotiation(dealID: deal.id)
                dismiss()
            } label: {
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
    /// 佣金上限（该项目单的 commission）。
    private var commissionCap: Int {
        guard let session = store.state.activeNegotiation else { return 0 }
        return store.state.deals.first { $0.id == session.dealID }?.commission ?? 0
    }

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

                // 实时佣金读数：把「压价深度→佣金」讲透，消除困惑
                HStack {
                    Text("预计到手佣金")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(WA.textSecondary)
                    Spacer()
                    Text("\(NegotiationEngine.estimatedPayout(state: store.state) ?? 0) / 上限 \(commissionCap) 万")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(WA.textPrimary)
                        .monospacedDigit()
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
                         ? "同意签约 · 拿佣金 \(NegotiationEngine.estimatedPayout(state: store.state) ?? 0) 万（上限 \(commissionCap)）"
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
