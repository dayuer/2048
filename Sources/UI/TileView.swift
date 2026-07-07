import SwiftUI

struct TileView: View {
    let tile: Tile
    let cellSize: CGFloat

    private var fontSize: CGFloat {
        switch String(tile.value).count {
        case ...2: cellSize * 0.52
        case 3: cellSize * 0.42
        case 4: cellSize * 0.34
        default: cellSize * 0.27
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cellSize * 0.06)
            .fill(Theme.tileColor(tile.value))
            .overlay(
                Text("\(tile.value)")
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(Theme.tileTextColor(tile.value))
                    .minimumScaleFactor(0.5)
            )
            .frame(width: cellSize, height: cellSize)
    }
}
