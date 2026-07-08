import SwiftUI

/// 创投百科词典：按分类分区的词条浏览器（培训闭环的「查」）。
struct GlossaryView: View {
    var body: some View {
        List {
            ForEach(GlossaryEntry.Category.allCases, id: \.self) { category in
                Section(category.rawValue) {
                    ForEach(Glossary.entries(in: category)) { entry in
                        NavigationLink {
                            GlossaryDetailView(entry: entry)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(entry.term)
                                    .font(.callout)
                                    .foregroundStyle(WA.textPrimary)
                                if !entry.english.isEmpty {
                                    Text(entry.english)
                                        .font(.caption)
                                        .foregroundStyle(WA.textSecondary)
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("创投百科")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 词条详情：释义 + 出处 + 关联策略包。
struct GlossaryDetailView: View {
    let entry: GlossaryEntry

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text(entry.term)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(WA.textPrimary)
                    if !entry.english.isEmpty {
                        Text(entry.english)
                            .font(.subheadline)
                            .foregroundStyle(WA.textSecondary)
                    }
                    Text(entry.category.rawValue)
                        .font(.caption2.weight(.medium))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(WA.accent.opacity(0.15), in: Capsule())
                        .foregroundStyle(WA.accent)
                }
                .padding(.vertical, 4)
            }

            Section("释义") {
                Text(entry.definition)
                    .font(.callout)
                    .lineSpacing(4)
            }

            Section("出处") {
                Label(entry.source, systemImage: "book.closed")
                    .font(.subheadline)
                    .foregroundStyle(WA.textSecondary)
            }

            if !entry.relatedCardIDs.isEmpty {
                Section("关联策略包") {
                    ForEach(entry.relatedCardIDs, id: \.self) { cardID in
                        if let card = CardCatalog.card(id: cardID) {
                            HStack {
                                Image(systemName: "rectangle.stack.fill")
                                    .foregroundStyle(WA.accent)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(card.name)
                                        .font(.subheadline.weight(.medium))
                                    Text("筹码 \(card.chips) × 倍率 \(String(format: "%.1f", card.mult))")
                                        .font(.caption)
                                        .foregroundStyle(WA.textSecondary)
                                        .monospacedDigit()
                                }
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(entry.term)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 谈判中弹出的词条 sheet（卡面 ⓘ 入口）。
struct GlossarySheet: View {
    let entry: GlossaryEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            GlossaryDetailView(entry: entry)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}
