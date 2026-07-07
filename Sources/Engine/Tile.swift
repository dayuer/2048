import Foundation

struct Tile: Codable, Hashable, Identifiable, Sendable {
    let id: UUID
    var value: Int
    var position: Position

    init(id: UUID = UUID(), value: Int, position: Position) {
        self.id = id
        self.value = value
        self.position = position
    }
}
