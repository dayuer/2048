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
                DealCardBubble(deal: deal, ap: store.state.ap) {
                    store.accept(dealID: deal.id)
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

/// 项目卡片气泡：商业计划书 + 接单按钮。状态四态直接显示在卡上。
private struct DealCardBubble: View {
    let deal: DealOffer
    let ap: Int
    let onAccept: () -> Void

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
                    metric(label: "成功佣金", value: "\(deal.commission) 万")
                    metric(label: "精力", value: "-\(deal.apCost)")
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
            Button(action: onAccept) {
                Text(ap >= deal.apCost ? "接单（-\(deal.apCost) 工时）" : "尽调工时不足")
                    .font(.system(size: 15, weight: .semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .tint(WA.accent)
            .disabled(ap < deal.apCost)
        case .accepted:
            statusLabel("已接单 · 明日结算", icon: "clock.fill", tint: .orange)
        case .paid:
            statusLabel("已交割 · 佣金 +\(deal.commission) 万", icon: "checkmark.seal.fill", tint: WA.accent)
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
