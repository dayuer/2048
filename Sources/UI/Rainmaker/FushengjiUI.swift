import SwiftUI

/// 浮生记线 UI：贩子交易面板 / 村长债务面板 / 跑市场选择器。
/// 全部挂在聊天详情或消息页上——交易过程 100% 长在 IM 里。

// MARK: - 贩子交易面板（挂在贩子线程 composer 上方）

struct TradingPanel: View {
    @Bindable var store: RainmakerStore
    let dealerID: String
    /// 点开的交易单（股票式：一次只处理一只，明确确认，杜绝误触）。
    @State private var ticketAssetID: String?

    private var venue: TradeVenue? { TradeCatalog.venueOfDealer(dealerID) }
    private var isHere: Bool { venue?.id == store.state.currentVenueID }

    var body: some View {
        VStack(spacing: 8) {
            if let venue, isHere {
                header(venue)
                quoteBoard
            } else if let venue {
                Text("\(NPCCatalog.profile(id: dealerID)?.name ?? "贩子")在\(venue.name)驻场——先「跑市场」过去才能交易。")
                    .font(.footnote)
                    .foregroundStyle(WA.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(12)
        .background(.thinMaterial)
        .sheet(item: Binding(
            get: { ticketAssetID.map(TradeTicketID.init) },
            set: { ticketAssetID = $0?.id }
        )) { ticket in
            TradeTicketSheet(store: store, assetID: ticket.id)
                .presentationDetents([.medium])
        }
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

    /// 只读报价板：点一行开交易单（不在这里直接成交，避免误触）。
    private var quoteBoard: some View {
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
        return Button {
            ticketAssetID = asset.id
        } label: {
            HStack(spacing: 6) {
                Text(asset.name)
                    .font(.footnote)
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
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(WA.textSecondary)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(WA.bubbleIn.opacity(0.6), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

/// sheet(item:) 需要 Identifiable 包装。
private struct TradeTicketID: Identifiable {
    let id: String
}

/// 股票交易式下单单：买/卖分档、数量可调、实时总额、单一确认——防误操作。
struct TradeTicketSheet: View {
    @Bindable var store: RainmakerStore
    let assetID: String
    @Environment(\.dismiss) private var dismiss

    private enum Side { case buy, sell }
    @State private var side: Side = .buy
    @State private var qty = 1

    private var asset: TradeAsset? { TradeCatalog.asset(id: assetID) }
    private var price: Int { store.state.assetPrices?[assetID] ?? 0 }
    private var owned: Int { store.state.currentHoldings[assetID] ?? 0 }
    private var space: Int { store.state.currentCapacity - store.state.usedCapacity }
    private var maxBuy: Int { price > 0 ? min(space, store.state.cash / price) : 0 }
    private var maxForSide: Int { side == .buy ? maxBuy : owned }
    private var total: Int { price * min(qty, max(maxForSide, 0)) }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                priceHeader
                Picker("方向", selection: $side) {
                    Text("买入").tag(Side.buy)
                    Text("卖出").tag(Side.sell)
                }
                .pickerStyle(.segmented)
                .onChange(of: side) { qty = 1 }

                quantityRow
                totalRow

                if asset?.isGrey == true, side == .buy {
                    Label("涉灰资产：卖出会掉信誉，还可能被「查水表」没收。", systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Spacer(minLength: 0)
                confirmButton
            }
            .padding(20)
            .navigationTitle(asset?.name ?? "交易")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private var priceHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("现价").font(.caption).foregroundStyle(WA.textSecondary)
                Text("\(price) 万/手").font(.title3.weight(.bold)).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("现金 \(store.state.cash) 万").font(.caption).foregroundStyle(WA.textSecondary)
                Text("持仓 \(owned) 手 · 空位 \(space)").font(.caption).foregroundStyle(WA.textSecondary)
            }
            .monospacedDigit()
        }
    }

    private var quantityRow: some View {
        HStack(spacing: 12) {
            Text("数量").font(.subheadline).foregroundStyle(WA.textSecondary)
            Stepper(value: $qty, in: 1...max(1, maxForSide)) {
                Text("\(min(qty, max(maxForSide, 0))) 手")
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
            }
            .disabled(maxForSide < 1)
            Button(side == .buy ? "可买 \(maxBuy)" : "全部 \(owned)") {
                qty = max(1, maxForSide)
            }
            .font(.caption.weight(.semibold))
            .buttonStyle(.bordered)
            .disabled(maxForSide < 1)
        }
    }

    private var totalRow: some View {
        HStack {
            Text(side == .buy ? "预计花费" : "预计得款")
                .font(.subheadline).foregroundStyle(WA.textSecondary)
            Spacer()
            Text("\(total) 万")
                .font(.title3.weight(.bold))
                .foregroundStyle(side == .buy ? .red : WA.accent)
                .monospacedDigit()
        }
    }

    private var confirmButton: some View {
        let n = min(qty, max(maxForSide, 0))
        let canTrade = n >= 1
        return Button {
            if side == .buy { store.buy(assetID: assetID, quantity: n) }
            else { store.sell(assetID: assetID, quantity: n) }
            dismiss()
        } label: {
            Text(side == .buy ? "确认买入 \(n) 手 · -\(total) 万" : "确认卖出 \(n) 手 · +\(total) 万")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .tint(side == .buy ? WA.accent : .orange)
        .disabled(!canTrade)
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
