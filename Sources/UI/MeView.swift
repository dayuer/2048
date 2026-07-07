import SwiftUI

/// 我 tab：ephemeral 昵称（可重掷）+ 隐私自述 + 设置（清空线程）。
struct MeView: View {
    let identity: EphemeralIdentity
    let chat: ChatStore

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(Shell.accent)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(identity.nickname)
                                .font(.system(size: 18, weight: .medium))
                                .foregroundStyle(Shell.textPrimary)
                            Text("本机临时身份")
                                .font(.system(size: 13))
                                .foregroundStyle(Shell.textSecondary)
                        }
                        Spacer()
                        Button("重掷") { identity.reroll() }
                            .buttonStyle(WeChatTextButtonStyle())
                    }
                    .listRowBackground(Shell.card)
                }

                Section("隐私") {
                    Label("无服务器、无账号", systemImage: "lock.shield")
                    Label("数据不出设备", systemImage: "iphone")
                    Label("线程本地删除即彻底消失", systemImage: "trash")
                }
                .foregroundStyle(Shell.textPrimary)
                .listRowBackground(Shell.card)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Shell.page)
            .navigationTitle("我")
        }
    }
}
