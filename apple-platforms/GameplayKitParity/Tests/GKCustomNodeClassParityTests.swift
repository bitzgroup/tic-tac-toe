import GameplayKit
import XCTest

private final class CountingGridNode: GKGridGraphNode {
    static var initCount = 0

    override init(gridPosition: vector_int2) {
        CountingGridNode.initCount += 1
        super.init(gridPosition: gridPosition)
    }

    required init?(coder: NSCoder) { fatalError("unused") }
}

private final class CountingNode2D: GKGraphNode2D {
    static var initCount = 0

    override init(point: vector_float2) {
        CountingNode2D.initCount += 1
        super.init(point: point)
    }

    required init?(coder: NSCoder) { fatalError("unused") }
}

/// Records how Apple's graphs build nodes of a caller's own class (`nodeClass:`), which
/// bitzgroup/GameplayKit (PARITY_GAP_PLAN.md G5) mirrors with node-factory parameters.
final class GKCustomNodeClassParityTests: XCTestCase {
    private func square() -> GKPolygonObstacle {
        var points = [vector_float2(-2, -2), vector_float2(2, -2), vector_float2(2, 2), vector_float2(-2, 2)]
        return GKPolygonObstacle(__points: &points, count: 4)
    }

    func testAGridGraphBuildsEveryNodeWithTheNodeClassInitializer() {
        CountingGridNode.initCount = 0
        let graph = GKGridGraph<CountingGridNode>(
            fromGridStartingAt: vector_int2(0, 0), width: 2, height: 3, diagonalsAllowed: false,
            nodeClass: CountingGridNode.self,
        )
        XCTAssertEqual(graph.nodes?.count, 6)
        XCTAssertTrue(graph.nodes!.allSatisfy { $0 is CountingGridNode })
        XCTAssertEqual(CountingGridNode.initCount, 6) // init(gridPosition:), once per node
        XCTAssertTrue(graph.node(atGridPosition: vector_int2(1, 2)) is CountingGridNode)
        XCTAssertTrue(graph.classForGenericArgument(at: 0) == CountingGridNode.self)
    }

    /// Swift's generic argument alone doesn't pick the class — it's erased; only `nodeClass:` counts.
    func testTheGenericArgumentAloneStillBuildsPlainNodes() {
        let graph = GKGridGraph<CountingGridNode>(
            fromGridStartingAt: vector_int2(0, 0), width: 2, height: 2, diagonalsAllowed: false,
        )
        XCTAssertTrue(graph.nodes!.allSatisfy { type(of: $0) == GKGridGraphNode.self })
    }

    func testAPlainNodeCanJoinAGridOfACustomClass() {
        let graph = GKGridGraph<CountingGridNode>(
            fromGridStartingAt: vector_int2(0, 0), width: 2, height: 1, diagonalsAllowed: false,
            nodeClass: CountingGridNode.self,
        )
        let plain = GKGridGraphNode(gridPosition: vector_int2(2, 0))
        graph.connectToAdjacentNodes(node: plain)
        XCTAssertTrue(graph.nodes!.contains { $0 === plain })
        XCTAssertEqual(plain.connectedNodes.count, 1)
    }

    func testAMeshGraphTriangulatesIntoNodesOfTheNodeClass() {
        CountingNode2D.initCount = 0
        let graph = GKMeshGraph<CountingNode2D>(
            bufferRadius: 1, minCoordinate: vector_float2(-10, -10), maxCoordinate: vector_float2(10, 10),
            nodeClass: CountingNode2D.self,
        )
        graph.addObstacles([square()])
        graph.triangulate()
        XCTAssertFalse(graph.nodes!.isEmpty)
        XCTAssertTrue(graph.nodes!.allSatisfy { $0 is CountingNode2D })
        XCTAssertEqual(CountingNode2D.initCount, graph.nodes!.count) // init(point:), once per node

        let plain = GKMeshGraph<CountingNode2D>(
            bufferRadius: 1, minCoordinate: vector_float2(-10, -10), maxCoordinate: vector_float2(10, 10),
        )
        plain.addObstacles([square()])
        plain.triangulate()
        XCTAssertTrue(plain.nodes!.allSatisfy { type(of: $0) == GKGraphNode2D.self })
    }

    func testAnObstacleGraphBuildsItsObstacleNodesFromTheNodeClass() {
        let obstacle = square()
        let graph = GKObstacleGraph<CountingNode2D>(obstacles: [obstacle], bufferRadius: 1, nodeClass: CountingNode2D.self)
        XCTAssertEqual(graph.nodes(for: obstacle).count, 4)
        XCTAssertTrue(graph.nodes!.allSatisfy { $0 is CountingNode2D })
    }
}
