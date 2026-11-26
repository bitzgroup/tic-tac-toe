import SpriteKit
import XCTest

/// Records Apple's `SKTileMapNode.fill(with:)`, `mapSize`, `color`/`colorBlendFactor`/`blendMode`,
/// `SKTileGroup.empty()` and `SKTileDefinition.placementWeight`, which bitzgroup/SpriteKit mirrors.
final class SKTileMapParityTests: XCTestCase {
    private func texture(_ color: UIColor) -> SKTexture {
        SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 8, height: 8)).image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 8, height: 8))
        })
    }

    private func rgba(_ color: UIColor) -> [CGFloat] {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return [r, g, b, a]
    }

    private func definition(_ color: UIColor = .white) -> SKTileDefinition {
        SKTileDefinition(texture: texture(color), size: CGSize(width: 10, height: 10))
    }

    private func map(_ group: SKTileGroup, columns: Int = 3, rows: Int = 2) -> SKTileMapNode {
        SKTileMapNode(
            tileSet: SKTileSet(tileGroups: [group]), columns: columns, rows: rows,
            tileSize: CGSize(width: 10, height: 10)
        )
    }

    func testDefaults() {
        let map = map(SKTileGroup(tileDefinition: definition()))
        XCTAssertTrue(map.enableAutomapping)
        XCTAssertEqual(rgba(map.color), [1, 1, 1, 1])
        XCTAssertEqual(map.colorBlendFactor, 0)
        XCTAssertEqual(map.blendMode, .alpha)
        XCTAssertEqual(definition().placementWeight, 1)
    }

    func testAGridMapsSizeIsItsUnscaledTiles() {
        let group = SKTileGroup(tileDefinition: definition())
        let map = SKTileMapNode(
            tileSet: SKTileSet(tileGroups: [group]), columns: 4, rows: 5, tileSize: CGSize(width: 10, height: 12)
        )
        XCTAssertEqual(map.mapSize, CGSize(width: 40, height: 60))
        map.setScale(2)
        XCTAssertEqual(map.mapSize, CGSize(width: 40, height: 60))
        XCTAssertEqual(map.frame.size, CGSize(width: 80, height: 120))
    }

    func testFillSetsEveryCellToTheGroupsFirstRuleEvenWhenAutomapping() {
        let edge = definition(.blue)
        let center = definition(.red)
        let group = SKTileGroup(rules: [
            SKTileGroupRule(adjacency: .adjacencyUp, tileDefinitions: [edge]),
            SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [center]),
        ])
        for automapping in [false, true] {
            let map = map(group, columns: 3, rows: 3)
            map.enableAutomapping = automapping
            map.fill(with: group)
            for row in 0..<3 {
                for column in 0..<3 {
                    XCTAssertTrue(map.tileGroup(atColumn: column, row: row) === group)
                    XCTAssertTrue(map.tileDefinition(atColumn: column, row: row) === edge)
                }
            }
            map.fill(with: nil)
            XCTAssertNil(map.tileGroup(atColumn: 1, row: 1))
            XCTAssertNil(map.tileDefinition(atColumn: 1, row: 1))
        }
    }

    func testTheFillingInitializerFillsLikeFill() {
        let edge = definition(.blue)
        let center = definition(.red)
        let group = SKTileGroup(rules: [
            SKTileGroupRule(adjacency: .adjacencyUp, tileDefinitions: [edge]),
            SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [center]),
        ])
        let map = SKTileMapNode(
            tileSet: SKTileSet(tileGroups: [group]), columns: 3, rows: 3,
            tileSize: CGSize(width: 10, height: 10), fillWith: group
        )
        XCTAssertTrue(map.enableAutomapping)
        for row in 0..<3 {
            for column in 0..<3 {
                XCTAssertTrue(map.tileDefinition(atColumn: column, row: row) === edge)
            }
        }
    }

    func testTheEmptyGroupHasNoRulesAndClearsACell() {
        let empty = SKTileGroup.empty()
        XCTAssertEqual(empty.rules.count, 0)
        XCTAssertNil(empty.name)
        XCTAssertFalse(SKTileGroup.empty() === SKTileGroup.empty())

        let group = SKTileGroup(tileDefinition: definition())
        let map = map(group)
        map.fill(with: group)
        map.setTileGroup(empty, forColumn: 1, row: 1)
        XCTAssertNil(map.tileGroup(atColumn: 1, row: 1))
        XCTAssertNil(map.tileDefinition(atColumn: 1, row: 1))
        map.fill(with: empty)
        XCTAssertNil(map.tileGroup(atColumn: 0, row: 0))
    }

    func testATileGroupFromOneDefinitionMatchesEveryNeighborhood() {
        let only = definition()
        let group = SKTileGroup(tileDefinition: only)
        XCTAssertEqual(group.rules.count, 1)
        XCTAssertEqual(group.rules[0].adjacency, .adjacencyAll)
        XCTAssertTrue(group.rules[0].tileDefinitions == [only])
    }

    /// How often each of two definitions in one rule is placed over a 40 × 40 fill, with the
    /// given placement weights.
    private func placements(_ weightA: Int, _ weightB: Int, automapping: Bool) -> (Int, Int) {
        let a = definition(.red)
        let b = definition(.blue)
        a.placementWeight = weightA
        b.placementWeight = weightB
        let group = SKTileGroup(rules: [SKTileGroupRule(adjacency: .adjacencyAll, tileDefinitions: [a, b])])
        let map = map(group, columns: 40, rows: 40)
        map.enableAutomapping = automapping
        map.fill(with: group)
        var countA = 0
        var countB = 0
        for row in 0..<40 {
            for column in 0..<40 {
                let placed = map.tileDefinition(atColumn: column, row: row)
                if placed === a { countA += 1 } else if placed === b { countB += 1 }
            }
        }
        XCTAssertEqual(countA + countB, 1600)
        return (countA, countB)
    }

    func testPlacementWeightsChooseBetweenARulesDefinitions() {
        for automapping in [false, true] {
            XCTAssertEqual(placements(1, 0, automapping: automapping).1, 0)
            XCTAssertEqual(placements(0, 1, automapping: automapping).0, 0)
            let even = placements(1, 1, automapping: automapping)
            XCTAssertEqual(Double(even.0) / 1600, 0.5, accuracy: 0.06)
            let threeToOne = placements(3, 1, automapping: automapping)
            XCTAssertEqual(Double(threeToOne.0) / 1600, 0.75, accuracy: 0.06)
            // With every weight 0, Apple picks evenly.
            let zeros = placements(0, 0, automapping: automapping)
            XCTAssertEqual(Double(zeros.0) / 1600, 0.5, accuracy: 0.06)
        }
    }

    func testColorIsStoredButNotDrawnWhileBlendModeIs() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        defer { window.isHidden = true }
        let scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)

        let grey = SKTileDefinition(
            texture: texture(UIColor(white: 0.5, alpha: 1)), size: CGSize(width: 20, height: 20)
        )
        let group = SKTileGroup(tileDefinition: grey)
        let map = SKTileMapNode(
            tileSet: SKTileSet(tileGroups: [group]), columns: 1, rows: 1, tileSize: CGSize(width: 20, height: 20)
        )
        map.fill(with: group)
        let background = SKSpriteNode(color: .blue, size: CGSize(width: 20, height: 20))
        background.addChild(map)
        scene.addChild(background)

        func centerPixel() -> [UInt8] {
            let image = view.texture(from: background)!.cgImage()
            var pixels = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = CGContext(
                data: &pixels, width: image.width, height: image.height, bitsPerComponent: 8,
                bytesPerRow: image.width * 4, space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let i = ((image.height / 2) * image.width + image.width / 2) * 4
            return Array(pixels[i..<i + 3])
        }

        XCTAssertEqual(centerPixel(), [128, 128, 128])
        map.color = .red
        map.colorBlendFactor = 1
        XCTAssertEqual(rgba(map.color), [1, 0, 0, 1])
        XCTAssertEqual(map.colorBlendFactor, 1)
        XCTAssertEqual(centerPixel(), [128, 128, 128])
        map.blendMode = .add
        XCTAssertEqual(centerPixel(), [128, 128, 255])
    }
}
