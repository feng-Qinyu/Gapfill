import XCTest
@testable import Gapfill

final class ClozeCardTests: XCTestCase {
    func testBuiltInBankIsEmptyBecauseCardsAreGeneratedAdaptively() {
        XCTAssertTrue(ClozeBank.all.isEmpty)
    }

    func testLearningContextIsBounded() {
        let deck = ClozeDeck(difficulty: .beginner, shouldRefillFromCodex: false, shouldPersist: false)
        for index in 0..<30 {
            let card = ClozeCard(
                sentence: "Sample ___ sentence \(index).",
                answer: "word\(index)",
                hint: "示例句子。",
                wordMeaning: "词",
                phonetic: "/wɜːrd/",
                partOfSpeech: "noun",
                memoryTip: "sample tip"
            )
            deck.record(card: card, correct: false)
        }

        let context = deck.learningContext()
        XCTAssertLessThanOrEqual(context.recentWrongAnswers.count, 5)
        XCTAssertLessThanOrEqual(context.avoidAnswers.count, 20)
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
