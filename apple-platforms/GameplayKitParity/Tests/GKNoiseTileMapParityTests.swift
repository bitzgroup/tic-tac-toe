import GameplayKit
import SpriteKit
import XCTest

/// Records Apple's `SKTileMapNode.tileMapNodes(tileSet:columns:rows:tileSize:from:tileTypeNoiseMapThresholds:)`,
/// which bitzgroup/GKSKBridge mirrors: one map per threshold plus one, map 0 filled with the first
/// group and map k holding group k wherever the noise reaches threshold k − 1, each cell's noise
/// being the mean of 3 × 3 bilinear samples across the cell.
final class GKNoiseTileMapParityTests: XCTestCase {
    private func group(_ name: String) -> SKTileGroup {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 4, height: 4)).image { _ in }
        let group = SKTileGroup(tileDefinition: SKTileDefinition(texture: SKTexture(image: image), size: CGSize(width: 10, height: 10)))
        group.name = name
        return group
    }

    private lazy var abc = SKTileSet(tileGroups: [group("a"), group("b"), group("c")])

    /// A noise map whose samples are exactly `value(x, y)`.
    private func noiseMap(_ samples: vector_int2, _ value: (Int, Int) -> Float) -> GKNoiseMap {
        let map = GKNoiseMap(
            GKNoise(GKConstantNoiseSource(value: 0)), size: vector_double2(1, 1), origin: vector_double2(0, 0),
            sampleCount: samples, seamless: false
        )
        for y in 0..<Int(samples.y) {
            for x in 0..<Int(samples.x) { map.setValue(value(x, y), at: vector_int2(Int32(x), Int32(y))) }
        }
        return map
    }

    private func maps(_ set: SKTileSet, _ columns: Int, _ rows: Int, _ noise: GKNoiseMap, _ thresholds: [Double]) -> [SKTileMapNode] {
        SKTileMapNode.tileMapNodes(
            tileSet: set, columns: columns, rows: rows, tileSize: CGSize(width: 10, height: 10), from: noise,
            tileTypeNoiseMapThresholds: thresholds.map { NSNumber(value: $0) }
        )
    }

    /// Each map's cells as group names, rows bottom to top separated by `/`, `-` for empty.
    private func layout(_ map: SKTileMapNode) -> String {
        (0..<map.numberOfRows).map { row in
            String((0..<map.numberOfColumns).map { column in
                Character(map.tileGroup(atColumn: column, row: row)?.name ?? "-")
            })
        }.joined(separator: "/")
    }

    func testOneMapPerThresholdPlusOneSharingTheGivenLayout() {
        let generated = maps(abc, 4, 3, noiseMap(vector_int2(4, 3)) { _, _ in 0 }, [-0.5, 0.5])
        XCTAssertEqual(generated.count, 3)
        for map in generated {
            XCTAssertTrue(map.tileSet === abc)
            XCTAssertEqual(map.numberOfColumns, 4)
            XCTAssertEqual(map.numberOfRows, 3)
            XCTAssertEqual(map.tileSize, CGSize(width: 10, height: 10))
            XCTAssertEqual(map.position, .zero)
            XCTAssertEqual(map.anchorPoint, CGPoint(x: 0.5, y: 0.5))
            XCTAssertTrue(map.enableAutomapping)
            XCTAssertEqual(map.name, "Default Tile Map")
        }
        XCTAssertEqual(maps(abc, 4, 3, noiseMap(vector_int2(4, 3)) { _, _ in 0 }, []).map(layout), ["aaaa/aaaa/aaaa"])
    }

    func testTheFirstMapIsFullAndMapKHoldsGroupKFromThresholdKMinusOneUp() {
        let expected: [Float: [String]] = [
            -1: ["aaaa/aaaa/aaaa", "----/----/----", "----/----/----"],
            -0.6: ["aaaa/aaaa/aaaa", "----/----/----", "----/----/----"],
            -0.5: ["aaaa/aaaa/aaaa", "bbbb/bbbb/bbbb", "----/----/----"],
            0.2: ["aaaa/aaaa/aaaa", "bbbb/bbbb/bbbb", "----/----/----"],
            0.5: ["aaaa/aaaa/aaaa", "bbbb/bbbb/bbbb", "cccc/cccc/cccc"],
            1: ["aaaa/aaaa/aaaa", "bbbb/bbbb/bbbb", "cccc/cccc/cccc"],
        ]
        for (value, layouts) in expected {
            let noise = noiseMap(vector_int2(4, 3)) { _, _ in value }
            XCTAssertEqual(maps(abc, 4, 3, noise, [-0.5, 0.5]).map(layout), layouts, "noise \(value)")
        }
    }

    func testMapsBeyondTheTileSetsGroupsAreEmpty() {
        let two = SKTileSet(tileGroups: [group("a"), group("b")])
        let noise = noiseMap(vector_int2(4, 3)) { _, _ in 1 }
        XCTAssertEqual(maps(two, 4, 3, noise, [-0.5, 0, 0.5]).map(layout), ["aaaa/aaaa/aaaa", "bbbb/bbbb/bbbb", "----/----/----", "----/----/----"])
    }

    /// The noise value a cell is compared with, found by bisecting the threshold.
    private func cellValues(_ noise: GKNoiseMap, _ columns: Int, _ rows: Int) -> [[Float]] {
        let set = SKTileSet(tileGroups: [group("a"), group("b")])
        var low = Array(repeating: Array(repeating: Float(-2), count: columns), count: rows)
        var high = Array(repeating: Array(repeating: Float(2), count: columns), count: rows)
        for _ in 0..<24 {
            var middle = low
            for row in 0..<rows { for column in 0..<columns { middle[row][column] = (low[row][column] + high[row][column]) / 2 } }
            for row in 0..<rows {
                for column in 0..<columns {
                    let generated = maps(set, columns, rows, noise, [Double(middle[row][column])])
                    if generated[1].tileGroup(atColumn: column, row: row) != nil {
                        low[row][column] = middle[row][column]
                    } else {
                        high[row][column] = middle[row][column]
                    }
                }
            }
        }
        return low
    }

    /// The model: the mean of [field] at 3 × 3 points across the cell, at 1/6, 1/2 and 5/6 of it,
    /// in sample coordinates clamped to the last sample, interpolated linearly between samples.
    private func model(_ field: (Float) -> Float, samples: Int, cells: Int, cell: Int) -> Float {
        let points = [1.0 / 6, 0.5, 5.0 / 6].map { (Float(cell) + Float($0)) * Float(samples) / Float(cells) }
        func sampled(_ x: Float) -> Float {
            let clamped = min(x, Float(samples - 1))
            let x0 = Int(clamped.rounded(.down))
            let x1 = min(x0 + 1, samples - 1)
            let t = clamped - Float(x0)
            return field(Float(x0)) * (1 - t) + field(Float(x1)) * t
        }
        return points.map(sampled).reduce(0, +) / 3
    }

    func testEachCellIsTheMeanOfThreeByThreeBilinearSamples() {
        let fields: [(String, (Float) -> Float)] = [("x", { $0 * 0.1 }), ("x²", { $0 * $0 * 0.01 })]
        for (name, field) in fields {
            for samples in [2, 3, 5, 8] {
                for cells in [1, 2, 3, 4, 8] {
                    let across = cellValues(noiseMap(vector_int2(Int32(samples), 2)) { x, _ in field(Float(x)) }, cells, 1)[0]
                    for cell in 0..<cells {
                        XCTAssertEqual(across[cell], model(field, samples: samples, cells: cells, cell: cell), accuracy: 1e-4, "\(name), \(samples) samples, cell \(cell) of \(cells)")
                    }
                    // The same along y.
                    let up = cellValues(noiseMap(vector_int2(2, Int32(samples))) { _, y in field(Float(y)) }, 1, cells).map { $0[0] }
                    for cell in 0..<cells {
                        XCTAssertEqual(up[cell], model(field, samples: samples, cells: cells, cell: cell), accuracy: 1e-4, "\(name) along y, \(samples) samples, cell \(cell) of \(cells)")
                    }
                }
            }
        }
    }
}
