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
    static let beginner: [ClozeCard] = [
        .init(sentence: "I ___ water every day.", answer: "drink", hint: "我每天喝水。", wordMeaning: "喝；饮用", phonetic: "/drɪŋk/", partOfSpeech: "verb", memoryTip: "drink water 是最常见搭配，按“喝水”整体记。"),
        .init(sentence: "She can ___ very fast.", answer: "run", hint: "她跑得很快。", wordMeaning: "跑", phonetic: "/rʌn/", partOfSpeech: "verb", memoryTip: "run 的发音短促，想成起跑时一下冲出去。"),
        .init(sentence: "Please ___ the door.", answer: "open", hint: "请打开门。", wordMeaning: "打开；开放的", phonetic: "/ˈoʊpən/", partOfSpeech: "verb/adjective", memoryTip: "open the door 是固定高频短语，先记动作。"),
        .init(sentence: "This book is very ___.", answer: "good", hint: "这本书很好。", wordMeaning: "好的；不错的", phonetic: "/ɡʊd/", partOfSpeech: "adjective", memoryTip: "good 是基础评价词，和 book、job、idea 都常搭。"),
        .init(sentence: "I ___ my mother on Sundays.", answer: "call", hint: "我星期天给妈妈打电话。", wordMeaning: "打电话；叫作", phonetic: "/kɔːl/", partOfSpeech: "verb/noun", memoryTip: "call mom = 给妈妈打电话，先用生活场景记。"),
        .init(sentence: "We ___ English at school.", answer: "study", hint: "我们在学校学英语。", wordMeaning: "学习；研究", phonetic: "/ˈstʌdi/", partOfSpeech: "verb/noun", memoryTip: "study English 是学生阶段最常见搭配。"),
        .init(sentence: "The soup is ___.", answer: "hot", hint: "汤是热的。", wordMeaning: "热的；辣的", phonetic: "/hɑːt/", partOfSpeech: "adjective", memoryTip: "hot soup、hot tea 都表示温度高。"),
        .init(sentence: "I need a ___ bag.", answer: "new", hint: "我需要一个新包。", wordMeaning: "新的", phonetic: "/nuː/", partOfSpeech: "adjective", memoryTip: "new 和 old 是一组反义词，成对记。"),
        .init(sentence: "He is my best ___.", answer: "friend", hint: "他是我最好的朋友。", wordMeaning: "朋友", phonetic: "/frend/", partOfSpeech: "noun", memoryTip: "best friend = 最好的朋友，直接按短语记。"),
        .init(sentence: "The baby is ___.", answer: "sleeping", hint: "宝宝正在睡觉。", wordMeaning: "正在睡觉", phonetic: "/ˈsliːpɪŋ/", partOfSpeech: "verb", memoryTip: "sleep 加 -ing 表示正在睡，看到 -ing 想“正在”。"),
        .init(sentence: "Can you ___ me?", answer: "help", hint: "你能帮我吗？", wordMeaning: "帮助", phonetic: "/help/", partOfSpeech: "verb/noun", memoryTip: "help me 是求助时最常用的说法。"),
        .init(sentence: "I ___ apples.", answer: "like", hint: "我喜欢苹果。", wordMeaning: "喜欢；像", phonetic: "/laɪk/", partOfSpeech: "verb/preposition", memoryTip: "like apples 先按“喜欢苹果”记，像不像的用法以后再扩展。"),
        .init(sentence: "The room is very ___.", answer: "small", hint: "这个房间很小。", wordMeaning: "小的", phonetic: "/smɔːl/", partOfSpeech: "adjective", memoryTip: "small 和 big 成对记，描述大小最常用。"),
        .init(sentence: "Please ___ your name here.", answer: "write", hint: "请在这里写下你的名字。", wordMeaning: "写", phonetic: "/raɪt/", partOfSpeech: "verb", memoryTip: "write your name = 写你的名字，先记应用场景。"),
        .init(sentence: "I ___ breakfast at seven.", answer: "eat", hint: "我七点吃早饭。", wordMeaning: "吃", phonetic: "/iːt/", partOfSpeech: "verb", memoryTip: "eat breakfast 是一天里最常用的动作短语。"),
        .init(sentence: "This box is ___.", answer: "heavy", hint: "这个箱子很重。", wordMeaning: "重的", phonetic: "/ˈhevi/", partOfSpeech: "adjective", memoryTip: "heavy box = 重箱子，用搬箱子的感觉记。"),
    ]

    static let intermediate: [ClozeCard] = [
        .init(sentence: "We need to ___ this problem today.", answer: "solve", hint: "我们今天需要解决这个问题。", wordMeaning: "解决", phonetic: "/sɑːlv/", partOfSpeech: "verb", memoryTip: "solve a problem = 解决问题，直接按固定搭配记。", difficulty: .intermediate),
        .init(sentence: "Please ___ the document before the meeting.", answer: "review", hint: "请在会议前审阅这份文件。", wordMeaning: "审阅；复习", phonetic: "/rɪˈvjuː/", partOfSpeech: "verb/noun", memoryTip: "re-view 可以想成“再看一遍”。", difficulty: .intermediate),
        .init(sentence: "Reading can ___ your vocabulary.", answer: "improve", hint: "阅读可以提升你的词汇量。", wordMeaning: "提升；改善", phonetic: "/ɪmˈpruːv/", partOfSpeech: "verb", memoryTip: "improve English = 提升英语，高频表达。", difficulty: .intermediate),
        .init(sentence: "The new rule will ___ many workers.", answer: "affect", hint: "新规则会影响许多员工。", wordMeaning: "影响", phonetic: "/əˈfekt/", partOfSpeech: "verb", memoryTip: "affect 是动词，effect 多作名词，先记 affect people。", difficulty: .intermediate),
        .init(sentence: "The company wants to ___ its market.", answer: "expand", hint: "公司想扩大市场。", wordMeaning: "扩大；扩展", phonetic: "/ɪkˈspænd/", partOfSpeech: "verb", memoryTip: "ex- 有“向外”的感觉，expand 就是向外变大。", difficulty: .intermediate),
        .init(sentence: "He can ___ pressure well.", answer: "handle", hint: "他能很好地处理压力。", wordMeaning: "处理；应对", phonetic: "/ˈhændl/", partOfSpeech: "verb/noun", memoryTip: "handle pressure = 处理压力，工作场景常用。", difficulty: .intermediate),
        .init(sentence: "They reached an ___ after a long talk.", answer: "agreement", hint: "他们长谈后达成了协议。", wordMeaning: "协议；一致", phonetic: "/əˈɡriːmənt/", partOfSpeech: "noun", memoryTip: "agree 加 -ment 变名词，agreement 就是“同意的结果”。", difficulty: .intermediate),
        .init(sentence: "Her answer was clear and ___.", answer: "concise", hint: "她的回答清晰而简洁。", wordMeaning: "简洁的", phonetic: "/kənˈsaɪs/", partOfSpeech: "adjective", memoryTip: "concise answer = 简洁回答，写作和汇报常用。", difficulty: .intermediate),
    ]

    static let advanced: [ClozeCard] = [
        .init(sentence: "The report offers a useful ___ of the market.", answer: "analysis", hint: "这份报告提供了有用的市场分析。", wordMeaning: "分析", phonetic: "/əˈnæləsɪs/", partOfSpeech: "noun", memoryTip: "analysis 常和 report、data、market 搭配。", difficulty: .advanced),
        .init(sentence: "We need to ___ the risk before we decide.", answer: "evaluate", hint: "我们需要先评估风险再决定。", wordMeaning: "评估", phonetic: "/ɪˈvæljueɪt/", partOfSpeech: "verb", memoryTip: "value 是价值，evaluate 就是判断价值或程度。", difficulty: .advanced),
        .init(sentence: "The plan is ___ but possible.", answer: "ambitious", hint: "这个计划目标很高，但有可能实现。", wordMeaning: "有雄心的；目标高的", phonetic: "/æmˈbɪʃəs/", partOfSpeech: "adjective", memoryTip: "ambitious plan = 目标高的计划。", difficulty: .advanced),
        .init(sentence: "The team must ___ quickly to change.", answer: "adapt", hint: "团队必须快速适应变化。", wordMeaning: "适应；调整", phonetic: "/əˈdæpt/", partOfSpeech: "verb", memoryTip: "adapt to change = 适应变化，职场高频。", difficulty: .advanced),
        .init(sentence: "This evidence can ___ our argument.", answer: "support", hint: "这个证据可以支持我们的论点。", wordMeaning: "支持；支撑", phonetic: "/səˈpɔːrt/", partOfSpeech: "verb/noun", memoryTip: "support an argument = 支持论点。", difficulty: .advanced),
        .init(sentence: "The decision had a major ___.", answer: "consequence", hint: "这个决定产生了重大后果。", wordMeaning: "后果；结果", phonetic: "/ˈkɑːnsəkwens/", partOfSpeech: "noun", memoryTip: "consequence 常指决定之后带来的结果。", difficulty: .advanced),
        .init(sentence: "The system should remain ___ under pressure.", answer: "stable", hint: "系统在压力下应保持稳定。", wordMeaning: "稳定的", phonetic: "/ˈsteɪbl/", partOfSpeech: "adjective", memoryTip: "stable system = 稳定系统，技术场景常用。", difficulty: .advanced),
        .init(sentence: "Good design can ___ user behavior.", answer: "influence", hint: "好的设计可以影响用户行为。", wordMeaning: "影响", phonetic: "/ˈɪnfluəns/", partOfSpeech: "verb/noun", memoryTip: "influence behavior = 影响行为，比 affect 更偏长期作用。", difficulty: .advanced),
    ]

    static let all: [ClozeCard] = beginner + intermediate + advanced
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

private struct DeckState: Codable {
    var cards: [StoredCard] = []
    var stats: [String: CardStat] = [:]
    var wrongRecords: [WrongRecord] = []

    init(cards: [StoredCard] = [], stats: [String: CardStat] = [:], wrongRecords: [WrongRecord] = []) {
        self.cards = cards
        self.stats = stats
        self.wrongRecords = wrongRecords
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        cards = try container.decodeIfPresent([StoredCard].self, forKey: .cards) ?? []
        stats = try container.decodeIfPresent([String: CardStat].self, forKey: .stats) ?? [:]
        wrongRecords = try container.decodeIfPresent([WrongRecord].self, forKey: .wrongRecords) ?? []
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
        let restored = saved.cards.map(Self.card(from:))
        self.cards = restored.isEmpty ? ClozeBank.all : restored
        self.stats = saved.stats
        self.wrongRecords = saved.wrongRecords
        self.selectedDifficulty = difficulty
        self.generator = CodexGenerator(difficulty: difficulty)
        self.shouldPersist = shouldPersist
        mergeIn(ClozeBank.all)   // always keep the built-in bank available
        if shouldRefillFromCodex {
            refillFromCodex(for: difficulty)        // ask Codex for fresh material in the background
        }
    }

    func setDifficulty(_ difficulty: DifficultyLevel) {
        selectedDifficulty = difficulty
        generator.difficulty = difficulty
        if cards(for: difficulty).count < 8 {
            refillFromCodex(for: difficulty)
        }
    }

    func nextCard() -> ClozeCard? {
        let eligibleCards = cards(for: selectedDifficulty)
        if eligibleCards.count < 8 { refillFromCodex(for: selectedDifficulty) }
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
            removeFromWrongBook(card)
        } else {
            s.wrong += 1
            s.box = 0                               // a miss sends it back to the front
            addToWrongBook(card)
        }
        s.lastShown = Date()
        stats[card.key] = s
        persist()
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

    // MARK: helpers

    private func cards(for difficulty: DifficultyLevel) -> [ClozeCard] {
        cards.filter { $0.difficulty == difficulty }
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
            cards: cards.map(Self.storedCard(from:)),
            stats: stats,
            wrongRecords: wrongRecords
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

    private func refillFromCodex(for difficulty: DifficultyLevel) {
        guard !isRefilling else { return }
        isRefilling = true
        let generator = CodexGenerator(difficulty: difficulty)
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
