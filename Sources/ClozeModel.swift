import Foundation

// MARK: - Difficulty

enum DifficultyLevel: String, Codable, CaseIterable, Identifiable {
    case beginner
    case intermediate
    case advanced

    var id: String { rawValue }

    var title: String {
        switch self {
        case .beginner: return "初级"
        case .intermediate: return "中级"
        case .advanced: return "进阶"
        }
    }

    var generatorDescription: String {
        switch self {
        case .beginner:
            return "beginner A1-A2 level, using short daily-life words only"
        case .intermediate:
            return "intermediate B1-B2 level, using common school, work, travel, and news words"
        case .advanced:
            return "advanced C1 level, using useful but not obscure academic and professional words"
        }
    }
}

// MARK: - Card

struct ClozeCard: Identifiable, Equatable {
    let id = UUID()
    let sentence: String   // contains "___" where the word goes
    let answer: String
    let hint: String
    let wordMeaning: String
    let phonetic: String
    let partOfSpeech: String
    let memoryTip: String
    let difficulty: DifficultyLevel

    /// Stable identity for tracking stats across launches. The runtime `id`
    /// changes every launch; the text content does not, so we key on that.
    var key: String { "\(sentence.lowercased())#\(answer.lowercased())" }

    init(
        sentence: String,
        answer: String,
        hint: String,
        wordMeaning: String,
        phonetic: String,
        partOfSpeech: String,
        memoryTip: String,
        difficulty: DifficultyLevel = .beginner
    ) {
        self.sentence = sentence
        self.answer = answer
        self.hint = hint
        self.wordMeaning = wordMeaning
        self.phonetic = phonetic
        self.partOfSpeech = partOfSpeech
        self.memoryTip = memoryTip
        self.difficulty = difficulty
    }
}

struct WrongBookEntry: Identifiable, Equatable {
    var id: String { card.key }
    let card: ClozeCard
    let wrongCount: Int
    let lastWrongAt: Date
}

struct LearningContext: Equatable {
    let recentWrongAnswers: [String]
    let recentCorrectAnswers: [String]
    let avoidAnswers: [String]
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

// MARK: - Built-in fallback bank

enum ClozeBank {
    /// The app now relies on adaptive generation instead of a fixed vocabulary
    /// bank, so users don't keep seeing the same words.
    static let all: [ClozeCard] = []
}

// MARK: - Persistence

private struct StoredCard: Codable {
    let sentence: String
    let answer: String
    let hint: String
    let wordMeaning: String?
    let phonetic: String?
    let partOfSpeech: String?
    let memoryTip: String?
    let difficulty: DifficultyLevel?
}

private struct WrongRecord: Codable {
    let card: StoredCard
    var wrongCount: Int
    var lastWrongAt: Date
}

private struct RecentAttempt: Codable {
    let answer: String
    let correct: Bool
    let attemptedAt: Date
}

private struct DeckState: Codable {
    var cards: [StoredCard] = []
    var stats: [String: CardStat] = [:]
    var wrongRecords: [WrongRecord] = []
    var recentAttempts: [RecentAttempt] = []

    init(
        cards: [StoredCard] = [],
        stats: [String: CardStat] = [:],
        wrongRecords: [WrongRecord] = [],
        recentAttempts: [RecentAttempt] = []
    ) {
        self.cards = cards
        self.stats = stats
        self.wrongRecords = wrongRecords
        self.recentAttempts = recentAttempts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cards = try container.decodeIfPresent([StoredCard].self, forKey: .cards) ?? []
        stats = try container.decodeIfPresent([String: CardStat].self, forKey: .stats) ?? [:]
        wrongRecords = try container.decodeIfPresent([WrongRecord].self, forKey: .wrongRecords) ?? []
        recentAttempts = try container.decodeIfPresent([RecentAttempt].self, forKey: .recentAttempts) ?? []
    }
}

private enum Persistence {
    static let url: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Gapfill", isDirectory: true)
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
    private var wrongRecords: [WrongRecord]
    private var recentAttempts: [RecentAttempt]
    private var lastID: UUID?
    private var selectedDifficulty: DifficultyLevel
    private let shouldPersist: Bool

    private var generator: CodexGenerator
    private var isRefilling = false

    init(
        difficulty: DifficultyLevel = .beginner,
        shouldRefillFromCodex: Bool = true,
        shouldPersist: Bool = true
    ) {
        let saved = shouldPersist ? Persistence.load() : DeckState()
        self.cards = []
        self.stats = saved.stats
        self.wrongRecords = saved.wrongRecords
        self.recentAttempts = saved.recentAttempts
        self.selectedDifficulty = difficulty
        self.generator = CodexGenerator(difficulty: difficulty)
        self.shouldPersist = shouldPersist
        if shouldRefillFromCodex {
            refillFromCodex(for: difficulty, count: 6)
        }
    }

    func setDifficulty(_ difficulty: DifficultyLevel) {
        selectedDifficulty = difficulty
        generator.difficulty = difficulty
        if cards(for: difficulty).count < 8 {
            refillFromCodex(for: difficulty, count: 6)
        }
    }

    func nextCard() -> ClozeCard? {
        let eligibleCards = cards(for: selectedDifficulty)
        if eligibleCards.count < 4 { refillFromCodex(for: selectedDifficulty, count: 6) }
        guard !eligibleCards.isEmpty else { return nil }

        let weights = eligibleCards.map { weight(for: $0) }
        let total = weights.reduce(0, +)
        guard total > 0 else { return eligibleCards.randomElement() }

        var r = Double.random(in: 0..<total)
        var chosen = eligibleCards[0]
        for (i, card) in eligibleCards.enumerated() {
            r -= weights[i]
            if r < 0 { chosen = card; break }
        }
        lastID = chosen.id
        cards.removeAll { $0.key == chosen.key }
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
        recentAttempts.append(
            RecentAttempt(
                answer: card.answer.lowercased(),
                correct: correct,
                attemptedAt: Date()
            )
        )
        recentAttempts = Array(recentAttempts.suffix(40))
        if correct {
            s.box = min(s.box + 1, 5)
            removeFromWrongBook(card)
        } else {
            s.wrong += 1
            s.box = 0                               // a miss sends it back to the front
            addToWrongBook(card)
        }
        s.lastShown = Date()
        stats[card.key] = s
        persist()
        refillFromCodex(for: card.difficulty, count: 2)
    }

    func wrongCards() -> [ClozeCard] {
        wrongBookEntries().map(\.card)
    }

    func wrongBookEntries() -> [WrongBookEntry] {
        wrongRecords
            .sorted { $0.lastWrongAt > $1.lastWrongAt }
            .map {
                WrongBookEntry(
                    card: Self.card(from: $0.card),
                    wrongCount: $0.wrongCount,
                    lastWrongAt: $0.lastWrongAt
                )
            }
    }

    func learningContext() -> LearningContext {
        let recentWrong = uniqueAnswers(
            recentAttempts
                .filter { !$0.correct }
                .sorted { $0.attemptedAt > $1.attemptedAt }
                .map(\.answer),
            limit: 5
        )
        let recentCorrect = uniqueAnswers(
            recentAttempts
                .filter(\.correct)
                .sorted { $0.attemptedAt > $1.attemptedAt }
                .map(\.answer),
            limit: 5
        )
        let avoid = uniqueAnswers(
            cards(for: selectedDifficulty)
                .sorted { ($0.answer, $0.sentence) < ($1.answer, $1.sentence) }
                .map { $0.answer.lowercased() },
            limit: 20
        )
        return LearningContext(
            recentWrongAnswers: recentWrong,
            recentCorrectAnswers: recentCorrect,
            avoidAnswers: avoid
        )
    }

    // MARK: helpers

    private func cards(for difficulty: DifficultyLevel) -> [ClozeCard] {
        cards.filter { $0.difficulty == difficulty }
    }

    private func uniqueAnswers(_ answers: [String], limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for answer in answers {
            let normalized = answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            guard !normalized.isEmpty, !seen.contains(normalized) else { continue }
            seen.insert(normalized)
            result.append(normalized)
            if result.count == limit { break }
        }
        return result
    }

    private func mergeIn(_ newCards: [ClozeCard]) {
        var existing = Set(cards.map(\.key))
        for c in newCards where !existing.contains(c.key) {
            cards.append(c)
            existing.insert(c.key)
        }
    }

    private func addToWrongBook(_ card: ClozeCard) {
        let stored = Self.storedCard(from: card)
        if let index = wrongRecords.firstIndex(where: { Self.card(from: $0.card).key == card.key }) {
            wrongRecords[index].wrongCount += 1
            wrongRecords[index].lastWrongAt = Date()
            wrongRecords[index] = WrongRecord(
                card: stored,
                wrongCount: wrongRecords[index].wrongCount,
                lastWrongAt: wrongRecords[index].lastWrongAt
            )
        } else {
            wrongRecords.append(WrongRecord(card: stored, wrongCount: 1, lastWrongAt: Date()))
        }
    }

    private func removeFromWrongBook(_ card: ClozeCard) {
        wrongRecords.removeAll { Self.card(from: $0.card).key == card.key }
    }

    private func persist() {
        guard shouldPersist else { return }
        let state = DeckState(
            cards: [],
            stats: stats,
            wrongRecords: wrongRecords,
            recentAttempts: recentAttempts
        )
        Persistence.save(state)
    }

    private static func card(from stored: StoredCard) -> ClozeCard {
        ClozeCard(
            sentence: stored.sentence,
            answer: stored.answer,
            hint: stored.hint,
            wordMeaning: stored.wordMeaning ?? "暂无释义",
            phonetic: stored.phonetic ?? "-",
            partOfSpeech: stored.partOfSpeech ?? "word",
            memoryTip: stored.memoryTip ?? "先把它放回句子里记：\(Self.sentenceWithAnswer(sentence: stored.sentence, answer: stored.answer))",
            difficulty: stored.difficulty ?? .beginner
        )
    }

    private static func storedCard(from card: ClozeCard) -> StoredCard {
        StoredCard(
            sentence: card.sentence,
            answer: card.answer,
            hint: card.hint,
            wordMeaning: card.wordMeaning,
            phonetic: card.phonetic,
            partOfSpeech: card.partOfSpeech,
            memoryTip: card.memoryTip,
            difficulty: card.difficulty
        )
    }

    private static func sentenceWithAnswer(sentence: String, answer: String) -> String {
        sentence.replacingOccurrences(of: "___", with: answer)
    }

    private func refillFromCodex(for difficulty: DifficultyLevel, count: Int) {
        guard !isRefilling else { return }
        isRefilling = true
        let generator = CodexGenerator(difficulty: difficulty)
        let context = learningContext()
        Task {
            let fresh = await generator.generate(count: count, context: context)
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
