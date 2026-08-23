import SwiftUI

/// The scrambled letter tiles, max 4 per row, tap to place in the answer.
struct LetterRackView: View {
    @Environment(ScramblisyModel.self) private var game

    var body: some View {
        VStack(spacing: Design.spacing) {
            ForEach(Array(game.rackRows.enumerated()), id: \.offset) { _, row in
                HStack(spacing: Design.spacing) {
                    ForEach(row, id: \.self) { index in
                        ScrambleTileView(
                            letter: String(game.scrambledLetters[index]),
                            index: index,
                            isUsed: game.isLetterUsed(index)
                        )
                    }
                }
            }
        }
        .id(game.wordGeneration)
        .frame(minHeight: 76)
    }
}

/// One rack tile: grow-in on a fresh word, fade when used, blast away on transition.
struct ScrambleTileView: View {
    @Environment(ScramblisyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    @State private var exploded = false

    let letter: String
    let index: Int
    let isUsed: Bool

    private static let tileSize = 64.0

    var body: some View {
        Button(action: select) {
            Text(letter)
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(theme.textPrimary)
                .frame(width: Self.tileSize, height: Self.tileSize)
                .background(theme.tileGradient, in: .rect(cornerRadius: Design.tileCornerRadius))
                .overlay(
                    RoundedRectangle(cornerRadius: Design.tileCornerRadius)
                        .strokeBorder(theme.tileBorder, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.25), radius: 3, y: 2)
        }
        .buttonStyle(.plain)
        .disabled(isUsed || game.isTransitioning)
        .opacity(tileOpacity)
        .scaleEffect(tileScale)
        .rotationEffect(.degrees(exploded ? explosionSpin : 0))
        .offset(exploded ? explosionOffset : .zero)
        .animation(Design.snappy, value: isUsed)
        .onChange(of: game.wordGeneration, initial: true) {
            animateIn()
        }
        .onChange(of: game.explosionTrigger) {
            guard !exploded else { return }
            withAnimation(reduceMotion ? .linear(duration: 0.2) : .easeOut(duration: 0.45)) {
                exploded = true
            }
        }
        .accessibilityLabel(isUsed ? "\(letter), used" : letter)
    }

    private var tileOpacity: Double {
        if exploded { return 0 }
        if !appeared { return 0 }
        return isUsed ? 0.25 : 1
    }

    private var tileScale: Double {
        if exploded { return 0.01 }
        if !appeared { return 0.01 }
        return isUsed ? 0.92 : 1
    }

    /// Deterministic per-tile blast direction.
    private var explosionOffset: CGSize {
        guard !reduceMotion else { return .zero }
        var rng = SeedEngine(seed: index &+ game.explosionTrigger &* 6_151)
        let angle = rng.next() * 2 * .pi
        let distance = 80 + rng.next() * 120
        return CGSize(width: cos(angle) * distance, height: sin(angle) * distance)
    }

    private var explosionSpin: Double {
        guard !reduceMotion else { return 0 }
        var rng = SeedEngine(seed: index &* 31 &+ game.explosionTrigger)
        return rng.next() * 360 - 180
    }

    private func animateIn() {
        appeared = false
        exploded = false
        let delay = reduceMotion ? 0 : Double(index) * 0.05
        withAnimation(Design.tilePop.delay(delay)) {
            appeared = true
        }
    }

    private func select() {
        game.selectLetter(index)
    }
}
