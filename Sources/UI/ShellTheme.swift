import SwiftUI

/// Session 外壳的「微信风」设计系统：浅灰页底、白卡片、发丝分隔线、微信绿主行动、系统字体。
/// 深度只用背景层级（灰页 vs 白卡）与极细分隔线表达，绝不用阴影或重描边。
enum Shell {
    /// 页底浅灰。
    static let page = Color(hex: 0xEDEDED)
    /// 白卡片 / 列表行底。
    static let card = Color(hex: 0xFFFFFF)
    /// 发丝分隔线。
    static let separator = Color(hex: 0xE5E5E5)
    /// 行按压高亮。
    static let rowPressed = Color(hex: 0xD9D9D9)
    /// 主文字（近黑）。
    static let textPrimary = Color(hex: 0x191919)
    /// 次要灰。
    static let textSecondary = Color(hex: 0x888888)
    /// 微信绿——只用于主行动。
    static let accent = Color(hex: 0x07C160)
    /// 微信绿按压态。
    static let accentPressed = Color(hex: 0x06AD56)

    static let radius: CGFloat = 8
    static let cardRadius: CGFloat = 10
}

/// 主行动按钮：微信绿填充 + 白字，圆角矩形、整宽。按压变深、轻微压暗，无弹跳。
struct WeChatPrimaryButtonStyle: ButtonStyle {
    var enabled: Bool = true
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                configuration.isPressed ? Shell.accentPressed : Shell.accent,
                in: RoundedRectangle(cornerRadius: Shell.radius)
            )
            .opacity(enabled ? 1 : 0.5)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 文字链接按钮：微信绿或灰，用于次级动作。按压压暗。
struct WeChatTextButtonStyle: ButtonStyle {
    var color: Color = Shell.accent
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16))
            .foregroundStyle(color)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
