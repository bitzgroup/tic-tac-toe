import SpriteKit
import XCTest

/// Records Apple's `SKNode` child-list API — `insertChild(_:at:)`, `removeChildren(in:)`,
/// `inParentHierarchy(_:)`, `move(toParent:)` — and `SKSpriteNode.scale(to:)`, which
/// bitzgroup/SpriteKit mirrors.
final class SKNodeHierarchyParityTests: XCTestCase {
    private func named(_ name: String) -> SKNode {
        let node = SKNode()
        node.name = name
        return node
    }

    func testInsertChildAtPutsItAtThatIndexIncludingTheEnd() {
        let parent = SKNode()
        parent.addChild(named("a"))
        parent.addChild(named("b"))
        parent.insertChild(named("c"), at: 1)
        XCTAssertEqual(parent.children.map(\.name), ["a", "c", "b"])
        parent.insertChild(named("d"), at: 3)
        XCTAssertEqual(parent.children.map(\.name), ["a", "c", "b", "d"])
        // An index past the end raises (NSRangeException) — not recorded as a test, since it crashes.
    }

    func testRemoveChildrenInRemovesOnlyThoseThatAreChildren() {
        let parent = SKNode()
        let a = named("a")
        let b = named("b")
        parent.addChild(a)
        parent.addChild(b)
        parent.removeChildren(in: [a, SKNode()])
        XCTAssertEqual(parent.children.map(\.name), ["b"])
        XCTAssertNil(a.parent)
    }

    func testInParentHierarchyIsTrueForAnyAncestorButNotTheNodeItself() {
        let root = SKNode()
        let child = SKNode()
        let grandchild = SKNode()
        root.addChild(child)
        child.addChild(grandchild)
        XCTAssertTrue(child.inParentHierarchy(root))
        XCTAssertTrue(grandchild.inParentHierarchy(root))
        XCTAssertFalse(root.inParentHierarchy(child))
        XCTAssertFalse(child.inParentHierarchy(child))
    }

    func testMoveToParentKeepsTheScenePositionButNotTheRotationOrScale() {
        let scene = SKScene(size: CGSize(width: 400, height: 400))
        let from = SKNode()
        from.position = CGPoint(x: 100, y: 50)
        from.zRotation = .pi / 2
        from.xScale = 2
        from.yScale = 3
        let to = SKNode()
        to.position = CGPoint(x: -20, y: 10)
        to.xScale = 0.5
        scene.addChild(from)
        scene.addChild(to)
        to.addChild(SKNode())
        let node = SKNode()
        node.position = CGPoint(x: 10, y: 0)
        node.zRotation = 0.3
        node.xScale = 1.5
        from.addChild(node)
        XCTAssertEqual(scene.convert(node.position, from: from), CGPoint(x: 100, y: 70))

        node.move(toParent: to)

        XCTAssertTrue(node.parent === to)
        XCTAssertTrue(to.children.last === node)
        XCTAssertEqual(node.position.x, 240, accuracy: 0.001)
        XCTAssertEqual(node.position.y, 60, accuracy: 0.001)
        XCTAssertEqual(node.zRotation, 0.3, accuracy: 0.0001)
        XCTAssertEqual(node.xScale, 1.5)
    }

    func testMoveToParentTreatsEachTreesRootAsTheSharedSpace() {
        let target = SKNode()
        target.position = CGPoint(x: -20, y: 10)
        target.xScale = 0.5

        let orphan = SKNode()
        orphan.position = CGPoint(x: 5, y: 6)
        orphan.move(toParent: target)
        XCTAssertEqual(orphan.position, CGPoint(x: 50, y: -4))

        let otherRoot = SKNode()
        otherRoot.position = CGPoint(x: 10, y: 10)
        let inOtherTree = SKNode()
        inOtherTree.position = CGPoint(x: 3, y: 4)
        otherRoot.addChild(inOtherTree)
        let unrooted = SKNode()
        unrooted.position = CGPoint(x: 1, y: 1)
        inOtherTree.move(toParent: unrooted)
        XCTAssertEqual(inOtherTree.position, CGPoint(x: 12, y: 13))
    }

    func testSpriteScaleToSetsTheScaleForThatSizeWhateverTheCurrentScaleOrRotation() {
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        sprite.xScale = 3
        sprite.zRotation = .pi / 2
        sprite.scale(to: CGSize(width: 40, height: 10))
        XCTAssertEqual(sprite.xScale, 4, accuracy: 0.001)
        XCTAssertEqual(sprite.yScale, 0.5, accuracy: 0.001)
        // A sprite's `size` includes its scale (see SKSpriteSizeParityTests).
        XCTAssertEqual(sprite.size, CGSize(width: 40, height: 10))
    }
}
