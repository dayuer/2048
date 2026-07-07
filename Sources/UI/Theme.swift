import SwiftUI

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: alpha
        )
    }
}

/// 原版 style/main.css 的调色板。
enum Theme {
    static let background = Color(hex: 0xFAF8EF)
    static let board = Color(hex: 0xBBADA0)
    static let emptyCell = Color(hex: 0xEEE4DA, alpha: 0.35)
    static let text = Color(hex: 0x776E65)
    static let lightText = Color(hex: 0xF9F6F2)
    static let button = Color(hex: 0x8F7A66)
    static let scoreBox = Color(hex: 0xBBADA0)
    static let scoreLabel = Color(hex: 0xEEE4DA)
    static let winOverlay = Color(hex: 0xEDC22E, alpha: 0.5)
    static let loseOverlay = Color(hex: 0xEEE4DA, alpha: 0.73)

    static func tileColor(_ value: Int) -> Color {
        switch value {
        case 2: Color(hex: 0xEEE4DA)
        case 4: Color(hex: 0xEDE0C8)
        case 8: Color(hex: 0xF2B179)
        case 16: Color(hex: 0xF59563)
        case 32: Color(hex: 0xF67C5F)
        case 64: Color(hex: 0xF65E3B)
        case 128: Color(hex: 0xEDCF72)
        case 256: Color(hex: 0xEDCC61)
        case 512: Color(hex: 0xEDC850)
        case 1024: Color(hex: 0xEDC53F)
        case 2048: Color(hex: 0xEDC22E)
        default: Color(hex: 0x3C3A32)
        }
    }

    static func tileTextColor(_ value: Int) -> Color {
        value <= 4 ? text : lightText
    }
}
