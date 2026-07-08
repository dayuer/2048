import SwiftUI

/// 我 tab：WhatsApp Settings 复刻。系统 insetGrouped + 个人行 + 彩色圆角方图标行。
struct MeView: View {
    let identity: EphemeralIdentity
    let chat: ChatStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        WAAvatar(size: 58)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(identity.nickname)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundStyle(WA.textPrimary)
                            Text("本机临时身份")
                                .font(.system(size: 14))
                                .foregroundStyle(WA.textSecondary)
                        }
                        Spacer()
                        Button("重掷") { identity.reroll() }
                            .buttonStyle(WATextButtonStyle())
                    }
                    .padding(.vertical, 4)
                }

                Section("隐私") {
                    settingsRow(icon: "lock.fill", color: WA.accent, text: "无服务器、无账号")
                    settingsRow(icon: "iphone", color: .blue, text: "数据不出设备")
                    settingsRow(icon: "trash.fill", color: .red, text: "线程本地删除即彻底消失")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("我")
        }
    }

    /// WhatsApp/iOS 设置行形态：28pt 彩色圆角方图标 + 文案。
    private func settingsRow(icon: String, color: Color, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 28, height: 28)
                .background(color, in: RoundedRectangle(cornerRadius: 6))
            Text(text)
                .font(.system(size: 17))
                .foregroundStyle(WA.textPrimary)
        }
    }
}
