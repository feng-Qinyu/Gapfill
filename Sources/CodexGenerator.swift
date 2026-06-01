import Foundation

/// Generates cloze cards via the OpenAI Codex CLI in non-interactive mode.
/// Uses --output-schema to force a strict JSON shape, and -o to capture the
/// final message in a file (cleaner than scraping stdout).
///
/// Setup reminders:
///  • App Sandbox must be OFF (can't spawn codex / read its auth otherwise).
///  • Set CODEX_CLI_PATH when you want Gapfill to use a specific Codex CLI.
struct CodexGenerator {
    var difficulty: DifficultyLevel = .beginner

    func generate(count: Int = 8, context: LearningContext = LearningContext(
        recentWrongAnswers: [],
        recentCorrectAnswers: [],
        avoidAnswers: []
    )) async -> [ClozeCard] {
        guard let json = await runCodex(prompt: prompt(count: count, context: context)) else { return [] }
        return parse(json)
    }

    func prompt(count: Int, context: LearningContext) -> String {
        let recentWrong = context.recentWrongAnswers.joined(separator: ", ")
        let recentCorrect = context.recentCorrectAnswers.joined(separator: ", ")
        let avoid = context.avoidAnswers.joined(separator: ", ")

        return """
        Generate \(count) English fill-in-the-blank vocabulary exercises at a \
        \(difficulty.generatorDescription). Avoid rare, overly obscure, or exam-trick words. \
        Create fresh, varied vocabulary across daily life, work, study, travel, feelings, \
        objects, actions, food, time, places, and simple abstract ideas. Do not overuse \
        common repeated examples like bag, dinner, bread, water, or shop unless they are \
        directly needed by the compact learning context.
        Use this compact learning context only; do not ask for or assume full history:
        {"recentWrongAnswers":"\(recentWrong)","recentCorrectAnswers":"\(recentCorrect)","avoidAnswers":"\(avoid)"}
        Prefer practicing a related easier word if recentWrongAnswers is non-empty. \
        Avoid all answer words listed in avoidAnswers. \
        Return an object {"items":[...]}. Each item must have: \
        "sentence" — one natural English sentence with exactly ONE useful target \
        word replaced by "___"; "answer" — that target word (the word that fills the blank); \
        "hint" — the complete Chinese translation of the full sentence with the blank \
        filled in (e.g. if sentence is "She was ___ to see him." and answer is "happy", \
        hint should be "她见到他非常高兴。"); "wordMeaning" — the Chinese meaning of the \
        answer word; "phonetic" — IPA pronunciation such as "/hæpi/"; "partOfSpeech" — \
        simple part of speech like "verb", "noun", or "adjective"; "memoryTip" — a short, \
        easy-to-remember Chinese memory tip using this sentence or a common phrase. \
        Output only data that matches the schema.
        """
    }

    private func runCodex(prompt: String) async -> String? {
        let tmp = FileManager.default.temporaryDirectory
        let schemaURL = tmp.appendingPathComponent("cloze_schema.json")
        let outURL = tmp.appendingPathComponent("cloze_out.json")
        try? Self.schemaJSON.data(using: .utf8)?.write(to: schemaURL)
        try? FileManager.default.removeItem(at: outURL)

        return await withCheckedContinuation { continuation in
            let process = Process()
            guard let codexURL = Self.resolveCodexURL() else {
                print("Codex launch failed: codex CLI was not found.")
                continuation.resume(returning: nil)
                return
            }
            process.executableURL = codexURL
            process.arguments = [
                "exec", "--skip-git-repo-check",
                "--output-schema", schemaURL.path,
                "-o", outURL.path,
                prompt
            ]
            process.environment = ProcessInfo.processInfo.environment

            let outPipe = Pipe(); process.standardOutput = outPipe
            let errPipe = Pipe(); process.standardError = errPipe

            process.terminationHandler = { _ in
                // Prefer the -o file (validated JSON); fall back to stdout.
                if let data = try? Data(contentsOf: outURL),
                   let text = String(data: data, encoding: .utf8),
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    continuation.resume(returning: text)
                } else {
                    let data = outPipe.fileHandleForReading.readDataToEndOfFile()
                    continuation.resume(returning: String(data: data, encoding: .utf8))
                }
            }

            do {
                try process.run()
            } catch {
                print("Codex launch failed (check codexPath & App Sandbox): \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    private static func resolveCodexURL() -> URL? {
        let fileManager = FileManager.default

        if let path = ProcessInfo.processInfo.environment["CODEX_CLI_PATH"],
           fileManager.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }

        let candidates = [
            "/opt/homebrew/bin/codex",
            "/usr/local/bin/codex",
            "/Applications/Codex.app/Contents/Resources/codex"
        ]

        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for directory in path.split(separator: ":") {
                let candidate = "\(directory)/codex"
                if fileManager.isExecutableFile(atPath: candidate) {
                    return URL(fileURLWithPath: candidate)
                }
            }
        }

        for candidate in candidates where fileManager.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        return nil
    }

    private func parse(_ raw: String) -> [ClozeCard] {
        var text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = text.firstIndex(of: "{"),
           let end = text.lastIndex(of: "}"), start < end {
            text = String(text[start...end])
        }

        struct Item: Decodable {
            let sentence: String
            let answer: String
            let hint: String
            let wordMeaning: String
            let phonetic: String
            let partOfSpeech: String
            let memoryTip: String
        }
        struct Wrapper: Decodable { let items: [Item] }

        guard let data = text.data(using: .utf8),
              let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) else {
            print("Codex output was not valid JSON; keeping existing cards.")
            return []
        }

        return wrapper.items
            .filter { item in
                item.sentence.contains("___")
                    && !item.answer.isEmpty
                    && item.answer.count <= 12
                    && !item.wordMeaning.isEmpty
                    && !item.memoryTip.isEmpty
            }
            .map {
                ClozeCard(
                    sentence: $0.sentence,
                    answer: $0.answer,
                    hint: $0.hint,
                    wordMeaning: $0.wordMeaning,
                    phonetic: $0.phonetic,
                    partOfSpeech: $0.partOfSpeech,
                    memoryTip: $0.memoryTip,
                    difficulty: difficulty
                )
            }
    }

    /// JSON Schema handed to `codex exec --output-schema`. Wrapped in an object
    /// with an `items` array, since structured output expects an object root.
    static let schemaJSON = """
    {
      "type": "object",
      "additionalProperties": false,
      "required": ["items"],
      "properties": {
        "items": {
          "type": "array",
          "items": {
            "type": "object",
            "additionalProperties": false,
            "required": ["sentence", "answer", "hint", "wordMeaning", "phonetic", "partOfSpeech", "memoryTip"],
            "properties": {
              "sentence": { "type": "string" },
              "answer": { "type": "string" },
              "hint": { "type": "string" },
              "wordMeaning": { "type": "string" },
              "phonetic": { "type": "string" },
              "partOfSpeech": { "type": "string" },
              "memoryTip": { "type": "string" }
            }
          }
        }
      }
    }
    """
}
