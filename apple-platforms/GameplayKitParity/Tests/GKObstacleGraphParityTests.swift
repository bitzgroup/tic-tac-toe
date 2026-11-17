import GameplayKit
import XCTest

/// Records Apple's `GKObstacleGraph` connection locking and `connectUsingObstacles` variants,
/// which bitzgroup/GameplayKit mirrors.
final class GKObstacleGraphParityTests: XCTestCase {
    private func square(_ cx: Float, _ cy: Float, _ half: Float) -> GKPolygonObstacle {
        var points = [
            vector_float2(cx - half, cy - half), vector_float2(cx + half, cy - half),
            vector_float2(cx + half, cy + half), vector_float2(cx - half, cy + half),
        ]
        return GKPolygonObstacle(__points: &points, count: 4)
    }

    private func connected(_ from: GKGraphNode, _ to: GKGraphNode) -> Bool {
        from.connectedNodes.contains { $0 === to }
    }

    private func node(_ nodes: [GKGraphNode2D], x: Float, y: Float) -> GKGraphNode2D {
        nodes.first { abs($0.position.x - x) < 0.01 && abs($0.position.y - y) < 0.01 }!
    }

    func testTheBufferRadiusPushesEachCornerOutAlongBothAxes() {
        let obstacle = square(0, 0, 10)
        let graph = GKObstacleGraph(obstacles: [obstacle], bufferRadius: 2)
        let positions = graph.nodes(for: obstacle).map { $0.position }
        for expected in [vector_float2(-12, -12), vector_float2(12, -12), vector_float2(12, 12), vector_float2(-12, 12)] {
            XCTAssertTrue(positions.contains { abs($0.x - expected.x) < 0.01 && abs($0.y - expected.y) < 0.01 }, "\(expected)")
        }
    }

    func testALockKeepsOnlyThatDirectionOfAConnectionWhenAnObstacleBlocksIt() {
        let left = square(0, 0, 10)
        let right = square(100, 0, 10)
        let graph = GKObstacleGraph(obstacles: [left, right], bufferRadius: 2)
        let a = node(graph.nodes(for: left), x: 12, y: -12)
        let b = node(graph.nodes(for: right), x: 88, y: -12)
        XCTAssertTrue(connected(a, b) && connected(b, a))
        XCTAssertFalse(graph.isConnectionLocked(from: a, to: b))

        graph.lockConnection(from: a, to: b)
        XCTAssertTrue(graph.isConnectionLocked(from: a, to: b))
        XCTAssertFalse(graph.isConnectionLocked(from: b, to: a))

        let middle = square(50, 0, 30)
        graph.addObstacles([middle])
        XCTAssertTrue(connected(a, b))
        XCTAssertFalse(connected(b, a))

        graph.unlockConnection(from: a, to: b)
        XCTAssertFalse(graph.isConnectionLocked(from: a, to: b))
        XCTAssertTrue(connected(a, b)) // unlocking alone changes no connection

        graph.removeObstacles([middle])
        XCTAssertTrue(connected(a, b) && connected(b, a))
        graph.addObstacles([middle])
        XCTAssertFalse(connected(a, b) || connected(b, a))
    }

    func testLockingAPairThatIsNotConnectedRecordsTheLockButConnectsNothing() {
        let graph = GKObstacleGraph(obstacles: [square(0, 0, 10)], bufferRadius: 0)
        let p = GKGraphNode2D(point: vector_float2(-50, 0))
        let q = GKGraphNode2D(point: vector_float2(50, 0))
        graph.lockConnection(from: p, to: q)
        XCTAssertTrue(graph.isConnectionLocked(from: p, to: q))
        XCTAssertFalse(connected(p, q))
        XCTAssertFalse(graph.nodes?.contains { $0 === p } ?? false)
    }

    func testAddingAnObstacleReconnectsNodesConnectedFromOutsideToo() {
        let graph = GKObstacleGraph(obstacles: [square(0, 0, 10)], bufferRadius: 0)
        let p = GKGraphNode2D(point: vector_float2(-50, 0))
        let q = GKGraphNode2D(point: vector_float2(50, 50))
        graph.connectUsingObstacles(node: p)
        graph.connectUsingObstacles(node: q)
        XCTAssertTrue(connected(p, q))
        graph.addObstacles([square(0, 25, 10)])
        XCTAssertFalse(connected(p, q) || connected(q, p))
    }

    func testConnectingIgnoringObstaclesLetsTheNodeSeeThroughThem() {
        let obstacle = square(50, 0, 20)
        let graph = GKObstacleGraph(obstacles: [obstacle], bufferRadius: 5)
        let start = GKGraphNode2D(point: vector_float2(50, -60))
        let end = GKGraphNode2D(point: vector_float2(50, 60))
        graph.connectUsingObstacles(node: start)
        graph.connectUsingObstacles(node: end)
        XCTAssertFalse(connected(start, end))
        XCTAssertEqual(start.connectedNodes.count, 2) // the two buffered corners it can see

        let seeingStart = GKGraphNode2D(point: vector_float2(50, -60))
        let seeingEnd = GKGraphNode2D(point: vector_float2(50, 60))
        graph.connectUsingObstacles(node: seeingStart, ignoring: [obstacle])
        graph.connectUsingObstacles(node: seeingEnd, ignoring: [obstacle])
        XCTAssertTrue(connected(seeingStart, seeingEnd) && connected(seeingEnd, seeingStart))
        XCTAssertTrue(graph.nodes?.contains { $0 === seeingStart } ?? false)
        // All four corners, start and end — everything else in the graph.
        XCTAssertEqual(seeingStart.connectedNodes.count, 7)
    }

    func testConnectingIgnoringTheBufferRadiusLetsANodeInsideTheBufferConnect() {
        let obstacle = square(50, 0, 20)
        let graph = GKObstacleGraph(obstacles: [obstacle], bufferRadius: 5)
        let start = GKGraphNode2D(point: vector_float2(50, -60))
        graph.connectUsingObstacles(node: start)
        // 3 points below the obstacle's edge: inside the 5-point buffer, outside the obstacle.
        let inBuffer = GKGraphNode2D(point: vector_float2(50, -23))
        graph.connectUsingObstacles(node: inBuffer)
        XCTAssertTrue(inBuffer.connectedNodes.isEmpty)

        let ignoringBuffer = GKGraphNode2D(point: vector_float2(50, -23))
        graph.connectUsingObstacles(node: ignoringBuffer, ignoringBufferRadiusOf: [obstacle])
        let positions = ignoringBuffer.connectedNodes.map { ($0 as! GKGraphNode2D).position }
        XCTAssertEqual(positions.count, 4) // the two lower corners, start, and the first in-buffer node
        XCTAssertTrue(positions.contains(vector_float2(50, -60)))
        XCTAssertTrue(positions.contains(vector_float2(50, -23)))
        XCTAssertTrue(positions.contains { abs($0.x - 25) < 0.01 && abs($0.y + 25) < 0.01 })
        XCTAssertTrue(positions.contains { abs($0.x - 75) < 0.01 && abs($0.y + 25) < 0.01 })
    }
}
