import Foundation

// MARK: - Card

struct ClozeCard: Identifiable, Equatable {
    let id = UUID()
    let sentence: String   // contains "___" where the word goes
    let answer: String
    let hint: String

    /// Stable identity for tracking stats across launches. The runtime `id`
    /// changes every launch; the text content does not, so we key on that.
    var key: String { "\(sentence.lowercased())#\(answer.lowercased())" }
}

// MARK: - Per-card learning stats (persisted)

struct CardStat: Codable {
    var seen = 0
    var wrong = 0
    var box = 0            // Leitner level: 0 = new/forgotten, higher = mastered
    var lastShown: Date?

    /// Fraction of attempts answered wrong. Unseen cards default to 0.5 so
    /// brand-new material gets medium priority rather than being ignored.
    var wrongRate: Double { seen > 0 ? Double(wrong) / Double(seen) : 0.5 }
}

// MARK: - Built-in fallback bank (cold start / offline)

enum ClozeBank {
    static let all: [ClozeCard] = [
        .init(sentence: "I want to ___ a new language this year.", answer: "learn", hint: "我今年想学一门新语言。"),
        .init(sentence: "She was ___ to hear the good news.", answer: "delighted", hint: "她听到这个好消息非常欣喜。"),
        .init(sentence: "We need to ___ this problem before the deadline.", answer: "solve", hint: "我们需要在截止日期前解决这个问题。"),
        .init(sentence: "His argument was very ___ and convincing.", answer: "persuasive", hint: "他的论点非常有说服力，令人信服。"),
        .init(sentence: "The company plans to ___ its business overseas.", answer: "expand", hint: "公司计划将业务扩展到海外。"),
        .init(sentence: "Please ___ the document before signing it.", answer: "review", hint: "请在签署之前审阅这份文件。"),
        .init(sentence: "They decided to ___ the meeting until next week.", answer: "postpone", hint: "他们决定将会议推迟到下周。"),
        .init(sentence: "A good leader should ___ their team.", answer: "inspire", hint: "好的领导者应该激励自己的团队。"),
        .init(sentence: "The new policy will ___ millions of people.", answer: "affect", hint: "新政策将影响数百万人。"),
        .init(sentence: "He tried to ___ the difficult situation calmly.", answer: "handle", hint: "他试图冷静地处理这一困难局面。"),
        .init(sentence: "Reading every day can ___ your vocabulary.", answer: "improve", hint: "每天阅读可以提升你的词汇量。"),
        .init(sentence: "We should ___ our natural resources.", answer: "conserve", hint: "我们应该保护自然资源。"),
        .init(sentence: "Her explanation was clear and ___.", answer: "concise", hint: "她的解释清晰而简洁。"),
        .init(sentence: "The two countries reached an ___ after talks.", answer: "agreement", hint: "两国经过谈判达成了协议。"),
        .init(sentence: "You must ___ to the rules of the game.", answer: "adhere", hint: "你必须遵守比赛规则。"),
        .init(sentence: "The scientist made a remarkable ___.", answer: "discovery", hint: "这位科学家取得了一项了不起的发现。"),
    ]
}

// MARK: - Persistence

private struct StoredCard: Codable {
    let sentence: String
    let answer: String
    let hint: String
}

private struct DeckState: Codable {
    var cards: [StoredCard] = []
    var stats: [String: CardStat] = [:]
}

private enum Persistence {
    static let url: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EnglishCloze", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("state.json")
    }()

    static func load() -> DeckState {
        guard let data = try? Data(contentsOf: url),
              let state = try? JSONDecoder().decode(DeckState.self, from: data) else {
            return DeckState()
        }
        return state
    }

    static func save(_ state: DeckState) {
        if let data = try? JSONEncoder().encode(state) {
            try? data.write(to: url, options: .atomic)
        }
    }
}

// MARK: - Deck

/// Holds the card pool + per-card stats, persists them to disk, and chooses the
/// next card with weighted randomness: frequently-wrong and less-known cards
/// are surfaced more often; mastered cards fade out.
final class ClozeDeck {
    private var cards: [ClozeCard]
    private var stats: [String: CardStat]
    private var lastID: UUID?

    private let generator = CodexGenerator()
    private var isRefilling = false

    init() {
        let saved = Persistence.load()
        let restored = saved.cards.map {
            ClozeCard(sentence: $0.sentence, answer: $0.answer, hint: $0.hint)
        }
        self.cards = restored.isEmpty ? ClozeBank.all : restored
        self.stats = saved.stats
        mergeIn(ClozeBank.all)   // always keep the built-in bank available
        refillFromCodex()        // ask Codex for fresh material in the background
    }

    func nextCard() -> ClozeCard? {
        if cards.count < 8 { refillFromCodex() }
        guard !cards.isEmpty else { return nil }

        let weights = cards.map { weight(for: $0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return cards.randomElement() }

        var r = Double.random(in: 0..<total)
        var chosen = cards[0]
        for (i, card) in cards.enumerated() {
            r -= weights[i]
            if r < 0 { chosen = card; break }
        }
        lastID = chosen.id
        return chosen
    }

    /// Higher weight = more likely to be shown next.
    private func weight(for card: ClozeCard) -> Double {
        let s = stats[card.key] ?? CardStat()
        var w = 1.0 + s.wrongRate * 4.0            // up to ~5x for always-wrong cards
        w *= pow(0.6, Double(s.box))               // mastered cards drop off
        if card.id == lastID { w *= 0.02 }          // never immediately repeat
        if let last = s.lastShown,
           Date().timeIntervalSince(last) < 120 { w *= 0.3 }  // brief cooldown
        return max(w, 0.001)
    }

    func record(card: ClozeCard, correct: Bool) {
        var s = stats[card.key] ?? CardStat()
        s.seen += 1
        if correct {
            s.box = min(s.box + 1, 5)
        } else {
            s.wrong += 1
            s.box = 0                               // a miss sends it back to the front
        }
        s.lastShown = Date()
        stats[card.key] = s
        persist()
    }

    // MARK: helpers

    private func mergeIn(_ newCards: [ClozeCard]) {
        var existing = Set(cards.map(\.key))
        for c in newCards where !existing.contains(c.key) {
            cards.append(c)
            existing.insert(c.key)
        }
    }

    private func persist() {
        let state = DeckState(
            cards: cards.map { StoredCard(sentence: $0.sentence, answer: $0.answer, hint: $0.hint) },
            stats: stats
        )
        Persistence.save(state)
    }

    private func refillFromCodex() {
        guard !isRefilling else { return }
        isRefilling = true
        Task {
            let fresh = await generator.generate(count: 8)
            await MainActor.run {
                if !fresh.isEmpty {
                    self.mergeIn(fresh)
                    self.persist()       // persist generated cards so they survive restart
                }
                self.isRefilling = false
            }
        }
    }
}

// MARK: - Daily stats for the menu

struct Stats {
    private(set) var todayCount = 0
    private(set) var correctCount = 0

    var accuracyText: String {
        guard todayCount > 0 else { return "—" }
        return "\(Int(Double(correctCount) / Double(todayCount) * 100))%"
    }

    mutating func record(correct: Bool) {
        todayCount += 1
        if correct { correctCount += 1 }
    }
}
