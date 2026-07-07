import SwiftUI

struct TileView: View {
    let value: Int
    let cellSize: CGFloat

    private var fontSize: CGFloat {
        switch String(value).count {
        case ...2: cellSize * 0.52
        case 3: cellSize * 0.42
        case 4: cellSize * 0.34
        default: cellSize * 0.27
        }
    }

    var body: some View {
        RoundedRectangle(cornerRadius: cellSize * 0.06)
            .fill(Theme.tileColor(value))
            .overlay(
                Text(verbatim: String(value))
                    .font(.system(size: fontSize, weight: .bold))
                    .foregroundStyle(Theme.tileTextColor(value))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .padding(cellSize * 0.05)
            )
            // 先把块+数字合成为单一图层再做透明度过渡，
            // 避免淡入时数字（对比度低）比色块晚显现造成的视觉跳动
            .compositingGroup()
            .frame(width: cellSize, height: cellSize)
    }
}
