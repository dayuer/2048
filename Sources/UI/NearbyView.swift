import SwiftUI

/// 附近 tab：B（蓝牙发现）落地前的引导态。隐私友好文案 + 不可用的「可被发现」开关。
struct NearbyView: View {
    @State private var discoverable = false   // 引导态：视觉可切换但不接任何无线电

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Image(systemName: "dot.radiowaves.left.and.right")
                    .font(.system(size: 52))
                    .foregroundStyle(Shell.accent)
                Text("发现身边的人")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Shell.textPrimary)
                Text("等你身边也有人在用这个 app 时，可以直接连上来一局——全程设备到设备，无服务器、无账号。即将开放。")
                    .font(.system(size: 14))
                    .foregroundStyle(Shell.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                Toggle("可被附近发现", isOn: $discoverable)
                    .disabled(true)
                    .padding(.horizontal, 40)
                    .tint(Shell.accent)
                Text("即将到来")
                    .font(.system(size: 12))
                    .foregroundStyle(Shell.textSecondary)
                Spacer()
            }
            .padding(.top, 60)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Shell.page)
            .navigationTitle("附近")
        }
    }
}
