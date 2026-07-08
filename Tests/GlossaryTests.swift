import XCTest
@testable import Game2048

/// 创投百科词典（Phase 2.5）：静态目录完整性——卡牌↔词条双向链接不许有死链。
final class GlossaryTests: XCTestCase {
    func testEntryIDsAreUnique() {
        let ids = Glossary.all.map(\.id)
        XCTAssertEqual(ids.count, Set(ids).count, "词条 id 不得重复")
    }

    func testEntriesHaveNoEmptyFields() {
        for entry in Glossary.all {
            XCTAssertFalse(entry.term.isEmpty, "\(entry.id) 缺词名")
            XCTAssertFalse(entry.definition.isEmpty, "\(entry.id) 缺释义")
            XCTAssertFalse(entry.source.isEmpty, "\(entry.id) 缺出处")
        }
    }

    func testLookupByID() {
        XCTAssertNotNil(Glossary.entry(id: "liq-pref"), "优先清算权必须在词典里")
        XCTAssertNil(Glossary.entry(id: "no-such-term"))
    }

    /// 每张策略包卡牌（含传说卡）都必须挂一个存在的词条（点击 ⓘ 必有着落）。
    func testEveryCardLinksToExistingEntry() {
        for card in CardCatalog.rookiePool + CardCatalog.legendaryPool {
            XCTAssertNotNil(
                Glossary.entry(id: card.glossaryID),
                "卡【\(card.name)】的词条 \(card.glossaryID) 不存在"
            )
        }
    }

    /// 词条反向引用的卡牌 id 必须真实存在于卡池。
    func testRelatedCardIDsResolve() {
        for entry in Glossary.all {
            for cardID in entry.relatedCardIDs {
                XCTAssertNotNil(
                    CardCatalog.card(id: cardID),
                    "词条「\(entry.term)」引用了不存在的卡 \(cardID)"
                )
            }
        }
    }

    func testEveryCategoryHasEntries() {
        for category in GlossaryEntry.Category.allCases {
            XCTAssertFalse(
                Glossary.entries(in: category).isEmpty,
                "分类 \(category) 不能是空架子"
            )
        }
    }
}
