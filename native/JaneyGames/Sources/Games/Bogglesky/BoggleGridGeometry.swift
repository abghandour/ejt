import Foundation

/// Pure geometry for the letter grid: cell layout, hit-testing, and the
/// direction-biased neighbor scoring ported from bogglesky.html. The web
/// version measured DOM rects; here everything derives from cell size + spacing.
nonisolated struct BoggleGridGeometry: Sendable {
    let gridSize: Int
    let cellSize: Double
    let spacing: Double

    var sideLength: Double {
        Double(gridSize) * cellSize + Double(gridSize - 1) * spacing
    }

    func center(of index: Int) -> CGPoint {
        let r = Double(index / gridSize)
        let c = Double(index % gridSize)
        return CGPoint(
            x: c * (cellSize + spacing) + cellSize / 2,
            y: r * (cellSize + spacing) + cellSize / 2
        )
    }

    /// The cell whose bounds contain `point`, or nil when in a gap / outside.
    func cell(at point: CGPoint) -> Int? {
        guard point.x >= 0, point.y >= 0 else { return nil }
        let stride = cellSize + spacing
        let c = Int(point.x / stride)
        let r = Int(point.y / stride)
        guard c < gridSize, r < gridSize else { return nil }
        // Only count the cell body, not its trailing gap.
        let inCellX = point.x - Double(c) * stride <= cellSize
        let inCellY = point.y - Double(r) * stride <= cellSize
        return (inCellX && inCellY) ? r * gridSize + c : nil
    }

    /// When the finger is in a gap: the unvisited neighbor of `lastIndex` the
    /// pointer is heading toward. Scores direction alignment (dot product ×100)
    /// minus distance (×0.5), requiring a positive score — same as the web tuning.
    func bestNeighbor(of lastIndex: Int, toward point: CGPoint, excluding path: Set<Int>) -> Int? {
        let last = center(of: lastIndex)
        var dirX = point.x - last.x
        var dirY = point.y - last.y
        let dirLen = (dirX * dirX + dirY * dirY).squareRoot()
        guard dirLen >= 1 else { return nil }
        dirX /= dirLen
        dirY /= dirLen

        var best: Int?
        var bestScore = -Double.infinity
        for neighbor in BoggleskyEngine.neighbors(of: lastIndex, size: gridSize) where !path.contains(neighbor) {
            let c = center(of: neighbor)
            var nx = c.x - last.x
            var ny = c.y - last.y
            let nLen = (nx * nx + ny * ny).squareRoot()
            guard nLen >= 1 else { continue }
            nx /= nLen
            ny /= nLen
            let dot = dirX * nx + dirY * ny
            let dx = point.x - c.x
            let dy = point.y - c.y
            let dist = (dx * dx + dy * dy).squareRoot()
            let score = dot * 100 - dist * 0.5
            if score > bestScore {
                bestScore = score
                best = neighbor
            }
        }
        return bestScore > 0 ? best : nil
    }
}
