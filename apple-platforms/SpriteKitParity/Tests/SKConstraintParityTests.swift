import SpriteKit
import XCTest

/// Records how `SKConstraint.referenceNode` and the point-based `distance`/`orient` constraints
/// behave — bitzgroup/SpriteKit (PARITY_GAP_PLAN.md C2) mirrors them. Position and distance
/// ranges are measured in the reference node's coordinates (the parent's by default), and a
/// point target is in the parent's coordinates unless another node is given.
///
/// The last tests record where Apple's results don't follow that model (PARITY_GAP_PLAN.md C3),
/// which the port doesn't mirror.
final class SKConstraintParityTests: XCTestCase {
    private var window: UIWindow!
    private var view: SKView!
    private var scene: SKScene!

    override func setUp() {
        super.setUp()
        view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)
        runFrames()
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        view = nil
        scene = nil
        super.tearDown()
    }

    private func runFrames(_ seconds: Double = 0.2) {
        let done = expectation(description: "frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    /// Constrains a fresh node at the origin of a parent placed at (100, 0) — so parent and
    /// scene coordinates differ — and returns it after a few frames.
    private func constrained(
        configure: (_ parent: SKNode, _ child: SKNode) -> Void = { _, _ in },
        _ constraint: SKConstraint
    ) -> SKNode {
        let parent = SKNode()
        parent.position = CGPoint(x: 100, y: 0)
        scene.addChild(parent)
        let child = SKNode()
        parent.addChild(child)
        configure(parent, child)
        child.constraints = [constraint]
        runFrames()
        return child
    }

    private func node(at position: CGPoint = .zero, scale: CGFloat = 1, rotation: CGFloat = 0) -> SKNode {
        let node = SKNode()
        node.position = position
        node.setScale(scale)
        node.zRotation = rotation
        scene.addChild(node)
        return node
    }

    private func referenced(_ constraint: SKConstraint, _ reference: SKNode) -> SKConstraint {
        constraint.referenceNode = reference
        return constraint
    }

    private func assertPosition(
        _ node: SKNode,
        _ expected: CGPoint,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(node.position.x, expected.x, accuracy: 0.001, file: file, line: line)
        XCTAssertEqual(node.position.y, expected.y, accuracy: 0.001, file: file, line: line)
    }

    func testReferenceNodeDefaultsToNil() {
        XCTAssertNil(SKConstraint.positionX(SKRange(lowerLimit: 0, upperLimit: 10)).referenceNode)
    }

    func testPositionRangesAreMeasuredInTheReferenceNodesCoordinates() {
        let range = SKRange(lowerLimit: 0, upperLimit: 10)
        assertPosition(constrained(referenced(.positionX(range), scene)), CGPoint(x: -90, y: 0))
        // Scene x 100 is 25 in a reference at x 50 scaled by 2, clamped to 10: scene x 70.
        let scaled = node(at: CGPoint(x: 50, y: 0), scale: 2)
        assertPosition(constrained(referenced(.positionX(range), scaled)), CGPoint(x: -30, y: 0))
        // A reference rotated a quarter turn measures its x along the scene's y.
        let rotated = node(rotation: .pi / 2)
        assertPosition(
            constrained(
                configure: { _, child in child.position = CGPoint(x: 0, y: 30) },
                referenced(.positionX(range), rotated)
            ),
            CGPoint(x: 0, y: 10)
        )
    }

    func testZRotationRangesFollowAReferenceNodeRotatedFurtherThanTheParent() {
        let reference = node(rotation: 1)
        let child = constrained(referenced(.zRotation(SKRange(lowerLimit: 0.2, upperLimit: 0.3)), reference))
        XCTAssertEqual(child.zRotation, 1.2, accuracy: 0.001)
    }

    func testDistanceToAPointUsesTheParentsCoordinatesUnlessGivenANode() {
        assertPosition(
            constrained(.distance(SKRange(upperLimit: 20), to: CGPoint(x: 0, y: 100))),
            CGPoint(x: 0, y: 80)
        )
        assertPosition(
            constrained(.distance(SKRange(constantValue: 0), to: CGPoint(x: 10, y: 10), in: scene)),
            CGPoint(x: -90, y: 10)
        )
        // (10, 10) in a node at (0, 50) scaled by 2 is (20, 70) in the scene.
        let other = node(at: CGPoint(x: 0, y: 50), scale: 2)
        assertPosition(
            constrained(.distance(SKRange(constantValue: 0), to: CGPoint(x: 10, y: 10), in: other)),
            CGPoint(x: -80, y: 70)
        )
    }

    func testDistanceIsMeasuredInTheReferenceNodesCoordinates() {
        let target = node()
        let scaleParent: (SKNode, SKNode) -> Void = { parent, child in
            parent.position = .zero
            parent.setScale(2)
            child.position = CGPoint(x: 100, y: 0)
        }
        // 20 in the parent's (doubled) coordinates by default; 20 scene points with the scene.
        assertPosition(
            constrained(configure: scaleParent, .distance(SKRange(upperLimit: 20), to: target)),
            CGPoint(x: 20, y: 0)
        )
        assertPosition(
            constrained(configure: scaleParent, referenced(.distance(SKRange(upperLimit: 20), to: target), scene)),
            CGPoint(x: 10, y: 0)
        )
        // A point target stays in the parent's coordinates: (0, 100) there is (100, 200) in the
        // scene, and 20 scene points from it is (0, 90) in the parent's.
        assertPosition(
            constrained(
                configure: { parent, _ in parent.setScale(2) },
                referenced(.distance(SKRange(upperLimit: 20), to: CGPoint(x: 0, y: 100)), scene)
            ),
            CGPoint(x: 0, y: 90)
        )
    }

    func testOrientFacesAPointInTheParentsCoordinatesUnlessGivenANode() {
        let zero = SKRange(constantValue: 0)
        XCTAssertEqual(
            constrained(.orient(to: CGPoint(x: 0, y: 10), offset: zero)).zRotation,
            .pi / 2,
            accuracy: 0.001
        )
        XCTAssertEqual(
            constrained(.orient(to: CGPoint(x: 0, y: 10), in: scene, offset: zero)).zRotation,
            atan2(10, -100),
            accuracy: 0.001
        )
        let offset = SKRange(lowerLimit: 0.1, upperLimit: 0.2)
        XCTAssertEqual(
            constrained(.orient(to: CGPoint(x: 0, y: 10), offset: offset)).zRotation,
            .pi / 2 + 0.1,
            accuracy: 0.001
        )
    }

    // MARK: - Where Apple's results don't follow the reference node's coordinates (C3)

    /// With the parent rotated further than the reference node, the node ends at the range's
    /// lower limit even when it started inside the range (rotation 0.25 relative to the reference).
    func testZRotationWithTheParentRotatedFurtherEndsAtTheLowerLimit() {
        let reference = node()
        let child = constrained(
            configure: { parent, child in
                parent.zRotation = 1
                child.zRotation = -0.75
            },
            referenced(.zRotation(SKRange(lowerLimit: 0.2, upperLimit: 0.3)), reference)
        )
        XCTAssertEqual(child.zRotation, 0.2 - 1, accuracy: 0.001)
    }

    /// Facing a point doesn't depend on a rotated coordinate system, yet with a reference node
    /// rotated further than the parent the node settles at the offset's upper limit.
    func testOrientWithAReferenceNodeRotatedFurtherEndsAtTheUpperLimit() {
        let reference = node(rotation: 1)
        let offset = SKRange(lowerLimit: 0.1, upperLimit: 0.2)
        let child = constrained(referenced(.orient(to: CGPoint(x: 0, y: 10), offset: offset), reference))
        XCTAssertEqual(child.zRotation, .pi / 2 + 0.2, accuracy: 0.001)
    }

    /// With a reference node, a distance constraint gives a NaN position once the node sits on
    /// its target; without one, the node stays there.
    func testDistanceWithAReferenceNodeGivesNaNOnTheTarget() {
        let withReference = constrained(
            referenced(.distance(SKRange(constantValue: 0), to: CGPoint(x: 10, y: 10)), scene)
        )
        XCTAssertTrue(withReference.position.x.isNaN)
        assertPosition(
            constrained(.distance(SKRange(constantValue: 0), to: CGPoint(x: 10, y: 10))),
            CGPoint(x: 10, y: 10)
        )
    }
}
