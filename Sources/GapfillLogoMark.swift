import SwiftUI

struct GapfillLogoMark: View {
    var size: CGFloat = 28
    var colored = true

    private var teal: Color { Color(red: 0.12, green: 0.63, blue: 0.74) }
    private var blue: Color { Color(red: 0.12, green: 0.42, blue: 0.72) }
    private var ink: Color { colored ? Color(red: 0.08, green: 0.14, blue: 0.20) : .primary }
    private var paper: Color { colored ? Color(red: 1.0, green: 0.96, blue: 0.85) : .clear }

    var body: some View {
        ZStack {
            if colored {
                RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [teal, blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }

            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(paper)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                        .stroke(ink.opacity(colored ? 0.08 : 0.92), lineWidth: max(1.4, size * 0.07))
                )
                .frame(width: size * 0.62, height: size * 0.50)
                .rotationEffect(.degrees(-4))
                .offset(x: -size * 0.03, y: -size * 0.01)

            VStack(alignment: .leading, spacing: size * 0.07) {
                Capsule()
                    .fill(ink.opacity(0.9))
                    .frame(width: size * 0.25, height: max(1.5, size * 0.055))
                Capsule()
                    .fill(colored ? teal : ink.opacity(0.92))
                    .frame(width: size * 0.34, height: max(3, size * 0.12))
                Capsule()
                    .fill(ink.opacity(colored ? 0.28 : 0.84))
                    .frame(width: size * 0.23, height: max(1.5, size * 0.055))
            }
            .offset(x: -size * 0.03, y: -size * 0.01)

            Image(systemName: "sparkle")
                .font(.system(size: size * 0.28, weight: .bold))
                .foregroundStyle(colored ? Color(red: 1.0, green: 0.63, blue: 0.10) : ink)
                .offset(x: size * 0.31, y: size * 0.20)
        }
        .frame(width: size, height: size)
    }
}
