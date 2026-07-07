import SwiftUI

/// Journey Pass 购买页（微信风）。诚实变现：一次性买断、无倒计时、无 dark pattern。
/// 购买失败 / 未联网静默降级，绝不打断——2048 免费部分始终可玩。
struct JourneyPassView: View {
    let passStore: JourneyPassStore
    @Environment(\.dismiss) private var dismiss

    @State private var message: String?
    @State private var busy = false

    var body: some View {
        ZStack {
            Shell.page.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button("以后再说") { dismiss() }
                        .buttonStyle(WeChatTextButtonStyle(color: Shell.textSecondary))
                }
                .padding(.top, 4)

                Spacer(minLength: 0)

                Text("Journey Pass")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Shell.textPrimary)
                Text("永久解锁 Session 模式")
                    .font(.system(size: 15))
                    .foregroundStyle(Shell.textSecondary)
                    .padding(.top, 8)

                VStack(spacing: 0) {
                    benefitRow("仪式容器", "有始有终的断网时段", first: true)
                    benefitRow("安静环境", "无红点、无 badge、无诱导")
                    benefitRow("落地收尾", "本次时间的本地统计")
                }
                .background(Shell.card, in: RoundedRectangle(cornerRadius: Shell.cardRadius))
                .padding(.top, 28)

                Text("一次买断，永久解锁。2048 本体始终免费。")
                    .font(.system(size: 13))
                    .foregroundStyle(Shell.textSecondary)
                    .padding(.top, 16)

                Spacer(minLength: 40)

                Button { Task { await buy() } } label: {
                    Text(purchaseLabel)
                }
                .buttonStyle(WeChatPrimaryButtonStyle(enabled: !busy))
                .disabled(busy)

                Button("恢复购买") { Task { await restore() } }
                    .buttonStyle(WeChatTextButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)

                if let message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(Shell.textSecondary)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .frame(maxWidth: 480)
        }
        .task { await load() }
        .onChange(of: passStore.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private func benefitRow(_ title: String, _ subtitle: String, first: Bool = false) -> some View {
        VStack(spacing: 0) {
            if !first {
                Rectangle().fill(Shell.separator).frame(height: 0.5)
                    .padding(.leading, 16)
            }
            HStack(spacing: 12) {
                Image(systemName: "checkmark")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Shell.accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundStyle(Shell.textPrimary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundStyle(Shell.textSecondary)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }

    private var purchaseLabel: String {
        if let price = passStore.product?.displayPrice { return "\(price) 解锁" }
        return "解锁"
    }

    private func load() async {
        do { try await passStore.loadProduct() }
        catch { message = "需要联网完成购买" } // 静默降级
    }

    private func buy() async {
        busy = true; defer { busy = false }
        do { try await passStore.purchase() }
        catch JourneyPassStore.PurchaseError.userCancelled { /* 静默 */ }
        catch JourneyPassStore.PurchaseError.pending { message = "购买待确认" }
        catch { message = "需要联网完成购买" }
    }

    private func restore() async {
        do { try await passStore.restore() }
        catch { message = "恢复失败，请检查网络" }
    }
}
