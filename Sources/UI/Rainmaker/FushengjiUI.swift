import SwiftUI

/// 浮生记线 UI：贩子交易面板 / 村长债务面板 / 跑市场选择器。
/// 全部挂在聊天详情或消息页上——交易过程 100% 长在 IM 里。

// MARK: - 贩子交易面板（挂在贩子线程 composer 上方）

struct TradingPanel: View {
    @Bindable var store: RainmakerStore
    let dealerID: String
    @State private var selectedAssetID: String?
    @State private var quantity = 1

    private var venue: TradeVenue? { TradeCatalog.venueOfDealer(dealerID) }
    private var isHere: Bool { venue?.id == store.state.currentVenueID }

    var body: some View {
        VStack(spacing: 8) {
            if let venue, isHere {
                header(venue)
                quoteRows
                if let assetID = selectedAssetID,
                   let price = store.state.assetPrices?[assetID] {
                    tradeControls(assetID: assetID, price: price)
                }
            } else if let venue {
                Text("\(NPCCatalog.profile(id: dealerID)?.name ?? "贩子")在\(venue.name)驻场——先「跑市场」过去才能交易。")
                    .font(.footnote)
                    .foregroundStyle(WA.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.thinMaterial)
    }

    private func header(_ venue: TradeVenue) -> some View {
        HStack {
            Label("\(venue.name) · 今日行情", systemImage: "chart.bar.doc.horizontal")
                .font(.caption.weight(.semibold))
                .foregroundStyle(WA.textSecondary)
            Spacer()
            Text("现金 \(store.state.cash) 万 · 仓位 \(store.state.usedCapacity)/\(store.state.currentCapacity)")
                .font(.caption2)
                .foregroundStyle(WA.textSecondary)
                .monospacedDigit()
        }
    }

    /// 今日报价行：有货的资产（缺货 3 种是常态，原版 leaveout 语义）。
    private var quoteRows: some View {
        VStack(spacing: 4) {
            ForEach(TradeCatalog.assets) { asset in
                if let price = store.state.assetPrices?[asset.id] {
                    quoteRow(asset: asset, price: price)
                }
            }
        }
    }

    private func quoteRow(asset: TradeAsset, price: Int) -> some View {
        let owned = store.state.currentHoldings[asset.id] ?? 0
        let selected = selectedAssetID == asset.id
        return Button {
            selectedAssetID = selected ? nil : asset.id
            quantity = 1
        } label: {
            HStack(spacing: 6) {
                Text(asset.name)
                    .font(.footnote.weight(selected ? .semibold : .regular))
                    .foregroundStyle(WA.textPrimary)
                if asset.isGrey {
                    Text("灰")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.orange)
                }
                Spacer()
                if owned > 0 {
                    Text("持 \(owned)")
                        .font(.caption2)
                        .foregroundStyle(WA.accent)
                        .monospacedDigit()
                }
                Text("\(price) 万")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(WA.textPrimary)
                    .monospacedDigit()
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                selected ? WA.accent.opacity(0.12) : WA.bubbleIn.opacity(0.6),
                in: RoundedRectangle(cornerRadius: 8)
            )
        }
        .buttonStyle(.plain)
    }

    /// 买卖控制：数量步进 + 全力买入/清仓卖出。
    private func tradeControls(assetID: String, price: Int) -> some View {
        let owned = store.state.currentHoldings[assetID] ?? 0
        let space = store.state.currentCapacity - store.state.usedCapacity
        let maxBuy = min(space, price > 0 ? store.state.cash / price : 0)
        return VStack(spacing: 6) {
            HStack {
                Stepper("数量 \(quantity)", value: $quantity, in: 1...max(1, max(maxBuy, owned)))
                    .font(.footnote)
            }
            HStack(spacing: 8) {
                Button("买入 \(quantity) 手（\(price * quantity) 万）") {
                    store.buy(assetID: assetID, quantity: quantity)
                    quantity = 1
                }
                .buttonStyle(.borderedProminent)
                .tint(WA.accent)
                .font(.footnote.weight(.semibold))
                .disabled(quantity > maxBuy)

                Button("卖出 \(min(quantity, owned)) 手") {
                    store.sell(assetID: assetID, quantity: min(quantity, owned))
                    quantity = 1
                }
                .buttonStyle(.bordered)
                .font(.footnote.weight(.semibold))
                .disabled(owned == 0)
            }
            HStack(spacing: 8) {
                Button("梭哈（\(maxBuy) 手）") {
                    store.buy(assetID: assetID, quantity: maxBuy)
                }
                .font(.caption)
                .disabled(maxBuy == 0)
                Button("清仓（\(owned) 手）") {
                    store.sell(assetID: assetID, quantity: owned)
                }
                .font(.caption)
                .disabled(owned == 0)
                Spacer()
            }
        }
    }
}

// MARK: - 村长债务面板（挂在村长线程 composer 上方）

struct DebtPanel: View {
    @Bindable var store: RainmakerStore

    private var debt: Int { store.state.currentDebt }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("欠村长 \(debt) 万", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(debt > 0 ? .red : WA.accent)
                    .monospacedDigit()
                Spacer()
                Text("日息一成 · 第 \(store.state.day)/\(RainmakerBalance.deadlineDay) 天")
                    .font(.caption2)
                    .foregroundStyle(WA.textSecondary)
            }
            if debt > 0 {
                HStack(spacing: 8) {
                    Button("还 1000 万") { store.repayDebt(amount: 1000) }
                        .buttonStyle(.bordered)
                        .font(.footnote.weight(.semibold))
                        .disabled(store.state.cash < 1)
                    Button("还一半") { store.repayDebt(amount: (debt + 1) / 2) }
                        .buttonStyle(.bordered)
                        .font(.footnote.weight(.semibold))
                        .disabled(store.state.cash < 1)
                    Button("全力还款") { store.repayDebt(amount: debt) }
                        .buttonStyle(.borderedProminent)
                        .tint(WA.accent)
                        .font(.footnote.weight(.semibold))
                        .disabled(store.state.cash < 1)
                }
            } else {
                Text("账清了。村里人都念你的好。")
                    .font(.footnote)
                    .foregroundStyle(WA.accent)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.thinMaterial)
    }
}

// MARK: - 跑市场（移动 = 过一天）

struct TravelSheet: View {
    @Bindable var store: RainmakerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(TradeCatalog.venues) { venue in
                let isHere = venue.id == store.state.currentVenueID
                Button {
                    guard !isHere else { return }
                    store.travel(to: venue.id)
                    dismiss()
                } label: {
                    HStack(spacing: 12) {
                        WAAvatar(systemImage: venue.icon, background: RainmakerUI.tint(for: venue.id), size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(venue.name)
                                .font(.body.weight(isHere ? .semibold : .regular))
                                .foregroundStyle(WA.textPrimary)
                            Text(NPCCatalog.profile(id: venue.dealerID).map { "\($0.name) · \($0.role)" } ?? "")
                                .font(.footnote)
                                .foregroundStyle(WA.textSecondary)
                        }
                        Spacer()
                        if isHere {
                            Text("当前")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(WA.accent)
                        }
                    }
                }
                .listRowSeparatorTint(WA.separator)
            }
            .listStyle(.plain)
            .navigationTitle("跑市场（奔走一地 = 一天）")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("取消") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
