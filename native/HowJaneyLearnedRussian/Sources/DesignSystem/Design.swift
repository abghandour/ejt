import SwiftUI

/// Shared layout, rounding, and animation constants so the app feels uniform.
nonisolated enum Design {
    static let spacing: Double = 12
    static let padding: Double = 16
    static let cornerRadius: Double = 16
    static let cardCornerRadius: Double = 28
    static let tileCornerRadius: Double = 12
    static let maxContentWidth: Double = 600

    static let snappy: Animation = .snappy(duration: 0.25)
    static let bouncy: Animation = .bouncy(duration: 0.4)
    static let tilePop: Animation = .spring(duration: 0.35, bounce: 0.45)
    static let arcadeStep: Animation = .smooth(duration: 0.14)
    static let celebration: Animation = .spring(duration: 0.55, bounce: 0.28)
}
