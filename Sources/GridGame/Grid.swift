/// 泛型棋盘：格子承载一个稳定标识的块；空格为 nil。扁平存储，行优先。
struct Grid<Payload: Codable & Equatable>: Codable, Equatable {
    let rows: Int
    let cols: Int
    private(set) var cells: [Tile<Payload>?]

    init(rows: Int, cols: Int) {
        self.rows = rows
        self.cols = cols
        self.cells = Array(repeating: nil, count: rows * cols)
    }

    subscript(_ c: Coord) -> Tile<Payload>? {
        get { cells[c.row * cols + c.col] }
        set { cells[c.row * cols + c.col] = newValue }
    }

    func contains(_ c: Coord) -> Bool {
        c.row >= 0 && c.row < rows && c.col >= 0 && c.col < cols
    }

    /// 所有非空格子及其坐标（行优先），供引擎遍历与 UI 渲染。
    var occupied: [(coord: Coord, tile: Tile<Payload>)] {
        cells.indices.compactMap { index in
            cells[index].map { (Coord(row: index / cols, col: index % cols), $0) }
        }
    }

    var emptyCoords: [Coord] {
        cells.indices.compactMap { index in
            cells[index] == nil ? Coord(row: index / cols, col: index % cols) : nil
        }
    }
}

extension Grid: Sendable where Payload: Sendable {}
