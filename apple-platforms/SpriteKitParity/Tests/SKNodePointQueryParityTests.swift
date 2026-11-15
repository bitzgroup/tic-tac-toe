import SpriteKit
import XCTest

/// Records Apple's `frame`/`contains(_:)`/`nodes(at:)`/`atPoint(_:)` semantics — the behavior
/// bitzgroup/SpriteKit's `SKNodePointQueryTest` expects, with the same node layouts.
final class SKNodePointQueryParityTests: XCTestCase {
    private func sprite(_ name: String, _ size: CGFloat, _ x: CGFloat, _ y: CGFloat) -> SKSpriteNode {
        let node = SKSpriteNode(color: .red, size: CGSize(width: size, height: size))
        node.name = name
        node.position = CGPoint(x: x, y: y)
        return node
    }

    private func names(_ nodes: [SKNode]) -> [String] { nodes.map { $0.name ?? "?" } }

    func testFrameOfAPlainNodeIsZeroSizeAtItsPosition() {
        let scene = SKScene(size: CGSize(width: 400, height: 400))
        let plain = SKNode()
        plain.position = CGPoint(x: 10, y: 20)
        scene.addChild(plain)
        XCTAssertEqual(plain.frame, CGRect(x: 10, y: 20, width: 0, height: 0))
    }

    func testFrameExcludesChildrenAndBoundsARotatedScaledNode() {
        let scene = SKScene(size: CGSize(width: 400, height: 400))
        let a = sprite("a", 100, 200, 200)
        a.addChild(sprite("b", 40, 80, 0))
        scene.addChild(a)
        XCTAssertEqual(a.frame, CGRect(x: 150, y: 150, width: 100, height: 100))
        a.setScale(2)
        a.zRotation = .pi / 4
        XCTAssertEqual(a.frame.minX, 58.579, accuracy: 0.01)
        XCTAssertEqual(a.frame.width, 282.843, accuracy: 0.01)
    }

    func testContainsUsesTheAccumulatedFrameWithHalfOpenEdges() {
        let scene = SKScene(size: CGSize(width: 400, height: 400))
        let a = sprite("a", 100, 200, 200)
        a.addChild(sprite("b", 40, 80, 0))
        scene.addChild(a)
        let sp = sprite("sp", 20, 50, 50)
        scene.addChild(sp)
        XCTAssertTrue(a.contains(CGPoint(x: 285, y: 200)))
        XCTAssertTrue(sp.contains(CGPoint(x: 40, y: 50)))
        XCTAssertFalse(sp.contains(CGPoint(x: 60, y: 50)))
        let plain = SKNode()
        scene.addChild(plain)
        XCTAssertFalse(plain.contains(.zero))
    }

    func testOrderingByZPositionThenChildrenAndLaterSiblingsInFront() {
        let scene = SKScene(size: CGSize(width: 400, height: 400))
        let a = sprite("a", 100, 200, 200)
        a.addChild(sprite("b", 40, 80, 0))
        let c = sprite("c", 100, 220, 200)
        c.zPosition = -1
        scene.addChild(a)
        scene.addChild(c)
        XCTAssertEqual(scene.atPoint(CGPoint(x: 280, y: 200)).name, "b")
        XCTAssertEqual(names(scene.nodes(at: CGPoint(x: 280, y: 200))), ["b", "a"])
        XCTAssertEqual(scene.atPoint(CGPoint(x: 210, y: 200)).name, "a")
        c.zPosition = 0
        XCTAssertEqual(scene.atPoint(CGPoint(x: 210, y: 200)).name, "c")
        XCTAssertEqual(names(scene.nodes(at: CGPoint(x: 210, y: 200))), ["c", "a"])
    }

    func testAtPointFallsBackToTheReceiverAndNodesExcludesIt() {
        let scene = SKScene(size: CGSize(width: 400, height: 400))
        scene.addChild(sprite("a", 100, 200, 200))
        XCTAssertTrue(scene.atPoint(CGPoint(x: 5, y: 5)) === scene)
        XCTAssertTrue(scene.atPoint(CGPoint(x: -50, y: -50)) === scene)
        XCTAssertEqual(scene.nodes(at: CGPoint(x: 5, y: 5)).count, 0)
    }

    func testHiddenAndFullyTransparentSubtreesAreSkipped() {
        let scene = SKScene(size: CGSize(width: 400, height: 400))
        let bg = sprite("bg", 400, 200, 200)
        let p = sprite("p", 100, 200, 200)
        p.addChild(sprite("c", 20, 0, 0))
        scene.addChild(bg)
        scene.addChild(p)
        let point = CGPoint(x: 200, y: 200)
        p.alpha = 0
        XCTAssertEqual(names(scene.nodes(at: point)), ["bg"])
        p.alpha = 1
        p.isHidden = true
        XCTAssertEqual(names(scene.nodes(at: point)), ["bg"])
        p.isHidden = false
        p.children[0].alpha = 0
        XCTAssertEqual(names(scene.nodes(at: point)), ["p", "bg"])
        p.children[0].alpha = 1
        p.zPosition = -5
        XCTAssertEqual(names(scene.nodes(at: point)), ["bg", "c", "p"])
    }

    func testAContainerIsFoundInGapsBetweenItsChildrenAndAPlainNodeAtItsPosition() {
        let scene = SKScene(size: CGSize(width: 400, height: 400))
        let g = SKNode()
        g.name = "g"
        g.position = CGPoint(x: 200, y: 200)
        g.addChild(sprite("s0", 20, -100, 0))
        g.addChild(sprite("s1", 20, 100, 0))
        scene.addChild(g)
        let plain = SKNode()
        plain.name = "plain"
        plain.position = CGPoint(x: 50, y: 350)
        scene.addChild(plain)
        XCTAssertEqual(scene.atPoint(CGPoint(x: 210, y: 200)).name, "g")
        XCTAssertEqual(names(scene.nodes(at: CGPoint(x: 300, y: 200))), ["s1", "g"])
        XCTAssertEqual(scene.atPoint(CGPoint(x: 50, y: 350)).name, "plain")
    }
}
