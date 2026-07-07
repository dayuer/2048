enum Direction: CaseIterable, Sendable {
    case up, down, left, right

    var vector: (dx: Int, dy: Int) {
        switch self {
        case .up: (0, -1)
        case .down: (0, 1)
        case .left: (-1, 0)
        case .right: (1, 0)
        }
    }
}
