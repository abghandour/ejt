import SwiftUI

/// The in-round screen: HUD (score, hearts, timer), main word, and the play
/// area with flying words, cut fragments, blade trail, and slash effects.
struct SlashskyPlayView: View {
    @Environment(SlashskyModel.self) private var game
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Design.spacing) {
            HStack(spacing: Design.spacing) {
                Button("Quit", systemImage: "xmark", action: quit)
                    .labelStyle(.iconOnly)
                    .padding(8)
                    .glassEffect(.regular.interactive())

                Label("\(game.state?.score ?? 0)", systemImage: "star.fill")
                    .font(.title3)
                    .bold()
                    .foregroundStyle(theme.accent)
                    .contentTransition(.numericText())
                    .animation(Design.snappy, value: game.state?.score)
                    .accessibilityLabel("Score \(game.state?.score ?? 0)")

                Spacer()

                SlashskyLivesView()

                Spacer()

                Text(game.timeText)
                    .font(.title3)
                    .bold()
                    .monospacedDigit()
                    .foregroundStyle((game.state?.timeRemaining ?? 60) <= 10 ? theme.danger : theme.accent)
                    .accessibilityLabel("Time \(game.timeText)")
            }
            .padding(.horizontal, Design.padding)

            SlashskyMainWordView()

            SlashskyPlayAreaView()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(.vertical, Design.spacing)
        .phaseAnimator(
            reduceMotion ? [0.0] : [0.0, -9, 8, -5, 4, 0],
            trigger: game.shakeTrigger
        ) { view, offset in
            view.offset(x: offset)
        } animation: { _ in
            .linear(duration: 0.05)
        }
        .overlay {
            if game.distractorFlash > 0 {
                DangerFlashView(trigger: game.distractorFlash)
            }
        }
    }

    private func quit() {
        game.backToStart()
    }
}

/// Three hearts, dimming as lives are lost, with a pop on change.
struct SlashskyLivesView: View {
    @Environment(SlashskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        let lives = game.state?.lives ?? 3
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Image(systemName: index < lives ? "heart.fill" : "heart.slash")
                    .foregroundStyle(index < lives ? theme.danger : theme.textMuted.opacity(0.4))
                    .scaleEffect(index == lives ? 1.2 : 1)
            }
        }
        .font(.headline)
        .animation(Design.bouncy, value: lives)
        .accessibilityElement()
        .accessibilityLabel("\(lives) lives left")
    }
}

/// The main word whose synonyms should be slashed, with collect progress.
struct SlashskyMainWordView: View {
    @Environment(SlashskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        VStack(spacing: 2) {
            if let state = game.state {
                Text(state.currentMainWord.word)
                    .font(.system(.title, design: .rounded))
                    .bold()
                    .foregroundStyle(theme.accent)
                    .shadow(color: theme.accentGlow, radius: 10)
                    .contentTransition(.opacity)
                Text(state.currentMainWord.translation)
                    .font(.subheadline)
                    .foregroundStyle(theme.info)
                Text("\(state.collectedSynonyms.count)/\(state.currentMainWord.synonyms.count) synonyms")
                    .font(.caption)
                    .foregroundStyle(theme.textMuted)
            }
        }
        .animation(Design.snappy, value: game.state?.currentMainWord)
        .accessibilityElement(children: .combine)
    }
}

/// Flying words, cut fragments, spark bursts, popups, blade trail, gesture.
struct SlashskyPlayAreaView: View {
    @Environment(SlashskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        @Bindable var game = game
        ZStack {
            ForEach(game.flyingWords) { word in
                FlyingWordView(word: word)
                    .position(x: word.x, y: word.y)
            }

            ForEach(game.fragments) { fragment in
                WordFragmentView(fragment: fragment)
                    .position(x: fragment.x, y: fragment.y)
            }

            ForEach(game.bursts) { burst in
                ExplosionBurstView(
                    trigger: burst.id,
                    hueDegrees: burst.isGood ? 30...60 : 0...15
                )
                .frame(width: 180, height: 180)
                .position(x: burst.x, y: burst.y)
                .allowsHitTesting(false)
            }

            ForEach(game.popups) { popup in
                SlashPopupView(popup: popup)
            }

            BladeTrailView()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(.rect)
        .clipped()
        .onGeometryChange(for: CGSize.self, of: \.size) { size in
            game.areaSize = size
        }
        .gesture(
            DragGesture(minimumDistance: 0, coordinateSpace: .local)
                .onChanged { value in
                    if game.trailPoints.isEmpty {
                        game.swipeBegan(at: value.location)
                    } else {
                        game.swipeMoved(to: value.location)
                    }
                }
                .onEnded { _ in
                    game.swipeEnded()
                }
        )
        .accessibilityElement()
        .accessibilityLabel("Play area — swipe across words to slash them")
    }
}

/// Fruit-Ninja-style blade: a tapered white-hot core inside a gold glow,
/// widest at the fingertip and vanishing at the tail.
struct BladeTrailView: View {
    @Environment(SlashskyModel.self) private var game
    @Environment(\.theme) private var theme

    var body: some View {
        Canvas { context, _ in
            let points = game.trailPoints
            guard points.count >= 2 else { return }
            let count = Double(points.count - 1)

            for index in 1..<points.count {
                let progress = Double(index) / count
                var segment = Path()
                segment.move(to: points[index - 1])
                segment.addLine(to: points[index])

                // Outer glow pass.
                context.stroke(
                    segment,
                    with: .color(theme.accent.opacity(0.10 + 0.30 * progress)),
                    style: StrokeStyle(lineWidth: 3 + 13 * progress, lineCap: .round, lineJoin: .round)
                )
                // White-hot core pass.
                context.stroke(
                    segment,
                    with: .color(.white.opacity(0.25 + 0.65 * progress)),
                    style: StrokeStyle(lineWidth: 1 + 4.5 * progress, lineCap: .round, lineJoin: .round)
                )
            }
        }
        .allowsHitTesting(false)
    }
}

/// One flying word: styled per type, with a pop-in on launch and a lazy spin.
struct FlyingWordView: View {
    @Environment(\.theme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var appeared = false
    let word: SlashskyEngine.FlyingWord

    var body: some View {
        SlashWordCapsule(text: word.text, type: word.type)
            .rotationEffect(.degrees(reduceMotion ? 0 : Double(word.id % 7 - 3) * 4))
            .scaleEffect(appeared ? 1 : 0.3)
            .opacity(appeared ? 1 : 0)
            .onAppear {
                withAnimation(Design.tilePop) {
                    appeared = true
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// The shared capsule styling for whole words and their cut halves.
struct SlashWordCapsule: View {
    @Environment(\.theme) private var theme
    let text: String
    let type: SlashskyEngine.WordType

    var body: some View {
        Text(text)
            .font(.system(.headline, design: .rounded))
            .bold()
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(background, in: .capsule)
            .overlay(Capsule().strokeBorder(borderColor, lineWidth: 1.5))
    }

    private var background: AnyShapeStyle {
        switch type {
        case .synonym, .distractor: AnyShapeStyle(theme.tileGradient)
        case .powerup: AnyShapeStyle(theme.correctGradient)
        case .bomb: AnyShapeStyle(theme.wrongGradient)
        }
    }

    private var borderColor: Color {
        switch type {
        case .synonym, .distractor: theme.tileBorder
        case .powerup: theme.correctBorder
        case .bomb: theme.wrongBorder
        }
    }

    private var textColor: Color {
        switch type {
        case .synonym, .distractor: theme.textPrimary
        case .powerup: theme.successText
        case .bomb: theme.dangerText
        }
    }
}

/// Half of a cut word: the capsule clipped along the slash line, spinning away.
/// Distractor halves burn red so a bad slash *feels* bad.
struct WordFragmentView: View {
    @Environment(\.theme) private var theme
    let fragment: SlashskyModel.WordFragment

    var body: some View {
        Group {
            if fragment.type == .distractor {
                Text(fragment.text)
                    .font(.system(.headline, design: .rounded))
                    .bold()
                    .foregroundStyle(theme.dangerText)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(theme.wrongGradient, in: .capsule)
                    .overlay(Capsule().strokeBorder(theme.wrongBorder, lineWidth: 1.5))
            } else {
                SlashWordCapsule(text: fragment.text, type: fragment.type)
            }
        }
        .clipShape(CutHalfShape(angle: fragment.cutAngle, keepPositiveSide: fragment.keepPositiveSide))
        .rotationEffect(.radians(fragment.rotation))
        .opacity(1 - fragment.age / SlashskyModel.WordFragment.lifetime)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// The half of a rect on one side of a line through its center at `angle` —
/// the geometric cut that splits a slashed word.
struct CutHalfShape: Shape {
    let angle: Double
    let keepPositiveSide: Bool

    nonisolated func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let direction = (dx: cos(angle), dy: sin(angle))

        // Signed side of the cut line (z of the cross product).
        func side(_ point: CGPoint) -> Double {
            let raw = direction.dx * (point.y - center.y) - direction.dy * (point.x - center.x)
            return keepPositiveSide ? raw : -raw
        }

        let corners = [
            CGPoint(x: rect.minX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.minY),
            CGPoint(x: rect.maxX, y: rect.maxY),
            CGPoint(x: rect.minX, y: rect.maxY),
        ]

        // Sutherland–Hodgman clip of the rect against the half-plane.
        var polygon: [CGPoint] = []
        for index in 0..<corners.count {
            let a = corners[index]
            let b = corners[(index + 1) % corners.count]
            let sideA = side(a)
            let sideB = side(b)
            if sideA >= 0 {
                polygon.append(a)
            }
            if sideA * sideB < 0 {
                let t = sideA / (sideA - sideB)
                polygon.append(CGPoint(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t))
            }
        }

        var path = Path()
        guard polygon.count >= 3 else { return path }
        path.addLines(polygon)
        path.closeSubpath()
        return path
    }
}

/// Floating feedback text that rises and fades.
struct SlashPopupView: View {
    @Environment(\.theme) private var theme
    let popup: SlashskyModel.SlashPopup

    private var progress: Double {
        popup.age / SlashskyModel.SlashPopup.lifetime
    }

    var body: some View {
        Text(popup.text)
            .font(.system(.title3, design: .rounded))
            .bold()
            .foregroundStyle(color)
            .shadow(color: color.opacity(0.6), radius: 6)
            .scaleEffect(1 + progress * 0.25)
            .opacity(1 - progress)
            .position(x: popup.x, y: popup.y - 55 * progress)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var color: Color {
        switch popup.kind {
        case .good: theme.accent
        case .bad: theme.danger
        case .bonus: theme.successText
        }
    }
}

/// Brief red border flash when a distractor is slashed.
struct DangerFlashView: View {
    @Environment(\.theme) private var theme
    let trigger: Int
    @State private var visible = false

    var body: some View {
        Rectangle()
            .strokeBorder(theme.danger.opacity(visible ? 0.6 : 0), lineWidth: 5)
            .blur(radius: 4)
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .onChange(of: trigger, initial: true) {
                visible = true
                withAnimation(.easeOut(duration: 0.5)) {
                    visible = false
                }
            }
    }
}
