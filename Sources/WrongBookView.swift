import SwiftUI

struct WrongBookView: View {
    let entries: [WrongBookEntry]

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_CN")
        formatter.dateFormat = "MM-dd HH:mm"
        return formatter
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if entries.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(entries) { entry in
                            wrongCard(entry)
                        }
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .padding(20)
        .frame(minWidth: 480, minHeight: 420)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var header: some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("错题本")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                Text("答错或点提示的题会进入这里；再次答对后自动移除。")
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text("\(entries.count)")
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Color.accentColor, in: Capsule())
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 38, weight: .semibold))
                .foregroundStyle(.green)
            Text("现在没有错题")
                .font(.system(size: 18, weight: .bold, design: .rounded))
            Text("答错或点提示后，题目会自动出现在这里。")
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func wrongCard(_ entry: WrongBookEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.card.answer)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                Text(entry.card.phonetic)
                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                    .foregroundStyle(.secondary)
                Text(entry.card.difficulty.title)
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.blue, in: Capsule())
                Spacer()
                Text("错 \(entry.wrongCount) 次")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.orange)
            }

            Text(entry.card.sentence.replacingOccurrences(of: "___", with: "____"))
                .font(.system(size: 15, weight: .semibold, design: .rounded))

            Text(entry.card.hint)
                .font(.system(size: 13, weight: .medium, design: .rounded))
                .foregroundStyle(.secondary)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(entry.card.wordMeaning)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                Text(entry.card.memoryTip)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(dateFormatter.string(from: entry.lastWrongAt))
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(14)
        .background(.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.black.opacity(0.06), lineWidth: 1)
        )
    }
}
