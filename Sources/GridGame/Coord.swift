/// 基本法坐标原语：行优先（row 向下增长、col 向右增长）。
struct Coord: Codable, Hashable, Sendable {
    let row: Int
    let col: Int
}
