import SwiftUI

/// The letter grid: sizing, the single drag gesture driving tracing, the
/// path line, and the celebration particle overlay.
struct BoggleGridView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme
    @State private var availableSize: CGSize = .zero
    @State private var dragStarted = false

    private static let spacing = 12.0
    private static let maxCellSize = 76.0

    private var geometry: BoggleGridGeometry? {
        guard let board = game.board, board.gridSize > 0,
              availableSize.width > 0, availableSize.height > 0
        else { return nil }
        let n = Double(board.gridSize)
        let gaps = Self.spacing * (n - 1)
        let fit = min(
            (availableSize.width - gaps) / n,
            (availableSize.height - gaps) / n
        )
        let cell = min(Self.maxCellSize, fit)
        guard cell > 0 else { return nil }
        return BoggleGridGeometry(gridSize: board.gridSize, cellSize: cell, spacing: Self.spacing)
    }

    var body: some View {
        ZStack {
            Color.clear
                .onGeometryChange(for: CGSize.self, of: \.size) { size in
                    availableSize = size
                }
            if let board = game.board, let geometry {
                GridBodyView(board: board, geometry: geometry)
                    .frame(width: geometry.sideLength, height: geometry.sideLength)
                    .gesture(dragGesture(geometry: geometry))
            }
        }
        .padding(.horizontal, Design.padding)
    }

    private func dragGesture(geometry: BoggleGridGeometry) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .local)
            .onChanged { value in
                if !dragStarted {
                    if let index = geometry.cell(at: value.location) {
                        dragStarted = true
                        game.dragBegan(at: index)
                    }
                } else {
                    game.dragMoved(to: value.location, geometry: geometry)
                }
            }
            .onEnded { _ in
                guard dragStarted else { return }
                dragStarted = false
                game.dragEnded()
            }
    }
}

/// Cells + path line + particles, laid out at fixed geometry.
struct GridBodyView: View {
    @Environment(BoggleskyModel.self) private var game
    let board: BoggleskyEngine.Board
    let geometry: BoggleGridGeometry

    var body: some View {
        ZStack {
            Grid(horizontalSpacing: geometry.spacing, verticalSpacing: geometry.spacing) {
                ForEach(0..<board.gridSize, id: \.self) { row in
                    GridRow {
                        ForEach(0..<board.gridSize, id: \.self) { column in
                            let index = row * board.gridSize + column
                            BoggleCellView(
                                letter: String(board.letters[index]),
                                index: index,
                                cellSize: geometry.cellSize
                            )
                        }
                    }
                }
            }
            PathLineView(geometry: geometry)
            if let burst = game.burst {
                ParticleBurstView(burst: burst, geometry: geometry)
                    .id(burst.id)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Letter grid")
    }
}

/// Translucent accent line traced through the selected tiles.
struct PathLineView: View {
    @Environment(BoggleskyModel.self) private var game
    @Environment(\.theme) private var theme
    let geometry: BoggleGridGeometry

    var body: some View {
        Canvas { context, _ in
            let path = game.selectedPath
            guard path.count >= 2 else { return }
            var line = Path()
            line.move(to: geometry.center(of: path[0]))
            for index in path.dropFirst() {
                line.addLine(to: geometry.center(of: index))
            }
            context.stroke(
                line,
                with: .color(theme.accent.opacity(0.4)),
                style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round)
            )
        }
        .allowsHitTesting(false)
    }
}
