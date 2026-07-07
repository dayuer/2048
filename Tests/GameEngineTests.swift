import Testing
@testable import Game2048

func makeTile(_ value: Int, _ x: Int, _ y: Int) -> Tile {
    Tile(value: value, position: Position(x: x, y: y))
}

@Suite struct DirectionTests {
    @Test func vectors() {
        #expect(Direction.up.vector == (0, -1))
        #expect(Direction.down.vector == (0, 1))
        #expect(Direction.left.vector == (-1, 0))
        #expect(Direction.right.vector == (1, 0))
    }
}
