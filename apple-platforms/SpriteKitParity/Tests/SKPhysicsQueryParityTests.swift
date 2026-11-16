import SpriteKit
import XCTest

/// Records Apple's `SKPhysicsWorld` spatial queries — `body(at:)`, `body(in:)`,
/// `body(alongRayStart:end:)` and their `enumerateBodies` forms — which bitzgroup/SpriteKit
/// mirrors. Bodies are static so the simulation can't move them between queries.
final class SKPhysicsQueryParityTests: SKPhysicsParityTestCase {
    private func names(at point: CGPoint) -> Set<String> {
        var found = Set<String>()
        world.enumerateBodies(at: point) { body, _ in found.insert(self.name(body) ?? "") }
        return found
    }

    private func names(in rect: CGRect) -> Set<String> {
        var found = Set<String>()
        world.enumerateBodies(in: rect) { body, _ in found.insert(self.name(body) ?? "") }
        return found
    }

    func testBodyAtTestsTheExactShapeAndFindsNewBodiesBeforeAnySimulationStep() {
        add("a", SKPhysicsBody(circleOfRadius: 20), at: CGPoint(x: 100, y: 100), dynamic: false)
        add("b", SKPhysicsBody(circleOfRadius: 20), at: CGPoint(x: 110, y: 100), dynamic: false)
        XCTAssertEqual(names(at: CGPoint(x: 105, y: 100)), ["a", "b"])
        XCTAssertEqual(names(at: CGPoint(x: 85, y: 100)), ["a"])
        XCTAssertNil(world.body(at: CGPoint(x: 84, y: 84))) // inside the bounding box, outside the circle
        XCTAssertNotNil(world.body(at: CGPoint(x: 105, y: 100)))
    }

    func testBodyAtFollowsTheNodesRotationAndItsAncestorsScale() {
        let box = add("box", SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 20)), at: CGPoint(x: 300, y: 100), dynamic: false)
        box.zRotation = .pi / 2
        let parent = SKNode()
        parent.position = CGPoint(x: 50, y: 300)
        parent.setScale(2)
        scene.addChild(parent)
        let child = SKNode()
        child.name = "child"
        child.position = CGPoint(x: 10, y: 0)
        child.physicsBody = SKPhysicsBody(circleOfRadius: 5)
        child.physicsBody?.isDynamic = false
        parent.addChild(child)
        runFrames(0.1)
        XCTAssertEqual(name(world.body(at: CGPoint(x: 300, y: 115))), "box")
        XCTAssertNil(world.body(at: CGPoint(x: 315, y: 100)))
        XCTAssertEqual(name(world.body(at: CGPoint(x: 78, y: 300))), "child") // radius 5, scaled by 2
    }

    func testBodyAtNeverFindsAnEdgeBodyWhichHasNoInterior() {
        add("edge", SKPhysicsBody(edgeLoopFrom: CGRect(x: -20, y: -20, width: 40, height: 40)), at: CGPoint(x: 200, y: 300), dynamic: false)
        XCTAssertNil(world.body(at: CGPoint(x: 200, y: 300)))
        XCTAssertNil(world.body(at: CGPoint(x: 220, y: 300)))
    }

    func testBodyAtIgnoresTheCategoryBitMask() {
        let node = add("masked", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 50, y: 50), dynamic: false)
        node.physicsBody?.categoryBitMask = 0
        XCTAssertEqual(name(world.body(at: CGPoint(x: 50, y: 50))), "masked")
    }

    func testBodyInMatchesBoundingBoxesPaddedByAboutFifteenPoints() {
        // a's bounding box starts at x = 80, b's at x = 90.
        add("a", SKPhysicsBody(circleOfRadius: 20), at: CGPoint(x: 100, y: 100), dynamic: false)
        add("b", SKPhysicsBody(circleOfRadius: 20), at: CGPoint(x: 110, y: 100), dynamic: false)
        func rect(endingAt x: CGFloat) -> CGRect { CGRect(x: x - 4, y: 98, width: 4, height: 4) }
        XCTAssertEqual(names(in: CGRect(x: 81, y: 81, width: 2, height: 2)), ["a", "b"]) // box corner, outside both circles
        XCTAssertEqual(names(in: rect(endingAt: 78)), ["a", "b"]) // 2 from a's box, 12 from b's
        XCTAssertEqual(names(in: rect(endingAt: 70)), ["a"]) // 10 from a's, 20 from b's
        XCTAssertEqual(names(in: rect(endingAt: 64)), []) // 16 from a's
        XCTAssertNil(world.body(in: rect(endingAt: 64)))
    }

    func testBodyInFindsAnEdgeBodyThroughItsBoundingBox() {
        add("loop", SKPhysicsBody(edgeLoopFrom: CGRect(x: -20, y: -20, width: 40, height: 40)), at: CGPoint(x: 200, y: 300), dynamic: false)
        add("line", SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 0), to: CGPoint(x: 100, y: 0)), at: CGPoint(x: 0, y: 200), dynamic: false)
        XCTAssertEqual(name(world.body(in: CGRect(x: 195, y: 295, width: 10, height: 10))), "loop")
        XCTAssertEqual(name(world.body(in: CGRect(x: 40, y: 202, width: 10, height: 10))), "line")
        XCTAssertNil(world.body(in: CGRect(x: 40, y: 220, width: 10, height: 10)))
    }

    func testRayHitsComeNearestFirstWithANormalOfLength150FacingTheRay() {
        add("far", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 350, y: 30), dynamic: false)
        add("near", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 50, y: 30), dynamic: false)
        var hits: [(String, CGPoint, CGVector)] = []
        world.enumerateBodies(alongRayStart: CGPoint(x: 0, y: 30), end: CGPoint(x: 400, y: 30)) { body, point, normal, _ in
            hits.append((self.name(body) ?? "", point, normal))
        }
        XCTAssertEqual(hits.map(\.0), ["near", "far"])
        XCTAssertEqual(hits[0].1.x, 45, accuracy: 0.01)
        XCTAssertEqual(hits[1].1.x, 345, accuracy: 0.01)
        XCTAssertEqual(hits[0].2.dx, -150, accuracy: 0.01)
        XCTAssertEqual(hits[0].2.dy, 0, accuracy: 0.01)
        XCTAssertEqual(name(world.body(alongRayStart: CGPoint(x: 0, y: 30), end: CGPoint(x: 400, y: 30))), "near")
        XCTAssertEqual(name(world.body(alongRayStart: CGPoint(x: 400, y: 30), end: CGPoint(x: 0, y: 30))), "far")
    }

    func testARayMissesBodiesBeyondItsEndAndOneItStartsInside() {
        add("near", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 50, y: 30), dynamic: false)
        add("far", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 350, y: 30), dynamic: false)
        XCTAssertNil(world.body(alongRayStart: CGPoint(x: 0, y: 30), end: CGPoint(x: 40, y: 30)))
        XCTAssertEqual(name(world.body(alongRayStart: CGPoint(x: 50, y: 30), end: CGPoint(x: 400, y: 30))), "far")
    }

    func testARayHitsAnEdgeLoopOnEachSideItCrosses() {
        add("loop", SKPhysicsBody(edgeLoopFrom: CGRect(x: -20, y: -20, width: 40, height: 40)), at: CGPoint(x: 200, y: 300), dynamic: false)
        var hits: [(CGPoint, CGVector)] = []
        world.enumerateBodies(alongRayStart: CGPoint(x: 200, y: 0), end: CGPoint(x: 200, y: 400)) { _, point, normal, _ in
            hits.append((point, normal))
        }
        XCTAssertEqual(hits.count, 2)
        XCTAssertEqual(hits[0].0.y, 280, accuracy: 0.01)
        XCTAssertEqual(hits[1].0.y, 320, accuracy: 0.01)
        XCTAssertEqual(hits[0].1.dy, -150, accuracy: 0.01)
        XCTAssertEqual(hits[1].1.dy, -150, accuracy: 0.01) // an edge's normal faces the ray from either side
    }

    func testEnumerationStopsWhenTheBlockSetsStop() {
        add("near", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 50, y: 30), dynamic: false)
        add("far", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 350, y: 30), dynamic: false)
        var seen: [String] = []
        world.enumerateBodies(alongRayStart: CGPoint(x: 0, y: 30), end: CGPoint(x: 400, y: 30)) { body, _, _, stop in
            seen.append(self.name(body) ?? "")
            stop.pointee = true
        }
        XCTAssertEqual(seen, ["near"])
    }
}
