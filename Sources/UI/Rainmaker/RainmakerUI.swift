import SwiftUI

/// Rainmaker UI 共用小件：NPC 配色、资源条、事件预览文案。
enum RainmakerUI {
    /// NPC 头像底色：每人一个可辨识的专属色（像真实通讯录里各人的头像底）。
    static func tint(for npcID: String) -> Color {
        switch npcID {
        case NPCCatalog.assistant.id: WA.accent                       // 小何 · 绿
        case NPCCatalog.creditor.id: rgb(0.16, 0.23, 0.38)            // 沈墨 · 深西装蓝
        // 商界联系人
        case "chen": rgb(0.29, 0.46, 0.90)                            // 陈总 · 蓝
        case "zhou": rgb(0.90, 0.49, 0.20)                            // 周老板 · 橙
        case "ma": rgb(0.56, 0.35, 0.86)                              // 马姐 · 紫
        case "liu": rgb(0.22, 0.60, 0.60)                             // 大刘 · 青
        // 十城驻场贩子
        case "dealer-bj": rgb(0.82, 0.33, 0.33)                       // 老猫 · 京红
        case "dealer-sh": rgb(0.85, 0.62, 0.14)                       // 金姐 · 沪金
        case "dealer-sz": rgb(0.15, 0.60, 0.76)                       // 老K · 科技蓝
        case "dealer-hk": rgb(0.86, 0.30, 0.55)                       // Tony 蔡 · 港粉
        case "dealer-sg": rgb(0.16, 0.62, 0.45)                       // 谭叔 · 南洋绿
        case "dealer-jp": rgb(0.42, 0.45, 0.72)                       // 佐藤桑 · 靛
        case "dealer-du": rgb(0.80, 0.53, 0.24)                       // 哈桑 · 沙金
        case "dealer-zh": rgb(0.38, 0.46, 0.56)                       // 穆勒 · 钢灰蓝
        case "dealer-ld": rgb(0.55, 0.20, 0.30)                       // 查尔斯 · 酒红
        case "dealer-us": rgb(0.20, 0.34, 0.52)                       // 朴哥 · 华尔街靛蓝
        default: WA.avatarBg
        }
    }

    /// NPC 头像字（姓氏 / 名号关键字）：像真实通讯录的首字母头像。
    static func monogram(for npcID: String) -> String {
        switch npcID {
        case NPCCatalog.assistant.id: "何"
        case NPCCatalog.creditor.id: "沈"
        case "chen": "陈"
        case "zhou": "周"
        case "ma": "马"
        case "liu": "刘"
        case "dealer-bj": "猫"
        case "dealer-sh": "金"
        case "dealer-sz": "K"
        case "dealer-hk": "蔡"
        case "dealer-sg": "谭"
        case "dealer-jp": "佐"
        case "dealer-du": "哈"
        case "dealer-zh": "穆"
        case "dealer-ld": "查"
        case "dealer-us": "朴"
        default: String(NPCCatalog.profile(id: npcID)?.name.prefix(1) ?? "?")
        }
    }

    private static func rgb(_ r: Double, _ g: Double, _ b: Double) -> Color {
        Color(red: r, green: g, blue: b)
    }

    /// 线程列表里的最后一条预览（我方消息由行内 ✓✓ 标识，不加“我：”前缀）。
    static func preview(for event: RainmakerEvent, in state: RainmakerState) -> String {
        switch event {
        case let .npcText(_, text, _): text
        case let .playerText(_, text, _): text
        case let .dealOffer(_, dealID, _):
            "📄 \(state.deals.first { $0.id == dealID }?.title ?? "商业计划书")"
        case let .systemNotice(_, text, _): "🔔 \(text)"
        }
    }

    static func timeLabel(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    /// 在线状态："最后上线于" 的后缀（今天→「15:17」，昨天→「昨天 15:17」，更早→「周二 15:17」）。
    static func presenceLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        let time = date.formatted(date: .omitted, time: .shortened)
        if calendar.isDateInToday(date) { return time }
        if calendar.isDateInYesterday(date) { return "昨天 \(time)" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "EEE"
        return "\(formatter.string(from: date)) \(time)"
    }

    /// 列表时间：今天→时刻，昨天→「昨天」，更早→短日期（WhatsApp 形态）。
    static func listTimeLabel(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        if calendar.isDateInYesterday(date) {
            return "昨天"
        }
        return date.formatted(date: .numeric, time: .omitted)
    }
}

/// NPC 头像：专属色渐变圆 + 姓氏字（像真实通讯录里设了头像的联系人）。
/// 系统/城市等非人格 tile 仍用 WAAvatar 的 SF Symbol 形态。
struct NPCAvatar: View {
    let npcID: String
    var size: CGFloat = 52

    private var base: Color { RainmakerUI.tint(for: npcID) }

    /// 头像图资产名：优先人设显式指定，否则按约定 avatar_<id>（连字符转下划线）。
    /// 约定名让新头像「丢进资产目录即生效」，无需改代码。
    private var assetName: String {
        NPCCatalog.profile(id: npcID)?.avatarImage
            ?? "avatar_" + npcID.replacingOccurrences(of: "-", with: "_")
    }

    var body: some View {
        // 资产存在就用真头像；缺失（含约定名未提供图）稳妥回退姓氏字，绝不空白。
        if let ui = UIImage(named: assetName) {
            Image(uiImage: ui)
                .resizable()
                .scaledToFill()
                .frame(width: size, height: size)
                .clipShape(Circle())
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
        } else {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [base.opacity(0.82), base],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .overlay(
                    Text(RainmakerUI.monogram(for: npcID))
                        .font(.system(size: size * 0.42, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                )
                .overlay(Circle().stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }
}

/// WhatsApp 蓝色已读双勾 ✓✓（气泡与列表预览共用）。
struct WADoubleTick: View {
    /// 默认走品牌色；置于发出气泡（靛紫底）上时传白色。
    var tint: Color = WA.accent

    var body: some View {
        HStack(spacing: -5) {
            Image(systemName: "checkmark")
            Image(systemName: "checkmark")
        }
        .font(.caption2.weight(.bold))
        .foregroundStyle(tint)
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
                 label: "尽调工时", value: "\(state.ap)/\(RainmakerBalance.apPerDay)")
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
                    .font(.caption2)
                    .foregroundStyle(tint)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(WA.textSecondary)
            }
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(WA.textPrimary)
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}
