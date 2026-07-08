import SwiftUI

/// Rainmaker UI 共用小件：NPC 配色、资源条、事件预览文案。
enum RainmakerUI {
    /// NPC 头像底色（assistant 走 WA 绿）。
    static func tint(for npcID: String) -> Color {
        switch npcID {
        case NPCCatalog.assistant.id: WA.accent
        case "chen": Color(red: 0.29, green: 0.46, blue: 0.90)
        case "zhou": Color(red: 0.90, green: 0.49, blue: 0.20)
        case "ma": Color(red: 0.56, green: 0.35, blue: 0.86)
        case "liu": Color(red: 0.22, green: 0.60, blue: 0.60)
        default: WA.avatarBg
        }
    }

    /// 线程列表里的最后一条预览。
    static func preview(for event: RainmakerEvent, in state: RainmakerState) -> String {
        switch event {
        case let .npcText(_, text, _): text
        case let .playerText(_, text, _): "我：\(text)"
        case let .dealOffer(_, dealID, _):
            "[项目] \(state.deals.first { $0.id == dealID }?.title ?? "商业计划书")"
        case let .systemNotice(_, text, _): "[通知] \(text)"
        }
    }

    static func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }
}

/// 顶部核心资源条：资金 / 信誉 / 精力。PRD 主视图要求常驻。
struct ResourceBar: View {
    let state: RainmakerState

    var body: some View {
        HStack(spacing: 0) {
            stat(icon: "yensign.circle.fill", tint: .orange,
                 label: "资金", value: "\(state.cash) 万")
            divider
            stat(icon: "rosette", tint: .purple,
                 label: "信誉", value: "\(state.reputation)")
            divider
            stat(icon: "bolt.fill", tint: state.ap > 0 ? .yellow : .gray,
                 label: "精力", value: "\(state.ap)/\(RainmakerBalance.apPerDay)")
            divider
            stat(icon: "calendar", tint: WA.accent,
                 label: "天数", value: "第 \(state.day) 天")
        }
        .padding(.vertical, 10)
        .background(WA.listBg)
        .overlay(alignment: .bottom) {
            WA.separator.frame(height: 0.5)
        }
    }

    private var divider: some View {
        WA.separator.frame(width: 0.5, height: 28)
    }

    private func stat(icon: String, tint: Color, label: String, value: String) -> some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                    .foregroundStyle(tint)
                Text(label)
                    .font(.system(size: 11))
                    .foregroundStyle(WA.textSecondary)
            }
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(WA.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
