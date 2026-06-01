import SwiftUI

struct ClozePopupView: View {
    let card: ClozeCard
    let onResult: (Bool) -> Void   // true = correct, called once
    let onNext: () -> Void         // show another card
    let onClose: () -> Void        // dismiss, start cooldown
    let onSnooze: () -> Void       // dismiss, suppress for 1 hour

    @State private var input = ""
    @State private var state: AnswerState = .typing
    @State private var resultReported = false
    @FocusState private var focused: Bool

    enum AnswerState { case typing, wrong, correct, revealed }

    // What shows in the blank slot of the sentence.
    private var blankWord: String {
        switch state {
        case .correct:  return input
        case .revealed: return card.answer
        default:        return input.isEmpty ? "______" : input
        }
    }

    private var sentenceText: String {
        card.sentence.replacingOccurrences(of: "___", with: blankWord)
    }

    private var sentenceParts: [String] {
        card.sentence.components(separatedBy: "___")
    }

    private var isResolved: Bool {
        state == .correct || state == .revealed
    }

    private var accentGradient: LinearGradient {
        LinearGradient(
            colors: [Color(red: 0.25, green: 0.62, blue: 0.96), Color(red: 0.98, green: 0.58, blue: 0.32)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            sentenceCard

            Text(card.hint)
                .font(.system(.callout, design: .rounded))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            switch state {
            case .typing, .wrong:
                inputArea
            case .correct, .revealed:
                resultArea
            }
        }
        .padding(20)
        .frame(width: 430)
        .background {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(.regularMaterial)
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 0.98, green: 0.99, blue: 1.0).opacity(0.84),
                                Color(red: 1.0, green: 0.96, blue: 0.90).opacity(0.74)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(accentGradient.opacity(0.34), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .shadow(color: .black.opacity(0.18), radius: 24, x: 0, y: 12)
        .onAppear { focused = true }
    }

    private var header: some View {
        HStack {
            ZStack {
                Circle()
                    .fill(accentGradient)
                    .frame(width: 30, height: 30)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Gapfill")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                Text(card.difficulty.title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .frame(width: 32, height: 32)
        }
    }

    private var sentenceCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if let first = sentenceParts.first {
                    Text(first)
                }

                Text(blankWord)
                    .fontWeight(.bold)
                    .foregroundStyle(isResolved ? .white : Color.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background {
                        Capsule()
                            .fill(isResolved ? accentGradient : LinearGradient(colors: [.white.opacity(0.72), .white.opacity(0.42)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    }
                    .overlay {
                        Capsule()
                            .strokeBorder(.black.opacity(isResolved ? 0 : 0.08), lineWidth: 1)
                    }

                if sentenceParts.count > 1 {
                    Text(sentenceParts.dropFirst().joined(separator: blankWord))
                }
            }
            .font(.system(size: 20, weight: .semibold, design: .rounded))
            .lineSpacing(4)
            .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                infoChip(card.difficulty.title, systemImage: "leaf.fill")
                Spacer(minLength: 0)
            }
        }
        .padding(14)
        .background(.white.opacity(0.44), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func infoChip(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.system(size: 10, weight: .semibold, design: .rounded))
            .foregroundStyle(.secondary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(.black.opacity(0.05), in: Capsule())
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            TextField("输入英文单词…", text: $input)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .focused($focused)
                .onSubmit(check)

            if state == .wrong {
                Text("还不对，再试一次；也可以点提示看答案和记忆法。")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("提示", action: reveal)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                Spacer()
                Button("检查", action: check)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(
                state == .correct ? "正确：\(card.answer)" : "答案：\(card.answer)",
                systemImage: state == .correct ? "checkmark.circle.fill" : "lightbulb.fill"
            )
            .foregroundStyle(state == .correct ? .green : .orange)
            .font(.system(.callout, design: .rounded).weight(.semibold))

            wordNoteArea

            HStack {
                Button("稍后再说", action: onSnooze)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                Spacer()
                Button("再来一个", action: onNext)
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var wordNoteArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text(card.wordMeaning)
                    .font(.system(size: 16, weight: .bold, design: .rounded))
                Text(card.phonetic)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(card.partOfSpeech)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(accentGradient, in: Capsule())
                Spacer(minLength: 0)
            }

            Label(card.memoryTip, systemImage: "pin.fill")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(.white.opacity(0.56), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func check() {
        let normalized = input.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized == card.answer.lowercased() {
            state = .correct
            reportResult(correct: true)
        } else {
            state = .wrong
        }
    }

    private func reveal() {
        state = .revealed
        reportResult(correct: false)
    }

    private func reportResult(correct: Bool) {
        guard !resultReported else { return }
        resultReported = true
        onResult(correct)
    }
}
