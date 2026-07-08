import SwiftUI

/// 浮生记线 UI：贩子交易面板 / 资方债务面板 / 跑市场选择器。
/// 军规「看不出是游戏」：面板不常驻聊天页，全部藏在 composer 的「+」附件入口后面。

// MARK: - 「+」附件 sheet：行情（贩子线程）

struct MarketSheet: View {
    @Bindable var store: RainmakerStore
    let dealerID: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                TradingPanel(store: store, dealerID: dealerID)
                    .padding(.vertical, 8)
            }
            .background(WA.listBg)
            .navigationTitle("今日行情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - 银行存取（按金额，带「存后现金剩余」提示，杜绝一键全存爆现金流）

struct BankSheet: View {
    @Bindable var store: RainmakerStore
    @Environment(\.dismiss) private var dismiss

    private enum Side { case deposit, withdraw }
    @State private var side: Side = .deposit
    @State private var amount = 0

    private var cash: Int { store.state.cash }
    private var saved: Int { store.state.currentBankDeposit }
    private var maxAmount: Int { side == .deposit ? cash : saved }
    private var clamped: Int { min(max(0, amount), maxAmount) }
    /// 操作后现金——存款会减现金，取款会加现金。让玩家看清现金流后果。
    private var cashAfter: Int { side == .deposit ? cash - clamped : cash + clamped }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("现金").font(.caption).foregroundStyle(WA.textSecondary)
                        Text("\(cash) 万").font(.title3.weight(.bold)).monospacedDigit()
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 2) {
                        Text("银行存款 · 日息 1%").font(.caption).foregroundStyle(WA.textSecondary)
                        Text("\(saved) 万").font(.title3.weight(.bold)).monospacedDigit()
                    }
                }

                Picker("方向", selection: $side) {
                    Text("存入").tag(Side.deposit)
                    Text("取出").tag(Side.withdraw)
                }
                .pickerStyle(.segmented)
                .onChange(of: side) { amount = 0 }

                // 快捷金额：按上限裁剪，避免手滑全存
                HStack(spacing: 8) {
                    ForEach([100, 500, 1000], id: \.self) { chip in
                        Button("\(chip)") { amount = min(chip, maxAmount) }
                            .buttonStyle(.bordered)
                            .font(.footnote.weight(.semibold))
                            .disabled(chip > maxAmount)
                    }
                    Button("一半") { amount = maxAmount / 2 }
                        .buttonStyle(.bordered).font(.footnote.weight(.semibold))
                        .disabled(maxAmount < 2)
                    Button("全部") { amount = maxAmount }
                        .buttonStyle(.bordered).font(.footnote.weight(.semibold))
                        .disabled(maxAmount <= 0)
                }

                Stepper(value: $amount, in: 0...max(0, maxAmount), step: 50) {
                    Text("金额 \(clamped) 万").font(.body.weight(.semibold)).monospacedDigit()
                }
                .disabled(maxAmount <= 0)

                // 现金流后果提示——存太多会红字警告
                HStack {
                    Text("操作后现金")
                        .font(.subheadline).foregroundStyle(WA.textSecondary)
                    Spacer()
                    Text("\(cashAfter) 万")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(cashAfter < RainmakerBalance.burnRate ? .red : WA.textPrimary)
                        .monospacedDigit()
                }
                if side == .deposit, cashAfter < RainmakerBalance.burnRate {
                    Label("现金将不够明日固定开销 \(RainmakerBalance.burnRate) 万，当心断流破产。",
                          systemImage: "exclamationmark.triangle")
                        .font(.caption).foregroundStyle(.red)
                }

                Spacer(minLength: 0)

                Button {
                    if side == .deposit { store.deposit(amount: clamped) }
                    else { store.withdraw(amount: clamped) }
                    dismiss()
                } label: {
                    Text(side == .deposit ? "存入 \(clamped) 万" : "取出 \(clamped) 万")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
                .tint(WA.accent)
                .disabled(clamped < 1)
            }
            .padding(20)
            .navigationTitle("银行")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { Button("关闭") { dismiss() } }
            }
        }
    }
}

// MARK: - 「+」附件 sheet：还款（资方线程）

struct RepaySheet: View {
    @Bindable var store: RainmakerStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack {
                DebtPanel(store: store)
                    .padding(.top, 8)
                Spacer(minLength: 0)
            }
            .background(WA.listBg)
            .navigationTitle("回购还款")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }
}

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

// MARK: - 资方债务面板（挂在沈墨线程 composer 上方）

struct DebtPanel: View {
    @Bindable var store: RainmakerStore

    private var debt: Int { store.state.currentDebt }

    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Label("回购余额 \(debt) 万", systemImage: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(debt > 0 ? .red : WA.accent)
                    .monospacedDigit()
                Spacer()
                Text("日罚息一成 · 第 \(store.state.day)/\(RainmakerBalance.deadlineDay) 天")
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
                Text("回购完毕。圈子很小，你的信用现在很值钱。")
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
                            HStack(spacing: 6) {
                                Text(venue.name)
                                    .font(.body.weight(isHere ? .semibold : .regular))
                                    .foregroundStyle(WA.textPrimary)
                                Text(NPCCatalog.profile(id: venue.dealerID)?.name ?? "")
                                    .font(.footnote)
                                    .foregroundStyle(WA.textSecondary)
                            }
                            Text(venue.tagline)
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
            .navigationTitle("跑市场（飞一城 = 一天）")
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
