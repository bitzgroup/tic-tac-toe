import GameplayKit
import SpriteKit
import XCTest

/// Records `SKNode.obstacles(fromNodePhysicsBodies:)`, for bitzgroup/GKSKBridge's
/// `obstaclesFromNodePhysicsBodies` (through bitzgroup/SpriteKit's `physicsBodyOutline`).
///
/// Every node here is in a scene: Apple's framework crashes on a body whose node isn't in one.
final class GKPhysicsObstacleParityTests: XCTestCase {
    private let scene = SKScene(size: CGSize(width: 100, height: 100))

    private func vertices(_ nodes: [SKNode]) -> [[vector_float2]] {
        SKNode.obstacles(fromNodePhysicsBodies: nodes).map { o in (0..<o.vertexCount).map { o.vertex(at: $0) } }
    }

    private func assertVertices(_ actual: [vector_float2], _ expected: [vector_float2], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, "\(actual)", file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.x, e.x, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(a.y, e.y, accuracy: 0.001, file: file, line: line)
        }
    }

    /// A node with its transform set, then its body, then added to the scene.
    @discardableResult
    private func node(_ body: SKPhysicsBody?, position: CGPoint = .zero, rotation: CGFloat = 0, xScale: CGFloat = 1, yScale: CGFloat = 1) -> SKNode {
        let node = SKNode()
        node.physicsBody = body
        node.position = position
        node.zRotation = rotation
        node.xScale = xScale
        node.yScale = yScale
        scene.addChild(node)
        return node
    }

    private func path(_ points: [CGPoint], closed: Bool) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        if closed { path.closeSubpath() }
        return path
    }

    private var rectangle: SKPhysicsBody { SKPhysicsBody(rectangleOf: CGSize(width: 10, height: 20)) }

    // MARK: Shapes

    /// A rectangle's corners, bottom-left first, counterclockwise, through the node's transform.
    func testRectangleGoesThroughTheNodesTransform() {
        let moved = node(rectangle, position: CGPoint(x: 100, y: 50))
        let turned = node(SKPhysicsBody(rectangleOf: CGSize(width: 10, height: 20), center: CGPoint(x: 5, y: 0)), position: CGPoint(x: 1, y: 2), rotation: .pi / 2)
        let scaled = node(rectangle, xScale: 2, yScale: 3)

        let result = vertices([moved, turned, scaled])

        assertVertices(result[0], [[95, 40], [105, 40], [105, 60], [95, 60]])
        assertVertices(result[1], [[11, 2], [11, 12], [-9, 12], [-9, 2]])
        assertVertices(result[2], [[-10, -30], [10, -30], [10, 30], [-10, 30]])
    }

    /// A polygon keeps the vertex it was given first; a clockwise outline is reversed after it.
    func testPolygonKeepsItsFirstVertexAndTurnsCounterclockwise() {
        let ccw = node(SKPhysicsBody(polygonFrom: path([CGPoint(x: 10, y: 0), CGPoint(x: 0, y: 10), .zero], closed: true)))
        let cw = node(SKPhysicsBody(polygonFrom: path([.zero, CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 0)], closed: true)))
        let pentagon = node(SKPhysicsBody(polygonFrom: path([CGPoint(x: 5, y: 10), CGPoint(x: 0, y: 6), CGPoint(x: 2, y: 0), CGPoint(x: 8, y: 0), CGPoint(x: 10, y: 6)], closed: true)))

        let result = vertices([ccw, cw, pentagon])

        assertVertices(result[0], [[10, 0], [0, 10], [0, 0]])
        assertVertices(result[1], [[0, 0], [10, 0], [0, 10]])
        assertVertices(result[2], [[5, 10], [0, 6], [2, 0], [8, 0], [10, 6]])
    }

    /// A circle is an octagon on the circle at 0°, 45°, … in scene space: the node's rotation
    /// moves its center but turns none of the vertices. A circle path makes a circle body too.
    func testCircleIsAnOctagonAtSceneSpaceAngles() {
        let circle = node(SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: 5, y: 0)), position: CGPoint(x: 100, y: 0), rotation: .pi / 2)
        let fromPath = node(SKPhysicsBody(polygonFrom: CGPath(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20), transform: nil)))
        let scaled = node(SKPhysicsBody(circleOfRadius: 10), xScale: 2, yScale: 2)

        let result = vertices([circle, fromPath, scaled])

        let d: Float = 7.0711
        assertVertices(result[0], [[110, 5], [100 + d, 5 + d], [100, 15], [100 - d, 5 + d], [90, 5], [100 - d, 5 - d], [100, -5], [100 + d, 5 - d]])
        assertVertices(result[1], [[10, 0], [d, d], [0, 10], [-d, d], [-10, 0], [-d, -d], [0, -10], [d, -d]])
        assertVertices(result[2], [[20, 0], [2 * d, 2 * d], [0, 20], [-2 * d, 2 * d], [-20, 0], [-2 * d, -2 * d], [0, -20], [2 * d, -2 * d]])
    }

    /// Edge chains keep their points in the order given; a loop repeats its first point at the end.
    func testEdgeChainsKeepTheirOrderAndLoopsRepeatTheirFirstPoint() {
        let rectLoop = node(SKPhysicsBody(edgeLoopFrom: CGRect(x: -5, y: 3, width: 10, height: 20)))
        let pathLoop = node(SKPhysicsBody(edgeLoopFrom: path([.zero, CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10)], closed: false)))
        let chain = node(SKPhysicsBody(edgeChainFrom: path([.zero, CGPoint(x: 0, y: 10), CGPoint(x: 10, y: 0)], closed: false)))
        let shortChain = node(SKPhysicsBody(edgeChainFrom: path([.zero, CGPoint(x: 10, y: 0)], closed: false)))

        let result = vertices([rectLoop, pathLoop, chain, shortChain])

        assertVertices(result[0], [[-5, 3], [5, 3], [5, 23], [-5, 23], [-5, 3]])
        assertVertices(result[1], [[0, 0], [10, 0], [10, 10], [0, 0]])
        assertVertices(result[2], [[0, 0], [0, 10], [10, 0]])
        assertVertices(result[3], [[0, 0], [10, 0]])
    }

    /// A body of one part gives that part, nested or not.
    func testBodyOfOnePartGivesThatPart() {
        let nested = node(SKPhysicsBody(bodies: [SKPhysicsBody(bodies: [rectangle])]))
        let circle = node(SKPhysicsBody(bodies: [SKPhysicsBody(circleOfRadius: 2)]))

        let result = vertices([nested, circle])

        assertVertices(result[0], [[-5, -10], [5, -10], [5, 10], [-5, 10]])
        XCTAssertEqual(result[1].count, 8)
    }

    /// No obstacle for a node without a body, a single edge, several parts or a concave polygon
    /// (which is several convex parts), so the result can be shorter than the input.
    func testSomeBodiesGiveNoObstacle() {
        let none = node(nil)
        let edge = node(SKPhysicsBody(edgeFrom: .zero, to: CGPoint(x: 10, y: 0)))
        let parts = node(SKPhysicsBody(bodies: [SKPhysicsBody(rectangleOf: CGSize(width: 2, height: 2)), SKPhysicsBody(circleOfRadius: 1, center: CGPoint(x: 10, y: 0))]))
        let concave = node(SKPhysicsBody(polygonFrom: path([.zero, CGPoint(x: 10, y: 0), CGPoint(x: 10, y: 10), CGPoint(x: 5, y: 3), CGPoint(x: 0, y: 10)], closed: true)))
        let square = node(SKPhysicsBody(rectangleOf: CGSize(width: 2, height: 2)))

        let result = vertices([none, edge, parts, concave, square])

        XCTAssertEqual(result.count, 1)
        assertVertices(result[0], [[-1, -1], [1, -1], [1, 1], [-1, 1]])
    }

    // MARK: Transforms

    /// Vertices go through every ancestor's transform up to the scene.
    func testObstaclesGoThroughTheNodesAncestors() {
        let parent = SKNode()
        parent.zRotation = .pi / 2
        parent.setScale(2)
        let child = SKNode()
        child.position = CGPoint(x: 10, y: 0)
        child.physicsBody = rectangle
        parent.addChild(child)
        scene.addChild(parent)

        assertVertices(vertices([child])[0], [[20, 10], [20, 30], [-20, 30], [-20, 10]])
    }

    /// The transform is the one the physics engine last synced from the node: a node moved or
    /// turned after its body joined the scene keeps its old obstacle until a frame runs.
    func testTransformChangedAfterJoiningTheSceneIsNotSeenYet() {
        let moved = node(rectangle, position: CGPoint(x: 100, y: 50))
        moved.position = .zero
        let turned = node(rectangle)
        turned.zRotation = .pi / 2

        let result = vertices([moved, turned])

        assertVertices(result[0], [[95, 40], [105, 40], [105, 60], [95, 60]])
        assertVertices(result[1], [[-5, -10], [5, -10], [5, 10], [-5, 10]])
    }

    /// A body scales only with scale changes made after it's attached: one attached to a node
    /// already at `xScale` 2 stays unscaled. A circle under a non-uniform scale gets the radius
    /// `r·√((sx² + sy²)/2)`.
    func testBodyScalesOnlyWithScaleChangesAfterItIsAttached() {
        let scaledFirst = SKNode()
        scaledFirst.xScale = 2
        scaledFirst.physicsBody = rectangle
        scene.addChild(scaledFirst)
        let ellipse = node(SKPhysicsBody(circleOfRadius: 10), yScale: 2)

        let result = vertices([scaledFirst, ellipse])

        assertVertices(result[0], [[-5, -10], [5, -10], [5, 10], [-5, 10]])
        XCTAssertEqual(result[1][0].x, 10 * (2.5 as Float).squareRoot(), accuracy: 0.001)
        XCTAssertEqual(result[1][2].y, 10 * (2.5 as Float).squareRoot(), accuracy: 0.001)
    }
}
