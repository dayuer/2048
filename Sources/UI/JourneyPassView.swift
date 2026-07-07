import SwiftUI

/// Journey Pass 购买页。诚实变现：一次性买断、无倒计时、无 dark pattern。
/// 购买失败 / 未联网静默降级，绝不打断——2048 免费部分始终可玩。
struct JourneyPassView: View {
    let passStore: JourneyPassStore
    @Environment(\.dismiss) private var dismiss

    @State private var message: String?
    @State private var busy = false

    var body: some View {
        ZStack {
            Shell.ground.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer(minLength: 0)

                Text("JOURNEY PASS")
                    .shellMonoLabel()

                Text("解锁\nSession 模式")
                    .font(.shellDisplay(40))
                    .foregroundStyle(Shell.ink)
                    .padding(.top, 12)

                Rectangle()
                    .fill(Shell.accent)
                    .frame(width: 40, height: 2)
                    .padding(.top, 22)

                VStack(alignment: .leading, spacing: 14) {
                    benefit("仪式容器：有始有终的断网时段")
                    benefit("安静环境：无红点、无 badge、无诱导")
                    benefit("落地收尾：本次时间的本地统计")
                }
                .padding(.top, 28)

                Text("一次买断，永久解锁。2048 本体始终免费。")
                    .font(.system(size: 13))
                    .foregroundStyle(Shell.mutedInk)
                    .padding(.top, 24)

                Spacer(minLength: 40)

                Button { Task { await buy() } } label: {
                    Text(purchaseLabel)
                }
                .buttonStyle(ShellPrimaryButtonStyle())
                .disabled(busy)
                .opacity(busy ? 0.6 : 1)

                Button("恢复购买") { Task { await restore() } }
                    .buttonStyle(ShellGhostButtonStyle())
                    .frame(maxWidth: .infinity)
                    .padding(.top, 16)

                if let message {
                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(Shell.mutedInk)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                        .padding(.top, 12)
                }

                Spacer(minLength: 0)

                Button("以后再说") { dismiss() }
                    .buttonStyle(ShellGhostButtonStyle())
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
            .frame(maxWidth: 480)
        }
        .task { await load() }
        .onChange(of: passStore.isUnlocked) { _, unlocked in
            if unlocked { dismiss() }
        }
    }

    private func benefit(_ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Circle().fill(Shell.mutedInk).frame(width: 4, height: 4)
                .offset(y: -3)
            Text(text)
                .font(.system(size: 15))
                .foregroundStyle(Shell.ink)
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
