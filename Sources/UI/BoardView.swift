import SwiftUI

struct BoardView: View {
    let tiles: [Tile]

    var body: some View {
        GeometryReader { geometry in
            let side = geometry.size.width
            let spacing = side * 0.03
            let cellSize = (side - spacing * CGFloat(GameEngine.size + 1)) / CGFloat(GameEngine.size)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: side * 0.016)
                    .fill(Theme.board)

                ForEach(0..<GameEngine.size * GameEngine.size, id: \.self) { index in
                    let position = Position(x: index % GameEngine.size, y: index / GameEngine.size)
                    RoundedRectangle(cornerRadius: cellSize * 0.06)
                        .fill(Theme.emptyCell)
                        .frame(width: cellSize, height: cellSize)
                        .offset(offset(for: position, cellSize: cellSize, spacing: spacing))
                }

                ForEach(tiles) { tile in
                    TileView(tile: tile, cellSize: cellSize)
                        .offset(offset(for: tile.position, cellSize: cellSize, spacing: spacing))
                        // 出现时轻柔淡入放大；移除立即消失，避免合并处的收缩闪烁
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.6).combined(with: .opacity),
                            removal: .identity
                        ))
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }

    private func offset(for position: Position, cellSize: CGFloat, spacing: CGFloat) -> CGSize {
        CGSize(
            width: spacing + (cellSize + spacing) * CGFloat(position.x),
            height: spacing + (cellSize + spacing) * CGFloat(position.y)
        )
    }
}
