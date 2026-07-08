import SwiftUI

/// 《顶级掮客》自有品牌 IM 设计系统。保留即时通讯的通用交互（气泡流/头像列表/
/// 常驻输入条），但视觉与任何现有通讯软件明确区分：品牌靛紫主色、无尾巴不对称
/// 圆角气泡、干净渐变画布、去标志性的已读标记。所有 token 深浅色自适应。
/// 符号名 WA 为历史遗留（= 本作 IM 设计系统），不指向任何第三方产品。
enum WA {
    /// 品牌主色（靛紫）：按钮、选中态、发出气泡。刻意区别于绿/蓝系通讯软件。
    static let accent = adaptive(light: 0x5B54D6, dark: 0x8E88F5)
    /// 聊天画布（冷调浅灰紫 / 靛黑）——非米色涂鸦墙。
    static let chatCanvas = adaptive(light: 0xF3F2F8, dark: 0x0F0D17)
    /// 画布上的极淡纹理色（稀疏菱形，与密集涂鸦墙区分）。
    static let doodle = adaptive(light: 0xDAD7E8, dark: 0x211E33)
    /// 发出气泡（品牌靛紫实底，白字）。
    static let bubbleOut = adaptive(light: 0x5B54D6, dark: 0x4038A0)
    /// 收到气泡 / 系统卡（中性面）。
    static let bubbleIn = adaptive(light: 0xFFFFFF, dark: 0x252233)
    /// 列表页底。
    static let listBg = adaptive(light: 0xFFFFFF, dark: 0x141220)
    /// 主文字。
    static let textPrimary = adaptive(light: 0x141220, dark: 0xECEAF5)
    /// 次要文字 / 时间戳。
    static let textSecondary = adaptive(light: 0x6B6880, dark: 0x9A96AE)
    /// 发丝分隔线。
    static let separator = adaptive(light: 0xECEAF3, dark: 0x262233)
    /// 默认头像底（灰圆 + 白剪影）。
    static let avatarBg = adaptive(light: 0xDFE0E7, dark: 0x6A6A75)

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(hex: dark) : UIColor(hex: light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// 主行动按钮：品牌靛紫整宽 pill + 白字。按压压暗并微缩。
struct WAPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(WA.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 文字链接按钮：品牌色文字，按压压暗。
struct WATextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundStyle(WA.accent)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 圆形头像：默认灰底白剪影；具体 NPC 走 NPCAvatar（真图/姓氏字）。
struct WAAvatar: View {
    var systemImage: String = "person.fill"
    var background: Color = WA.avatarBg
    var size: CGFloat = 52

    var body: some View {
        Circle()
            .fill(background)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: systemImage)
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(.white)
            )
    }
}

/// 聊天画布：冷调渐变底 + 极稀疏菱形纹理（SeededGenerator 定种子，布局确定）。
/// 刻意区别于「米色 + 密集涂鸦」的既有通讯软件墙纸——大间距、低透明、单一几何。
struct WADoodleWallpaper: View {
    var body: some View {
        LinearGradient(
            colors: [WA.chatCanvas, WA.chatCanvas.opacity(0.92)],
            startPoint: .top, endPoint: .bottom
        )
        .overlay(
            Canvas { context, size in
                var rng = SeededGenerator(seed: 2048)
                let cell: CGFloat = 118            // 大间距，稀疏
                let cols = Int(size.width / cell) + 2
                let rows = Int(size.height / cell) + 2
                for row in 0..<rows {
                    for col in 0..<cols {
                        let jitterX = CGFloat(rng.next() % 30) - 15
                        let jitterY = CGFloat(rng.next() % 30) - 15
                        let offsetX = (row % 2 == 0) ? 0 : cell / 2
                        let point = CGPoint(
                            x: CGFloat(col) * cell + offsetX + jitterX,
                            y: CGFloat(row) * cell + jitterY
                        )
                        let resolved = context.resolve(
                            Image(systemName: "suit.diamond")
                                .renderingMode(.template)
                        )
                        context.draw(resolved, in: CGRect(x: point.x, y: point.y, width: 16, height: 16))
                    }
                }
            }
            .foregroundStyle(WA.doodle)
            .opacity(0.35)
        )
        .ignoresSafeArea()
    }
}

/// 品牌气泡：无尾巴、四角大圆角，仅「己方右下 / 对方左下」收紧一角作方向暗示。
/// 明确区别于带尾巴的既有通讯软件气泡。
struct BubbleShape: Shape {
    let mine: Bool
    private let radius: CGFloat = 17
    private let tight: CGFloat = 5

    func path(in rect: CGRect) -> Path {
        UnevenRoundedRectangle(
            topLeadingRadius: radius,
            bottomLeadingRadius: mine ? radius : tight,
            bottomTrailingRadius: mine ? tight : radius,
            topTrailingRadius: radius
        ).path(in: rect)
    }
}
