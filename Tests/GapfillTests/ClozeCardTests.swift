import XCTest
@testable import Gapfill

final class ClozeCardTests: XCTestCase {
    func testBuiltInCardsAreBeginnerFriendlyAndIncludeWordNotes() {
        XCTAssertFalse(ClozeBank.all.isEmpty)

        for card in ClozeBank.all {
            XCTAssertLessThanOrEqual(card.answer.count, 9)
            XCTAssertFalse(card.wordMeaning.isEmpty)
            XCTAssertFalse(card.phonetic.isEmpty)
            XCTAssertFalse(card.partOfSpeech.isEmpty)
            XCTAssertFalse(card.memoryTip.isEmpty)
        }
    }

    func testCardKeyIncludesOnlyPromptIdentityNotMutableNotes() {
        let first = ClozeCard(
            sentence: "I ___ water every day.",
            answer: "drink",
            hint: "我每天喝水。",
            wordMeaning: "喝",
            phonetic: "/drɪŋk/",
            partOfSpeech: "verb",
            memoryTip: "drink water = 喝水，直接按短语记。"
        )
        let second = ClozeCard(
            sentence: "I ___ water every day.",
            answer: "drink",
            hint: "我每天喝水。",
            wordMeaning: "饮用",
            phonetic: "/drɪŋk/",
            partOfSpeech: "v.",
            memoryTip: "想成 daily drink。"
        )

        XCTAssertEqual(first.key, second.key)
    }
}
