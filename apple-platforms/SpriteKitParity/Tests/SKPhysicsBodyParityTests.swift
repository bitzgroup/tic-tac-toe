import SpriteKit
import XCTest

/// Records Apple's `SKPhysicsBody` bookkeeping — `node`, `area`, `isResting`, `joints`,
/// `allContactedBodies()` — and the physics units behind `mass`, gravity, forces and impulses,
/// which bitzgroup/SpriteKit mirrors. Apple measures lengths for mass in meters of 150 points.
final class SKPhysicsBodyParityTests: SKPhysicsParityTestCase {
    func testAreaIsInSquareMetersOf150PointsAndMassIsDensityTimesArea() {
        let circle = SKPhysicsBody(circleOfRadius: 10)
        XCTAssertEqual(circle.area, CGFloat.pi * 100 / 22500, accuracy: 1e-6)
        XCTAssertEqual(circle.mass, circle.area, accuracy: 1e-6)
        let rect = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 10))
        XCTAssertEqual(rect.area, 200.0 / 22500, accuracy: 1e-6)
        rect.mass = 1
        XCTAssertEqual(rect.density, 112.5, accuracy: 1e-3)
        XCTAssertEqual(SKPhysicsBody(edgeLoopFrom: CGRect(x: 0, y: 0, width: 10, height: 10)).area, 0)
    }

    func testAreaIgnoresTheNodesScale() {
        let node = SKNode()
        node.setScale(2)
        node.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        XCTAssertEqual(node.physicsBody!.area, CGFloat.pi * 100 / 22500, accuracy: 1e-6)
    }

    func testGravityIsInMetersPerSecondSquaredOf150Points() {
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        let node = add("faller", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 200, y: 380))
        node.physicsBody?.linearDamping = 0
        runFrames(0.5)
        // About half a second of -1470 points/s²; frame timing makes the exact time vary.
        XCTAssertEqual(node.physicsBody!.velocity.dy, -735, accuracy: 120)
    }

    func testAnImpulseChangesVelocityInPointsPerSecondByImpulseOverMass() {
        let node = add("m", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 100, y: 300))
        node.physicsBody?.applyImpulse(CGVector(dx: 1, dy: 0))
        XCTAssertEqual(node.physicsBody!.velocity.dx, 1 / node.physicsBody!.mass, accuracy: 0.01)
    }

    func testAForceAcceleratesAtForceOverMassPointsPerSecondSquaredForAShortTime() {
        let node = add("m", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 100, y: 300))
        node.physicsBody?.linearDamping = 0
        let done = expectation(description: "force")
        scene.run(.sequence([
            .run { node.physicsBody?.applyForce(CGVector(dx: 1, dy: 0)) },
            .wait(forDuration: 0.2),
            .run { done.fulfill() },
        ]))
        wait(for: [done], timeout: 2)
        // Δv = F/m × (time the force acted). That time is the step's — 1/60 or 1/120 s on iOS
        // simulators, longer on tvOS — so only its range is recorded: more than a 1/120 s step,
        // far less than the 0.2 s waited (it doesn't keep acting).
        let actedFor = node.physicsBody!.velocity.dx * node.physicsBody!.mass
        XCTAssertGreaterThanOrEqual(actedFor, 1.0 / 120 - 1e-4)
        XCTAssertLessThan(actedFor, 0.15)
    }

    func testAnAngularImpulseUsesInertiaWithLengthsInMeters() {
        let circle = add("c", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 100, y: 300))
        let rect = add("r", SKPhysicsBody(rectangleOf: CGSize(width: 30, height: 10)), at: CGPoint(x: 300, y: 300))
        circle.physicsBody?.applyAngularImpulse(1)
        rect.physicsBody?.applyAngularImpulse(1)
        let radius = 10.0 / 150
        let circleInertia = circle.physicsBody!.mass * radius * radius / 2
        let rectInertia = rect.physicsBody!.mass * (pow(30.0 / 150, 2) + pow(10.0 / 150, 2)) / 12
        XCTAssertEqual(circle.physicsBody!.angularVelocity / (1 / circleInertia), 1, accuracy: 1e-3)
        XCTAssertEqual(rect.physicsBody!.angularVelocity / (1 / rectInertia), 1, accuracy: 1e-3)
    }

    func testNodeIsTheNodeCarryingTheBodyAndNilOtherwise() {
        let body = SKPhysicsBody(circleOfRadius: 10)
        XCTAssertNil(body.node)
        let node = SKNode()
        node.physicsBody = body
        XCTAssertTrue(body.node === node)
        node.physicsBody = nil
        XCTAssertNil(body.node)
    }

    func testIsRestingIsNotSetByTheSimulationForABodyLyingStill() {
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        add("floor", SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 50), to: CGPoint(x: 400, y: 50)), at: .zero)
        let ball = add("ball", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 200, y: 61))
        ball.physicsBody?.restitution = 0
        XCTAssertFalse(ball.physicsBody!.isResting)
        runFrames(2)
        XCTAssertEqual(ball.physicsBody!.velocity.dy, 0, accuracy: 0.5)
        XCTAssertFalse(ball.physicsBody!.isResting)
    }

    func testSettingIsRestingStopsTheBodyUntilTheNextStepClearsIt() {
        let body = SKPhysicsBody(circleOfRadius: 10)
        body.isResting = true
        XCTAssertTrue(body.isResting)

        let node = add("k", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 200, y: 300))
        node.physicsBody?.linearDamping = 0
        node.physicsBody?.velocity = CGVector(dx: 50, dy: 0)
        node.physicsBody?.isResting = true
        XCTAssertTrue(node.physicsBody!.isResting)
        XCTAssertEqual(node.physicsBody!.velocity, .zero)
        runFrames(0.3)
        XCTAssertFalse(node.physicsBody!.isResting)
        XCTAssertEqual(node.position.x, 200)

        node.physicsBody?.isResting = true
        node.physicsBody?.velocity = CGVector(dx: 30, dy: 0)
        XCTAssertFalse(node.physicsBody!.isResting)
    }

    func testJointsListsTheWorldsJointsOnTheBodyUntilRemovedOrItsNodeLeaves() {
        let a = add("a", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 100, y: 100))
        let b = add("b", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 150, y: 100))
        let joint = SKPhysicsJointPin.joint(withBodyA: a.physicsBody!, bodyB: b.physicsBody!, anchor: CGPoint(x: 125, y: 100))
        XCTAssertTrue(a.physicsBody!.joints.isEmpty)
        world.add(joint)
        XCTAssertTrue(a.physicsBody!.joints.first === joint)
        XCTAssertTrue(b.physicsBody!.joints.first === joint)
        world.remove(joint)
        XCTAssertTrue(a.physicsBody!.joints.isEmpty)
        world.add(joint)
        b.removeFromParent()
        XCTAssertTrue(a.physicsBody!.joints.isEmpty)
    }

    func testAllContactedBodiesListsTouchingPairsThatCollideOrTestForContact() {
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        add("floor", SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 50), to: CGPoint(x: 400, y: 50)), at: .zero)
        let ball = add("ball", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 100, y: 61))
        scene.physicsWorld.gravity = .zero
        XCTAssertTrue(ball.physicsBody!.allContactedBodies().isEmpty) // nothing until a step runs

        func ghost(_ name: String, _ x: CGFloat, _ y: CGFloat) -> SKNode {
            let node = add(name, SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: x, y: y))
            node.physicsBody?.collisionBitMask = 0
            return node
        }
        // Overlapping, neither colliding nor testing for contact: not a contact.
        let quiet1 = ghost("quiet1", 300, 300)
        ghost("quiet2", 305, 300)
        // Overlapping, not colliding, one testing for contact: a contact for both.
        let sensor = ghost("sensor", 300, 200)
        sensor.physicsBody?.contactTestBitMask = 0xFFFF_FFFF
        let target = ghost("target", 305, 200)
        // Overlapping, only one side colliding: a contact for both.
        let wall = add("wall", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 200, y: 300), dynamic: false)
        let pusher = ghost("pusher", 205, 300)
        runFrames(0.2)

        XCTAssertEqual(ball.physicsBody!.allContactedBodies().map { $0.node?.name }, ["floor"])
        XCTAssertTrue(quiet1.physicsBody!.allContactedBodies().isEmpty)
        XCTAssertEqual(sensor.physicsBody!.allContactedBodies().map { $0.node?.name }, ["target"])
        XCTAssertEqual(target.physicsBody!.allContactedBodies().map { $0.node?.name }, ["sensor"])
        XCTAssertEqual(wall.physicsBody!.allContactedBodies().map { $0.node?.name }, ["pusher"])
        XCTAssertEqual(pusher.physicsBody!.allContactedBodies().map { $0.node?.name }, ["wall"])
    }
}
