import SwiftUI

/// Session 外壳的「墨上留白（Ink-on-Void）」设计系统。
/// 与 2048 本体的暖米色调色板刻意区隔：深墨底、暖白墨、单一克制的黄铜点缀。
/// 深度只用背景层级与极细 hairline 表达，绝不给每个容器描边。
enum Shell {
    /// 近黑暖炭底——安静、昂贵、克制。
    static let ground = Color(hex: 0x14130F)
    /// 抬升表面（比 ground 亮约 5%），用背景层级而非描边表达深度。
    static let surface = Color(hex: 0x1F1D17)
    /// 主墨色：暖白，正文与标题。
    static let ink = Color(hex: 0xF2ECE0)
    /// 弱墨：次要文字与 mono 微标签。
    static let mutedInk = Color(hex: 0x8C857A)
    /// 单一点缀：深黄铜。每屏至多出现一次（时间 hairline / 选中下划线）。
    static let accent = Color(hex: 0xC9A227)

    static let radius: CGFloat = 12
}

extension Font {
    /// 展示体：New York 衬线，昂贵的编辑感。
    static func shellDisplay(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }
    /// 微标签：等宽，作「安静的仪表」。配合 uppercase + tracking 使用。
    static var shellLabel: Font { .system(.caption, design: .monospaced) }
}

extension View {
    /// 「安静仪表」微标签：等宽、大写、宽字距、弱墨。
    func shellMonoLabel() -> some View {
        self.font(.shellLabel)
            .textCase(.uppercase)
            .tracking(2.5)
            .foregroundStyle(Shell.mutedInk)
    }
}

/// 主行动按钮：暖白填充 + 深墨字，作为每屏唯一的高对比锚点。按压平稳缩放、无弹跳。
struct ShellPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .medium))
            .foregroundStyle(Shell.ground)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 17)
            .background(Shell.ink, in: RoundedRectangle(cornerRadius: Shell.radius))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 幽灵按钮：纯文字、弱墨，用于次级与「不打扰」的退让动作。
struct ShellGhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .regular))
            .foregroundStyle(Shell.mutedInk)
            .opacity(configuration.isPressed ? 0.55 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}
