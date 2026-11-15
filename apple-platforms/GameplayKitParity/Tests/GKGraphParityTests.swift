import GameplayKit
import XCTest

/// Records how Apple's `GKGraph`/`GKGridGraph` keep membership, connections and grid lookup in
/// step when nodes are removed or added.
final class GKGraphParityTests: XCTestCase {
    private func grid() -> GKGridGraph<GKGridGraphNode> {
        GKGridGraph(fromGridStartingAt: vector_int2(0, 0), width: 3, height: 3, diagonalsAllowed: false)
    }

    func testRemovingAGridNodeClearsItsLookupAndConnections() {
        let graph = grid()
        let center = graph.node(atGridPosition: vector_int2(1, 1))!
        let left = graph.node(atGridPosition: vector_int2(0, 1))!
        XCTAssertEqual(left.connectedNodes.count, 3)

        graph.remove([center])

        XCTAssertNil(graph.node(atGridPosition: vector_int2(1, 1)))
        XCTAssertEqual(graph.nodes?.count, 8)
        XCTAssertEqual(left.connectedNodes.count, 2)
        XCTAssertEqual(center.connectedNodes.count, 0)
    }

    func testConnectToAdjacentNodesAddsTheNodeToTheGraphAndTheLookup() {
        let graph = grid()
        graph.remove([graph.node(atGridPosition: vector_int2(1, 1))!])
        let replacement = GKGridGraphNode(gridPosition: vector_int2(1, 1))

        graph.connectToAdjacentNodes(node: replacement)

        XCTAssertTrue(graph.node(atGridPosition: vector_int2(1, 1)) === replacement)
        XCTAssertEqual(graph.nodes?.count, 9)
        XCTAssertEqual(replacement.connectedNodes.count, 4)
        XCTAssertTrue(graph.node(atGridPosition: vector_int2(0, 1))!.connectedNodes.contains(replacement))
    }

    /// A node outside `gridOrigin`/`gridWidth`/`gridHeight` joins the graph but can't be looked up.
    func testANodeOutsideTheGridIsNotFoundByPosition() {
        let graph = grid()
        let outside = GKGridGraphNode(gridPosition: vector_int2(5, 5))

        graph.connectToAdjacentNodes(node: outside)

        XCTAssertNil(graph.node(atGridPosition: vector_int2(5, 5)))
        XCTAssertEqual(graph.nodes?.count, 10)
    }

    /// Plain `GKGraph.remove` also cuts the removed nodes' connections, in both directions.
    func testRemovingAPlainGraphNodeCutsItsConnections() {
        let a = GKGraphNode(), b = GKGraphNode(), c = GKGraphNode()
        a.addConnections(to: [b], bidirectional: true)
        b.addConnections(to: [c], bidirectional: true)
        let graph = GKGraph([a, b, c])

        graph.remove([b])

        XCTAssertEqual(graph.nodes?.count, 2)
        XCTAssertEqual(a.connectedNodes.count, 0)
        XCTAssertEqual(c.connectedNodes.count, 0)
        XCTAssertEqual(b.connectedNodes.count, 0)
    }

    /// `GKGraph.add` registers nodes without connecting them.
    func testAddingDoesNotConnect() {
        let a = GKGraphNode(), b = GKGraphNode()
        let graph = GKGraph([a])
        graph.add([b])
        XCTAssertEqual(a.connectedNodes.count, 0)
        XCTAssertEqual(b.connectedNodes.count, 0)
    }
}
