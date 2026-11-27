import SpriteKit
import XCTest

/// Records how Apple's physics bodies follow their node's scale, which bitzgroup/SpriteKit
/// (PARITY_GAP_PLAN.md P8) mirrors. A node's own scale counts only relative to its scale when
/// the body was attached; its ancestors' scale counts in full; a circle stays a circle, of
/// radius `r·√((sx² + sy²)/2)` under a non-uniform scale. Queries and contacts agree.
final class SKPhysicsScaleParityTests: SKPhysicsParityTestCase, SKPhysicsContactDelegate {
    private var ball: SKNode?
    private var ballXAtContact: CGFloat?

    func didBegin(_ contact: SKPhysicsContact) {
        if ballXAtContact == nil { ballXAtContact = ball?.position.x }
    }

    private let center = CGPoint(x: 200, y: 200)

    private func circle(scale: CGFloat = 1) -> SKNode {
        let node = SKNode()
        node.position = center
        node.setScale(scale)
        node.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        node.physicsBody?.isDynamic = false
        scene.addChild(node)
        return node
    }

    /// Asserts a body reaches [inside] points from the center along (dx, dy), but not [outside].
    private func assertReach(
        _ inside: CGFloat,
        not outside: CGFloat,
        dx: CGFloat = 1,
        dy: CGFloat = 0,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        runFrames(0.1)
        let at = { (d: CGFloat) in CGPoint(x: self.center.x + dx * d, y: self.center.y + dy * d) }
        XCTAssertNotNil(world.body(at: at(inside)), "at \(inside)", file: file, line: line)
        XCTAssertNil(world.body(at: at(outside)), "at \(outside)", file: file, line: line)
    }

    func testANodesOwnScaleCountsOnlyFromWhenItsBodyWasAttached() {
        let node = circle(scale: 2)
        assertReach(9, not: 11)
        node.setScale(4)
        assertReach(19, not: 21)
        node.setScale(1)
        assertReach(4.5, not: 6)
    }

    func testScalingANodeAfterAttachingItsBodyScalesTheBody() {
        let node = circle()
        runFrames(0.1)
        node.setScale(2)
        assertReach(19, not: 21)
    }

    func testAnAncestorsScaleCountsInFull() {
        let parent = SKNode()
        parent.position = center
        parent.setScale(2)
        scene.addChild(parent)
        let child = SKNode()
        child.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        child.physicsBody?.isDynamic = false
        parent.addChild(child)
        assertReach(19, not: 21)
    }

    func testABodyMovedToAnotherNodeTakesThatNodesScaleAsItsOwn() {
        let first = circle()
        runFrames(0.1)
        let second = SKNode()
        second.position = center
        second.setScale(3)
        scene.addChild(second)
        let body = first.physicsBody
        first.physicsBody = nil
        first.removeFromParent()
        second.physicsBody = body
        assertReach(9, not: 11)
    }

    func testACopysBodyCountsTheCopysScaleWhenItWasMade() {
        let original = circle()
        runFrames(0.1)
        original.setScale(2)
        let copy = original.copy() as! SKNode
        original.removeFromParent()
        scene.addChild(copy)
        assertReach(9, not: 11)
        copy.setScale(1)
        assertReach(4.5, not: 6)
    }

    func testACircleUnderANonUniformScaleKeepsTheMeanSquareOfTheTwoStretches() {
        let node = circle()
        runFrames(0.1)
        node.xScale = 3 // radius 10·√5 ≈ 22.4 both ways
        assertReach(22, not: 23)
        assertReach(22, not: 23, dx: 0, dy: 1)
    }

    func testARectangleStretchesAlongEachAxis() {
        let node = SKNode()
        node.position = center
        node.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 20))
        node.physicsBody?.isDynamic = false
        scene.addChild(node)
        runFrames(0.1)
        node.xScale = 2
        assertReach(19, not: 21)
        assertReach(9, not: 11, dx: 0, dy: 1)
        node.zRotation = .pi / 2
        assertReach(9, not: 11)
        assertReach(19, not: 21, dx: 0, dy: 1)
    }

    /// Where a radius-5 ball moving along +x at 100 points/s first touches a radius-10 circle at
    /// x 250, set up by [configure] before and [adjust] after its body is attached.
    private func ballXAtContact(
        configure: (SKNode) -> Void = { _ in },
        adjust: (SKNode) -> Void = { _ in }
    ) -> CGFloat? {
        ballXAtContact = nil
        world.contactDelegate = self
        let target = SKNode()
        target.position = CGPoint(x: 250, y: 200)
        configure(target)
        target.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        target.physicsBody?.isDynamic = false
        target.physicsBody?.contactTestBitMask = 1
        scene.addChild(target)
        adjust(target)
        let moving = SKNode()
        moving.position = CGPoint(x: 100, y: 200)
        moving.physicsBody = SKPhysicsBody(circleOfRadius: 5)
        moving.physicsBody?.contactTestBitMask = 1
        moving.physicsBody?.linearDamping = 0
        moving.physicsBody?.velocity = CGVector(dx: 100, dy: 0)
        scene.addChild(moving)
        ball = moving
        runFrames(2)
        moving.removeFromParent()
        target.removeFromParent()
        return ballXAtContact
    }

    func testContactsUseTheSameScaledShape() throws {
        // Touching at a gap of 15 (unscaled), 25 (scale 2) or 5 + 10·√5 (x scale 3).
        XCTAssertEqual(try XCTUnwrap(ballXAtContact()), 235, accuracy: 2)
        XCTAssertEqual(try XCTUnwrap(ballXAtContact(configure: { $0.setScale(2) })), 235, accuracy: 2)
        XCTAssertEqual(try XCTUnwrap(ballXAtContact(adjust: { $0.setScale(2) })), 225, accuracy: 2)
        XCTAssertEqual(try XCTUnwrap(ballXAtContact(adjust: { $0.xScale = 3 })), 250 - 5 - 10 * sqrt(5), accuracy: 2)
    }
}
