import Foundation

/// Generates cloze cards via the OpenAI Codex CLI in non-interactive mode.
/// Uses --output-schema to force a strict JSON shape, and -o to capture the
/// final message in a file (cleaner than scraping stdout).
///
/// Setup reminders:
///  • App Sandbox must be OFF (can't spawn codex / read its auth otherwise).
///  • The bundled Codex desktop CLI is used when `codex` is not on PATH.
struct CodexGenerator {
    var difficulty = "intermediate, around CET-6 / IELTS 6.0 level"

    func generate(count: Int = 8) async -> [ClozeCard] {
        let prompt = """
        Generate \(count) English fill-in-the-blank vocabulary exercises at a \
        \(difficulty). Return an object {"items":[...]}. Each item must have: \
        "sentence" — one natural English sentence with exactly ONE useful target \
        word replaced by "___"; "answer" — that target word (the word that fills the blank); \
        "hint" — the complete Chinese translation of the full sentence with the blank \
        filled in (e.g. if sentence is "She was ___ to see him." and answer is "happy", \
        hint should be "她见到他非常高兴。"). Output only data that matches the schema.
        """
        guard let json = await runCodex(prompt: prompt) else { return [] }
        return parse(json)
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

        struct Item: Decodable { let sentence: String; let answer: String; let hint: String }
        struct Wrapper: Decodable { let items: [Item] }

        guard let data = text.data(using: .utf8),
              let wrapper = try? JSONDecoder().decode(Wrapper.self, from: data) else {
            print("Codex output was not valid JSON; keeping existing cards.")
            return []
        }

        return wrapper.items
            .filter { $0.sentence.contains("___") && !$0.answer.isEmpty }
            .map { ClozeCard(sentence: $0.sentence, answer: $0.answer, hint: $0.hint) }
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
            "required": ["sentence", "answer", "hint"],
            "properties": {
              "sentence": { "type": "string" },
              "answer": { "type": "string" },
              "hint": { "type": "string" }
            }
          }
        }
      }
    }
    """
}
