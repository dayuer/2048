import Foundation

/// BoardView 渲染单元：引擎 Tile<Int> + 其坐标的展开（UI 过渡帧需要独立于引擎改坐标）。
struct DisplayTile: Identifiable, Equatable {
    let id: UUID
    var value: Int
    var coord: Coord
}
