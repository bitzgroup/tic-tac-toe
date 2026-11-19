import SpriteKit
import XCTest

/// Records how Apple's physics turns bodies — `applyForce(_:at:)`, `applyImpulse(_:at:)`, the
/// center of mass bodies turn about, and spin from off-center contacts — which bitzgroup/SpriteKit
/// (PARITY_GAP_PLAN.md P3) mirrors. Lengths in torques are in meters of 150 points, as in mass.
final class SKPhysicsAngularParityTests: SKPhysicsParityTestCase {
    /// Inertia about the center of a circle of radius [points], in kg·m².
    private func circleInertia(_ body: SKPhysicsBody, radius points: CGFloat) -> CGFloat {
        body.mass * pow(points / 150, 2) / 2
    }

    /// An impulse at a point off the center of mass also turns the body, by `(r × J) / I` with
    /// `r` and `J` both scaled to meters; the point is in scene coordinates.
    func testAnOffCenterImpulseTurnsTheBody() {
        let body = add("a", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 200, y: 200)).physicsBody!
        body.applyImpulse(CGVector(dx: 0, dy: 10), at: CGPoint(x: 210, y: 200))
        XCTAssertEqual(body.velocity.dy, 10 / body.mass, accuracy: 0.01)
        XCTAssertEqual(body.angularVelocity, (10.0 / 150) * (10.0 / 150) / circleInertia(body, radius: 10), accuracy: 0.01)
        XCTAssertEqual(body.angularVelocity, 143.239, accuracy: 0.01)

        let holder = SKNode()
        holder.position = CGPoint(x: 50, y: 0)
        holder.zRotation = .pi / 2
        scene.addChild(holder)
        let nested = SKNode()
        nested.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        holder.addChild(nested)
        nested.physicsBody!.applyImpulse(CGVector(dx: 0, dy: 10), at: CGPoint(x: 60, y: 0))
        XCTAssertEqual(nested.physicsBody!.angularVelocity, 143.239, accuracy: 0.01)
    }

    /// The lever arm runs from the center of mass — the shape's center — not the node's origin, and
    /// an angular impulse divides by the inertia about that center.
    func testTheLeverArmRunsFromTheCenterOfMass() {
        let body = add("a", SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: 20, y: 0)), at: CGPoint(x: 100, y: 300)).physicsBody!
        body.applyImpulse(CGVector(dx: 0, dy: 10), at: CGPoint(x: 100, y: 300))
        XCTAssertEqual(body.velocity.dy, 716.197, accuracy: 0.01)
        XCTAssertEqual(body.angularVelocity, -286.479, accuracy: 0.01)

        let spun = add("b", SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: 20, y: 0)), at: CGPoint(x: 300, y: 100)).physicsBody!
        spun.applyAngularImpulse(1)
        XCTAssertEqual(spun.angularVelocity, 1 / circleInertia(spun, radius: 10), accuracy: 1)
        XCTAssertEqual(spun.velocity, .zero)
    }

    /// A force at a point turns the body in the same proportion as an impulse there, for one step.
    func testAnOffCenterForceTurnsTheBody() {
        let body = add("a", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 200, y: 200)).physicsBody!
        body.applyForce(CGVector(dx: 0, dy: 10), at: CGPoint(x: 210, y: 200))
        runFrames(0.2)
        XCTAssertGreaterThan(body.velocity.dy, 0)
        XCTAssertEqual(body.angularVelocity / body.velocity.dy, 0.2, accuracy: 0.001)
    }

    /// A torque turns the body by `τ · dt / I`, measured against a force applied in the same step.
    func testATorqueTurnsTheBodyByTorqueOverInertia() {
        let node = add("r", SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 20)), at: CGPoint(x: 100, y: 100))
        let body = node.physicsBody!
        body.applyForce(CGVector(dx: 10, dy: 0))
        body.applyTorque(1)
        runFrames(0.2)
        let dt = body.velocity.dx / (10 / body.mass)
        let inertia = body.mass * (pow(40.0 / 150, 2) + pow(20.0 / 150, 2)) / 12
        XCTAssertEqual(body.angularVelocity / (dt / inertia), 1, accuracy: 0.001)
    }

    /// A body turns about its center of mass: a node whose body's shape is off its origin swings
    /// around that point, which stays put; `velocity` is the center of mass's. A body turns at most
    /// a quarter turn (π/2) a 1/120-second step, however fast it's spun: 60π radians a second.
    func testABodyTurnsAboutItsCenterOfMassAtMostAQuarterTurnAStep() {
        let node = add("e", SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: 20, y: 0)), at: CGPoint(x: 300, y: 100))
        node.physicsBody!.angularDamping = 0
        node.physicsBody!.applyAngularImpulse(1)
        runFrames(0.3)
        XCTAssertEqual(node.physicsBody!.angularVelocity, .pi * 60, accuracy: 0.01)
        XCTAssertEqual(node.physicsBody!.velocity, .zero)
        let center = CGPoint(x: node.position.x + 20 * cos(node.zRotation), y: node.position.y + 20 * sin(node.zRotation))
        XCTAssertEqual(center.x, 320, accuracy: 0.01)
        XCTAssertEqual(center.y, 100, accuracy: 0.01)
        XCTAssertNotEqual(node.position, CGPoint(x: 300, y: 100))
    }

    /// Contacts push at their contact points: a box landing on its corner turns flat and settles,
    /// and a ball sliding along the floor starts rolling (ω ≈ −v/r) at about two thirds its speed.
    func testOffCenterContactsTurnBodies() {
        scene.physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        let floor = SKNode()
        floor.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 50), to: CGPoint(x: 400, y: 50))
        scene.addChild(floor)
        let box = add("box", SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 40)), at: CGPoint(x: 100, y: 120))
        box.zRotation = 0.3
        let ball = add("ball", SKPhysicsBody(circleOfRadius: 10), at: CGPoint(x: 250, y: 61))
        ball.physicsBody!.velocity = CGVector(dx: 100, dy: 0)
        runFrames(0.3)
        XCTAssertEqual(ball.physicsBody!.velocity.dx, 63.5, accuracy: 3)
        XCTAssertEqual(ball.physicsBody!.angularVelocity, -ball.physicsBody!.velocity.dx / 10, accuracy: 0.2)
        runFrames(1)
        XCTAssertEqual(box.zRotation, 0, accuracy: 0.01)
        XCTAssertEqual(box.physicsBody!.angularVelocity, 0, accuracy: 0.05)
        XCTAssertEqual(box.position.y, 71, accuracy: 1.5)
    }

    /// Physics runs in steps of 1/120 of a second, however long the frame: at 20 frames a second a
    /// falling body moves as six such steps a frame move it, and a box settles exactly as at 60.
    func testPhysicsRunsInSubstepsOfA120thOfASecond() {
        final class Recorder: SKScene {
            var samples: [(time: TimeInterval, y: CGFloat, vy: CGFloat)] = []
            var node: SKNode?
            var now: TimeInterval = 0
            override func update(_ currentTime: TimeInterval) { now = currentTime }
            override func didSimulatePhysics() {
                if let node, samples.count < 3 { samples.append((now, node.position.y, node.physicsBody!.velocity.dy)) }
            }
        }
        let recorder = Recorder(size: CGSize(width: 400, height: 400))
        recorder.physicsWorld.gravity = CGVector(dx: 0, dy: -9.8)
        view.preferredFramesPerSecond = 20
        view.presentScene(recorder)
        runFrames(0.3)
        let node = SKNode()
        node.position = CGPoint(x: 200, y: 300)
        node.physicsBody = SKPhysicsBody(circleOfRadius: 5)
        node.physicsBody!.linearDamping = 0
        recorder.addChild(node)
        recorder.node = node
        runFrames(0.5)
        let (t0, y0, v0) = recorder.samples[1]
        let (t1, y1, v1) = recorder.samples[2]
        XCTAssertEqual(t1 - t0, 0.05, accuracy: 0.001)
        XCTAssertEqual(v1 - v0, -73.5, accuracy: 0.01)
        // Six steps, each adding 12.25 points/s and then moving: (Σ 1…6) × 12.25 / 120 past v0.
        let sixSteps = -(6 * -v0 + 21 * 12.25) / 120
        XCTAssertEqual(y1 - y0, sixSteps, accuracy: 0.001)

        let floor = SKNode()
        floor.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 0, y: 50), to: CGPoint(x: 400, y: 50))
        recorder.addChild(floor)
        let box = SKNode()
        box.position = CGPoint(x: 100, y: 120)
        box.zRotation = 0.3
        box.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 40))
        recorder.addChild(box)
        runFrames(1.5)
        XCTAssertEqual(box.zRotation, 0, accuracy: 0.01)
        XCTAssertEqual(box.physicsBody!.angularVelocity, 0, accuracy: 0.05)
        XCTAssertEqual(box.position.y, 72.274, accuracy: 0.01)
    }

    /// A body moves at most 2 meters (300 points) a step: 36,000 points a second.
    func testABodyMovesAtMost300PointsAStep() {
        let fast = add("a", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 200, y: 200)).physicsBody!
        fast.linearDamping = 0
        fast.velocity = CGVector(dx: 100000, dy: 0)
        let slower = add("b", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: 200, y: 100)).physicsBody!
        slower.linearDamping = 0
        slower.velocity = CGVector(dx: 30000, dy: 0)
        runFrames(0.1)
        XCTAssertEqual(fast.velocity.dx, 36000, accuracy: 0.01)
        XCTAssertEqual(slower.velocity.dx, 30000, accuracy: 0.01)
    }

    /// Restitution applies however slowly bodies meet: a perfectly elastic ball bounces straight
    /// back at 50 points a second as at 400.
    func testRestitutionAppliesAtAnySpeed() {
        let wall = SKNode()
        wall.physicsBody = SKPhysicsBody(edgeFrom: CGPoint(x: 300, y: 0), to: CGPoint(x: 300, y: 400))
        scene.addChild(wall)
        var balls: [(CGFloat, SKPhysicsBody)] = []
        for (i, speed) in [50.0, 140, 400].enumerated() {
            let body = SKPhysicsBody(circleOfRadius: 5)
            body.restitution = 1
            body.linearDamping = 0
            body.friction = 0
            add("b\(i)", body, at: CGPoint(x: 300 - 6 - speed * 0.05, y: 30 + CGFloat(i) * 60))
            body.velocity = CGVector(dx: speed, dy: 0)
            balls.append((speed, body))
        }
        runFrames(0.5)
        for (speed, body) in balls { XCTAssertEqual(body.velocity.dx, -speed, accuracy: 0.01) }
    }
}
