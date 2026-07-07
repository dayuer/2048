import Foundation
import Testing
@testable import Game2048

@Suite struct SeededGeneratorTests {
    @Test func sameSeedSameSequence() {
        var a = SeededGenerator(seed: 42)
        var b = SeededGenerator(seed: 42)
        for _ in 0..<8 { #expect(a.next() == b.next()) }
    }

    @Test func differentSeedDivergesEarly() {
        var a = SeededGenerator(seed: 1)
        var b = SeededGenerator(seed: 2)
        #expect(a.next() != b.next())
    }

    @Test func codableRoundTripContinuesSequence() throws {
        var original = SeededGenerator(seed: 7)
        _ = original.next()
        _ = original.next()
        let data = try JSONEncoder().encode(original)
        var restored = try JSONDecoder().decode(SeededGenerator.self, from: data)
        for _ in 0..<8 { #expect(original.next() == restored.next()) }
    }
}

@Suite struct CoordTests {
    @Test func codableAndHashable() throws {
        let coord = Coord(row: 2, col: 3)
        let data = try JSONEncoder().encode(coord)
        let decoded = try JSONDecoder().decode(Coord.self, from: data)
        #expect(decoded == coord)
        #expect(Set([coord, Coord(row: 2, col: 3)]).count == 1)
    }
}

@Suite struct TimelineCodableTests {
    @Test func resolutionRoundTripWithAllChangeKinds() throws {
        let a = UUID(), b = UUID(), c = UUID(), d = UUID(), e = UUID()
        let resolution = Resolution<Int>(
            beats: [
                Beat(
                    moves: [Move(id: a, from: Coord(row: 0, col: 3), to: Coord(row: 0, col: 0))],
                    removals: [Removal(id: d, at: Coord(row: 2, col: 2))],
                    transforms: [Transform(consumed: [a, b], produced: c, at: Coord(row: 0, col: 0), payload: 4)]
                ),
                Beat(spawns: [Spawn(id: e, at: Coord(row: 3, col: 1), payload: 2)]),
            ],
            scoreDelta: 4
        )
        let data = try JSONEncoder().encode(resolution)
        let decoded = try JSONDecoder().decode(Resolution<Int>.self, from: data)
        #expect(decoded == resolution)
    }

    @Test func emptyResolutionMeansNoChange() {
        let resolution = Resolution<Int>()
        #expect(resolution.beats.isEmpty)
        #expect(resolution.scoreDelta == 0)
    }
}

@Suite struct GridTests {
    @Test func subscriptGetSet() {
        var grid = Grid<Int>(rows: 4, cols: 4)
        let tile = Tile<Int>(payload: 2)
        grid[Coord(row: 1, col: 2)] = tile
        #expect(grid[Coord(row: 1, col: 2)] == tile)
        #expect(grid[Coord(row: 2, col: 1)] == nil)
    }

    @Test func containsBounds() {
        let grid = Grid<Int>(rows: 4, cols: 4)
        #expect(grid.contains(Coord(row: 0, col: 0)))
        #expect(grid.contains(Coord(row: 3, col: 3)))
        #expect(!grid.contains(Coord(row: -1, col: 0)))
        #expect(!grid.contains(Coord(row: 0, col: 4)))
    }

    @Test func occupiedAndEmptyCoords() {
        var grid = Grid<Int>(rows: 2, cols: 2)
        grid[Coord(row: 0, col: 1)] = Tile<Int>(payload: 4)
        #expect(grid.occupied.count == 1)
        #expect(grid.occupied[0].coord == Coord(row: 0, col: 1))
        #expect(grid.occupied[0].tile.payload == 4)
        #expect(Set(grid.emptyCoords) == Set([
            Coord(row: 0, col: 0), Coord(row: 1, col: 0), Coord(row: 1, col: 1),
        ]))
    }

    @Test func codableRoundTripPreservesNilCells() throws {
        var grid = Grid<Int>(rows: 4, cols: 4)
        grid[Coord(row: 3, col: 0)] = Tile<Int>(payload: 8)
        let data = try JSONEncoder().encode(grid)
        let decoded = try JSONDecoder().decode(Grid<Int>.self, from: data)
        #expect(decoded == grid)
    }
}
