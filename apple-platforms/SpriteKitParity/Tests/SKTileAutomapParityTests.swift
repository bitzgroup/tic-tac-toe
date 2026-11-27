import SpriteKit
import XCTest

/// Records how Apple's automapping picks each tile's rule, which bitzgroup/SpriteKit's
/// closest-mask matching doesn't mirror (its `docs/PARITY_GAP_PLAN.md`, M2).
final class SKTileAutomapParityTests: XCTestCase {
    /// The 13 masks of an Xcode adjacency tile group: the center, eight edges and four inner corners.
    private let standardRules: [(String, SKTileAdjacencyMask)] = [
        ("All", .adjacencyAll),
        ("UpE", .adjacencyUpEdge), ("URE", .adjacencyUpperRightEdge), ("RE", .adjacencyRightEdge),
        ("LRE", .adjacencyLowerRightEdge), ("DE", .adjacencyDownEdge), ("LLE", .adjacencyLowerLeftEdge),
        ("LE", .adjacencyLeftEdge), ("ULE", .adjacencyUpperLeftEdge),
        ("URC", .adjacencyUpperRightCorner), ("LRC", .adjacencyLowerRightCorner),
        ("LLC", .adjacencyLowerLeftCorner), ("ULC", .adjacencyUpperLeftCorner),
    ]

    /// One rule for each of the 256 masks, named by its raw value.
    private var everyMaskRules: [(String, SKTileAdjacencyMask)] {
        (0..<256).map { (String($0), SKTileAdjacencyMask(rawValue: UInt($0))) }
    }

    /// A group whose rules each hold one definition named like the rule.
    private func group(_ rules: [(String, SKTileAdjacencyMask)]) -> SKTileGroup {
        SKTileGroup(rules: rules.map { name, mask in
            let definition = SKTileDefinition(texture: SKTexture(), size: CGSize(width: 10, height: 10))
            definition.name = name
            return SKTileGroupRule(adjacency: mask, tileDefinitions: [definition])
        })
    }

    /// A 7 × 7 map after placing `group` at each of `cells` in order, as rows from the top: `.` for
    /// no tile, a definition's name, or `nil` for a tile with a group but no definition.
    private func paint(_ rules: [(String, SKTileAdjacencyMask)], _ cells: [(column: Int, row: Int)]) -> [String] {
        let group = group(rules)
        let map = SKTileMapNode(
            tileSet: SKTileSet(tileGroups: [group]), columns: 7, rows: 7, tileSize: CGSize(width: 10, height: 10)
        )
        for (column, row) in cells { map.setTileGroup(group, forColumn: column, row: row) }
        return (0..<7).reversed().map { row in
            (0..<7).map { column -> String in
                guard map.tileGroup(atColumn: column, row: row) != nil else { return "." }
                return map.tileDefinition(atColumn: column, row: row)?.name ?? "nil"
            }.joined(separator: " ")
        }
    }

    private let block: [(column: Int, row: Int)] = (2...4).flatMap { row in (2...4).map { (column: $0, row: row) } }

    /// With a rule for every mask, each tile takes the rule for its same-group edge neighbors
    /// (up 1, right 4, down 16, left 64); diagonal neighbors never count, and the order tiles are
    /// placed in doesn't matter. Nothing is painted beyond the placed cells.
    func testWithARuleForEveryMaskATileMatchesItsEdgeNeighbors() {
        let blockGrid = [
            ". . . . . . .",
            ". . . . . . .",
            ". . 20 84 80 . .",
            ". . 21 85 81 . .",
            ". . 5 69 65 . .",
            ". . . . . . .",
            ". . . . . . .",
        ]
        XCTAssertEqual(paint(everyMaskRules, block), blockGrid)
        XCTAssertEqual(paint(everyMaskRules, block.reversed()), blockGrid)
        XCTAssertEqual(paint(everyMaskRules, [(2, 2), (3, 3)]), [
            ". . . . . . .",
            ". . . . . . .",
            ". . . . . . .",
            ". . . 0 . . .",
            ". . 0 . . . .",
            ". . . . . . .",
            ". . . . . . .",
        ])
    }

    /// With an adjacency group's rules, placing one tile paints its whole neighborhood: the cell
    /// takes the center rule and its eight neighbors the edge rules around it. Placing the group
    /// on a cell that already holds it changes nothing.
    func testWithAdjacencyRulesATilePaintsItsNeighbors() {
        XCTAssertEqual(paint(standardRules, [(3, 3)]), [
            ". . . . . . .",
            ". . . . . . .",
            ". . ULE UpE URE . .",
            ". . LE All RE . .",
            ". . LLE DE LRE . .",
            ". . . . . . .",
            ". . . . . . .",
        ])
        // The second tile lands on a cell already holding the group's right-edge tile, and
        // nothing changes.
        XCTAssertEqual(paint(standardRules, [(2, 3), (3, 3)]), [
            ". . . . . . .",
            ". . . . . . .",
            ". ULE UpE URE . . .",
            ". LE All RE . . .",
            ". LLE DE LRE . . .",
            ". . . . . . .",
            ". . . . . . .",
        ])
    }

    /// Placing a 3 × 3 block one tile at a time, row by row from the bottom, leaves an uneven
    /// shape, since a tile placed where the group already shows changes nothing there.
    func testWithAdjacencyRulesABlockPaintsUnevenly() {
        XCTAssertEqual(paint(standardRules, block), [
            ". . . . . . .",
            ". ULE UpE URE . . .",
            ". LE All LLC URE . .",
            ". LE All All LLC URE .",
            ". LE All All All RE .",
            ". LLE DE DE DE LRE .",
            ". . . . . . .",
        ])
    }

    /// With rules for only some masks, a tile no rule fits keeps its group but gets no definition.
    func testATileNoRuleFitsHasNoDefinition() {
        XCTAssertEqual(paint([("U", .adjacencyUp), ("All", .adjacencyAll)], [(3, 3)])[3], ". . . nil . . .")
    }
}
