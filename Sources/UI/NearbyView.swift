import SwiftUI

/// 附近 tab：B（蓝牙发现）落地前的引导态。WhatsApp 空态形态：
/// 大灰圆图标 + 标题 + 说明 + 绿 accent 开关（禁用）。
struct NearbyView: View {
    @State private var discoverable = false   // 引导态：不接任何无线电

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                WAAvatar(systemImage: "dot.radiowaves.left.and.right", size: 96)
                Text("发现身边的人")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(WA.textPrimary)
                Text("等你身边也有人在用这个 app 时，可以直接连上来一局——全程设备到设备，无服务器、无账号。即将开放。")
                    .font(.system(size: 15))
                    .foregroundStyle(WA.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)
                Toggle("可被附近发现", isOn: $discoverable)
                    .disabled(true)
                    .padding(.horizontal, 44)
                    .tint(WA.accent)
                Text("即将到来")
                    .font(.system(size: 13))
                    .foregroundStyle(WA.textSecondary)
                Spacer()
            }
            .padding(.top, 48)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(WA.listBg)
            .navigationTitle("附近")
        }
    }
}
