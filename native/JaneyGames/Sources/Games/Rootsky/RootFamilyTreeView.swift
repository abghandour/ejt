import SwiftUI

/// The day's five words growing as branches from their shared root —
/// shown on the results card, branches sprouting one by one.
struct RootFamilyTreeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let rootWord: String
    let words: [String]
    let theme: Theme
    @State private var grownCount = 0

    private static let height = 150.0

    var body: some View {
        VStack(spacing: 4) {
            // Branch canopy: words fan out above the root.
            ZStack {
                Canvas { context, size in
                    let origin = CGPoint(x: size.width / 2, y: size.height)
                    for (index, position) in wordPositions(in: size).enumerated() where index < grownCount {
                        var branch = Path()
                        branch.move(to: origin)
                        let control = CGPoint(
                            x: (origin.x + position.x) / 2,
                            y: position.y + (origin.y - position.y) * 0.35
                        )
                        branch.addQuadCurve(to: position, control: control)
                        context.stroke(
                            branch,
                            with: .color(theme.success.opacity(0.7)),
                            style: StrokeStyle(lineWidth: 2, lineCap: .round)
                        )
                    }
                }
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let position = wordPositions(in: CGSize(width: 300, height: Self.height))[index]
                    Text(word)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(theme.textPrimary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(theme.correctGradient, in: .capsule)
                        .overlay(Capsule().strokeBorder(theme.correctBorder, lineWidth: 1))
                        .position(position)
                        .scaleEffect(index < grownCount ? 1 : 0.01)
                        .opacity(index < grownCount ? 1 : 0)
                }
            }
            .frame(width: 300, height: Self.height)

            Label(rootWord, systemImage: "arrow.up")
                .font(.system(.subheadline, design: .rounded))
                .bold()
                .foregroundStyle(theme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(theme.tileSelectedGradient, in: .capsule)
                .overlay(Capsule().strokeBorder(theme.accent.opacity(0.5), lineWidth: 1))
        }
        .onAppear(perform: grow)
        .accessibilityElement()
        .accessibilityLabel("Word family tree: \(words.joined(separator: ", ")), all from the root \(rootWord)")
    }

    /// Fan layout: 3 up top, 2 on a lower tier.
    private func wordPositions(in size: CGSize) -> [CGPoint] {
        let columns = [0.16, 0.5, 0.84, 0.28, 0.72]
        let rows = [0.15, 0.1, 0.15, 0.55, 0.55]
        return (0..<min(words.count, 5)).map { i in
            CGPoint(x: size.width * columns[i], y: size.height * rows[i])
        }
    }

    private func grow() {
        guard grownCount == 0 else { return }
        guard !reduceMotion else {
            grownCount = words.count
            return
        }
        for index in 0..<words.count {
            withAnimation(Design.tilePop.delay(0.3 + Double(index) * 0.18)) {
                grownCount = index + 1
            }
        }
    }
}
