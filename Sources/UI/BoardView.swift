import SwiftUI

struct BoardView: View {
    let tiles: [DisplayTile]

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            let spacing = side * 0.03
            let cellSize = (side - spacing * CGFloat(GameEngine.size + 1)) / CGFloat(GameEngine.size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: side * 0.016)
                    .fill(Theme.board)

                ForEach(0..<GameEngine.size * GameEngine.size, id: \.self) { index in
                    let coord = Coord(row: index / GameEngine.size, col: index % GameEngine.size)
                    RoundedRectangle(cornerRadius: cellSize * 0.06)
                        .fill(Theme.emptyCell)
                        .frame(width: cellSize, height: cellSize)
                        .offset(offset(for: coord, cellSize: cellSize, spacing: spacing))
                }

                ForEach(tiles) { tile in
                    TileView(value: tile.value, cellSize: cellSize)
                        .offset(offset(for: tile.coord, cellSize: cellSize, spacing: spacing))
                        // 出现只做纯淡入（无任何缩放/弹跳）；移除立即消失
                        .transition(.asymmetric(
                            insertion: .opacity,
                            removal: .identity
                        ))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func offset(for coord: Coord, cellSize: CGFloat, spacing: CGFloat) -> CGSize {
        CGSize(
            width: spacing + (cellSize + spacing) * CGFloat(coord.col),
            height: spacing + (cellSize + spacing) * CGFloat(coord.row)
        )
    }
}
