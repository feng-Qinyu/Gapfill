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

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            Text(sentenceText)
                .font(.system(size: 17, weight: .medium))
                .fixedSize(horizontal: false, vertical: true)

            Text(card.hint)
                .font(.callout)
                .foregroundStyle(.secondary)
                .italic()

            switch state {
            case .typing, .wrong:
                inputArea
            case .correct, .revealed:
                resultArea
            }
        }
        .padding(18)
        .frame(width: 380)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.white.opacity(0.08), lineWidth: 1)
        )
        .onAppear { focused = true }
    }

    private var header: some View {
        HStack {
            Image(systemName: "text.book.closed.fill")
                .foregroundStyle(.tint)
            Text("填空练习")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    private var inputArea: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("输入英文单词…", text: $input)
                .textFieldStyle(.roundedBorder)
                .focused($focused)
                .onSubmit(check)

            if state == .wrong {
                Text("不对哦，再试一次")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("看答案", action: reveal)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("检查", action: check)
                    .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var resultArea: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(
                state == .correct ? "正确！" : "答案：\(card.answer)",
                systemImage: state == .correct ? "checkmark.circle.fill" : "lightbulb.fill"
            )
            .foregroundStyle(state == .correct ? .green : .orange)
            .font(.callout.weight(.semibold))

            HStack {
                Button("稍后再说", action: onSnooze)
                    .buttonStyle(.plain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("再来一个", action: onNext)
                    .keyboardShortcut(.defaultAction)
            }
        }
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
