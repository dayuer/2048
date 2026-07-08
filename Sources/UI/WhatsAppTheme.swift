import SwiftUI

/// 全 app「WhatsApp iOS」设计系统复刻：绿主行动、大标题列表 + 圆形头像、
/// 米色涂鸦聊天画布、带尾巴的气泡。所有 token 深浅色自适应。
/// 涂鸦与图标全自绘/SF Symbols，不含任何 WhatsApp 版权素材。
enum WA {
    /// 主行动绿（浅 #1DAB61 / 深 #21C063）：按钮、选中 tab、开关。
    static let accent = adaptive(light: 0x1DAB61, dark: 0x21C063)
    /// 聊天画布（浅米 / 近黑）。
    static let chatCanvas = adaptive(light: 0xEFEAE2, dark: 0x0B141A)
    /// 自绘涂鸦纹理色（画布上极淡可辨）。
    static let doodle = adaptive(light: 0xC5BCAD, dark: 0x233138)
    /// 发出气泡。
    static let bubbleOut = adaptive(light: 0xD9FDD3, dark: 0x005C4B)
    /// 收到气泡 / 中置系统卡。
    static let bubbleIn = adaptive(light: 0xFFFFFF, dark: 0x202C33)
    /// 列表页底。
    static let listBg = adaptive(light: 0xFFFFFF, dark: 0x111B21)
    /// 主文字。
    static let textPrimary = adaptive(light: 0x111B21, dark: 0xE9EDEF)
    /// 次要文字 / 时间戳。
    static let textSecondary = adaptive(light: 0x667781, dark: 0x8696A0)
    /// 发丝分隔线。
    static let separator = adaptive(light: 0xE9EDEF, dark: 0x222D34)
    /// 默认头像底（灰圆 + 白剪影，WhatsApp 默认头像形态）。
    static let avatarBg = adaptive(light: 0xDFE5E7, dark: 0x6A7175)

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

/// 主行动按钮：绿整宽 pill + 白字。按压压暗并微缩（WhatsApp 大 CTA 形态）。
struct WAPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(WA.accent, in: Capsule())
            .opacity(configuration.isPressed ? 0.8 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 文字链接按钮：绿文字，按压压暗。
struct WATextButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 17))
            .foregroundStyle(WA.accent)
            .opacity(configuration.isPressed ? 0.5 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// 圆形头像：WhatsApp 默认头像形态（灰底白剪影）；AI 线程传绿底 cpu 图标。
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

/// 聊天画布：米色底 + 自绘涂鸦平铺（SeededGenerator 定种子，布局确定）。
/// 对应 WhatsApp 的标志性墙纸观感；图案全部 SF Symbols 自绘，无版权素材。
struct WADoodleWallpaper: View {
    private static let symbols = [
        "gamecontroller", "dice", "puzzlepiece", "star", "airplane",
        "message", "bolt", "moon.stars", "sparkles", "heart",
    ]

    var body: some View {
        WA.chatCanvas
            .overlay(
                Canvas { context, size in
                    var rng = SeededGenerator(seed: 2048)
                    let cell: CGFloat = 64
                    let cols = Int(size.width / cell) + 2
                    let rows = Int(size.height / cell) + 2
                    for row in 0..<rows {
                        for col in 0..<cols {
                            let symbol = Self.symbols[Int(rng.next() % UInt64(Self.symbols.count))]
                            let jitterX = CGFloat(rng.next() % 24) - 12
                            let jitterY = CGFloat(rng.next() % 24) - 12
                            // 奇数行错半格，接近手绘平铺的错落感
                            let offsetX = (row % 2 == 0) ? 0 : cell / 2
                            let point = CGPoint(
                                x: CGFloat(col) * cell + offsetX + jitterX,
                                y: CGFloat(row) * cell + jitterY
                            )
                            let resolved = context.resolve(
                                Image(systemName: symbol)
                                    .renderingMode(.template)
                            )
                            context.draw(
                                resolved,
                                in: CGRect(x: point.x, y: point.y, width: 20, height: 20)
                            )
                        }
                    }
                }
                .foregroundStyle(WA.doodle)
                .opacity(0.5)
            )
            .ignoresSafeArea()
    }
}

/// WhatsApp 气泡：圆角 8 + 顶部外侧小尾巴（原版第一条消息的尾巴位置）。
struct BubbleShape: Shape {
    let mine: Bool
    private let radius: CGFloat = 8
    private let tail: CGFloat = 6

    func path(in rect: CGRect) -> Path {
        var path = Path()
        // 气泡主体：水平方向给尾巴让出 tail 宽度
        let body = mine
            ? CGRect(x: rect.minX, y: rect.minY, width: rect.width - tail, height: rect.height)
            : CGRect(x: rect.minX + tail, y: rect.minY, width: rect.width - tail, height: rect.height)
        path.addRoundedRect(in: body, cornerSize: CGSize(width: radius, height: radius))

        // 顶部外侧尾巴：从主体顶角伸出的小三角（带一点弧度的观感靠小尺寸即可）
        var tailPath = Path()
        if mine {
            tailPath.move(to: CGPoint(x: body.maxX - radius, y: rect.minY))
            tailPath.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
            tailPath.addLine(to: CGPoint(x: body.maxX, y: rect.minY + radius + 2))
        } else {
            tailPath.move(to: CGPoint(x: body.minX + radius, y: rect.minY))
            tailPath.addLine(to: CGPoint(x: rect.minX, y: rect.minY))
            tailPath.addLine(to: CGPoint(x: body.minX, y: rect.minY + radius + 2))
        }
        tailPath.closeSubpath()
        path.addPath(tailPath)
        return path
    }
}
