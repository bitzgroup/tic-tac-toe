import GameplayKit
import SpriteKit
import XCTest

/// Records how Apple's GameplayKit-SpriteKit glue behaves, for bitzgroup/GKSKBridge to mirror.
final class GKSKBridgeParityTests: XCTestCase {
    // MARK: GKSKNodeComponent as a GKAgentDelegate

    func testNodeComponentSeedsTheAgentFromTheNodeBeforeAnUpdate() {
        let node = SKNode()
        node.position = CGPoint(x: 10, y: 20)
        node.zRotation = 0.5
        let component = GKSKNodeComponent(node: node)
        let agent = GKAgent2D()

        component.agentWillUpdate(agent)

        XCTAssertEqual(agent.position, vector_float2(10, 20))
        XCTAssertEqual(agent.rotation, 0.5)
    }

    func testNodeComponentMovesTheNodeToTheAgentAfterAnUpdate() {
        let node = SKNode()
        let component = GKSKNodeComponent(node: node)
        let agent = GKAgent2D()
        agent.position = vector_float2(30, 40)
        agent.rotation = 1.25

        component.agentDidUpdate(agent)

        XCTAssertEqual(node.position, CGPoint(x: 30, y: 40))
        XCTAssertEqual(node.zRotation, 1.25)
    }

    /// As the agent's delegate, the component brackets every agent update: a node moved by the
    /// game is picked up by the agent, then written back.
    func testAsTheAgentsDelegateTheNodeDrivesAndFollowsTheAgent() {
        let node = SKNode()
        let component = GKSKNodeComponent(node: node)
        let agent = GKAgent2D()
        agent.delegate = component
        node.position = CGPoint(x: 5, y: 6)

        agent.update(deltaTime: 0.1)

        XCTAssertEqual(agent.position, vector_float2(5, 6))
        XCTAssertEqual(node.position, CGPoint(x: 5, y: 6))
    }

    // MARK: SKNode.obstacles(fromNodeBounds:)

    private func vertices(_ obstacle: GKPolygonObstacle) -> [vector_float2] {
        (0..<obstacle.vertexCount).map { obstacle.vertex(at: $0) }
    }

    private func assertVertices(_ actual: [vector_float2], _ expected: [vector_float2], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a.x, e.x, accuracy: 0.001, file: file, line: line)
            XCTAssertEqual(a.y, e.y, accuracy: 0.001, file: file, line: line)
        }
    }

    /// One four-vertex obstacle per node: its own bounds' corners (bottom-left, bottom-right,
    /// top-right, top-left in the node's local space) through the node's position, scale and
    /// rotation — the rotated rectangle itself, not an axis-aligned box around it.
    func testObstaclesAreTheNodesTransformedBoundsCorners() {
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        sprite.position = CGPoint(x: 100, y: 50)
        let rotated = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        rotated.zRotation = .pi / 2
        let anchored = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        anchored.anchorPoint = .zero
        let scaled = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        scaled.xScale = 2

        let obstacles = SKNode.obstacles(fromNodeBounds: [sprite, rotated, anchored, scaled])

        XCTAssertEqual(obstacles.count, 4)
        assertVertices(vertices(obstacles[0]), [[95, 40], [105, 40], [105, 60], [95, 60]])
        assertVertices(vertices(obstacles[1]), [[10, -5], [10, 5], [-10, 5], [-10, -5]])
        assertVertices(vertices(obstacles[2]), [[0, 0], [10, 0], [10, 20], [0, 20]])
        assertVertices(vertices(obstacles[3]), [[-10, -10], [10, -10], [10, 10], [-10, 10]])
    }

    /// Vertices go through every ancestor's transform, the root's own included (a scene's position is
    /// normally zero, so that is scene space).
    func testObstaclesGoThroughEveryAncestorIncludingTheRoot() {
        let parent = SKNode()
        parent.position = CGPoint(x: 1000, y: 0)
        let child = SKSpriteNode(color: .red, size: CGSize(width: 4, height: 4))
        parent.addChild(child)

        let obstacles = SKNode.obstacles(fromNodeBounds: [child])

        assertVertices(vertices(obstacles[0]), [[998, -2], [1002, -2], [1002, 2], [998, 2]])
    }

    /// A node's children don't widen its obstacle, and a node with no content of its own gives a
    /// degenerate obstacle at its position.
    func testObstaclesUseOnlyTheNodesOwnContent() {
        let withChild = SKSpriteNode(color: .red, size: CGSize(width: 2, height: 2))
        let child = SKSpriteNode(color: .red, size: CGSize(width: 2, height: 2))
        child.position = CGPoint(x: 10, y: 0)
        withChild.addChild(child)
        let empty = SKNode()
        empty.position = CGPoint(x: 3, y: 3)

        let obstacles = SKNode.obstacles(fromNodeBounds: [withChild, empty])

        assertVertices(vertices(obstacles[0]), [[-1, -1], [1, -1], [1, 1], [-1, 1]])
        assertVertices(vertices(obstacles[1]), [[3, 3], [3, 3], [3, 3], [3, 3]])
    }
}
