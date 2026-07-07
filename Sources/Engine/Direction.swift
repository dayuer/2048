enum Direction: CaseIterable, Sendable {
    case up, down, left, right

    /// 基本法坐标系：(dRow, dCol)，行向下增长、列向右增长。
    var vector: (dRow: Int, dCol: Int) {
        switch self {
        case .up: (-1, 0)
        case .down: (1, 0)
        case .left: (0, -1)
        case .right: (0, 1)
        }
    }
}
