import SpriteKit
import XCTest

/// Records Apple's physics actions — `applyForce`/`applyImpulse`/`applyTorque`/
/// `applyAngularImpulse` over a duration, `changeMass`, `changeCharge`, and a field's
/// `strength`/`falloff` actions — which bitzgroup/SpriteKit (PARITY_GAP_PLAN.md A6) mirrors.
final class SKPhysicsActionParityTests: SKPhysicsParityTestCase {
    /// Records a body's velocity and angular velocity each time a frame's actions have run.
    final class Recorder: SKScene {
        var samples: [(v: CGVector, w: CGFloat)] = []
        var body: SKPhysicsBody?
        override func didEvaluateActions() {
            if let body { samples.append((body.velocity, body.angularVelocity)) }
        }
    }

    /// Runs `action` on a still circle of radius 10 for `seconds`, returning the samples from the
    /// first frame the action ran onward.
    private func record(_ action: SKAction, seconds: Double = 0.4) -> [(v: CGVector, w: CGFloat)] {
        let recorder = Recorder(size: CGSize(width: 400, height: 400))
        recorder.physicsWorld.gravity = .zero
        view.presentScene(recorder)
        runFrames(0.2)
        let node = SKNode()
        node.position = CGPoint(x: 200, y: 200)
        node.physicsBody = SKPhysicsBody(circleOfRadius: 10)
        node.physicsBody!.linearDamping = 0
        node.physicsBody!.angularDamping = 0
        recorder.addChild(node)
        recorder.body = node.physicsBody
        node.run(action)
        runFrames(seconds)
        let samples = recorder.samples.drop { $0.v == .zero && $0.w == 0 }
        return Array(samples)
    }

    private func body(_ name: String, at position: CGPoint) -> SKPhysicsBody {
        let body = add(name, SKPhysicsBody(circleOfRadius: 10), at: position).physicsBody!
        body.linearDamping = 0
        body.angularDamping = 0
        return body
    }

    private func runAction(_ action: SKAction, on node: SKNode) {
        let done = expectation(description: "action")
        node.run(action) { done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    /// An impulse action changes the velocity as the frame's actions run, before physics, by an
    /// even share of the impulse each frame: twelve frames of 0.2 seconds, 10 / mass in all.
    func testAnImpulseActionSpreadsItsImpulseOverItsDuration() {
        let samples = record(.applyImpulse(CGVector(dx: 10, dy: 0), duration: 0.2))
        XCTAssertEqual(samples[0].v.dx, 59.6831, accuracy: 0.001)
        XCTAssertEqual(samples[1].v.dx, 119.3662, accuracy: 0.001)
        XCTAssertEqual(samples[11].v.dx, 716.1971, accuracy: 0.001)
        XCTAssertEqual(samples.last!.v.dx, 716.1971, accuracy: 0.001)
    }

    /// A force action pushes as the force would over its duration: F / m / 60 a frame.
    func testAForceActionPushesAsTheForceWouldForItsDuration() {
        let samples = record(.applyForce(CGVector(dx: 10, dy: 0), duration: 0.2))
        XCTAssertEqual(samples[0].v.dx, 11.9366, accuracy: 0.001)
        XCTAssertEqual(samples[11].v.dx, 143.2394, accuracy: 0.001)
        XCTAssertEqual(samples.last!.v.dx, 143.2394, accuracy: 0.001)
    }

    /// The push follows the action's eased progress. Apple's `easeIn` is 2t² − t³: halfway
    /// through, 3/8 of the impulse; the force action follows the same curve.
    func testATimingModeShapesThePush() {
        let impulse = SKAction.applyImpulse(CGVector(dx: 10, dy: 0), duration: 0.2)
        impulse.timingMode = .easeIn
        let samples = record(impulse)
        let t: CGFloat = 1.0 / 12
        let firstFrame: CGFloat = 2 * t * t - t * t * t
        XCTAssertEqual(samples[0].v.dx / 716.1971, firstFrame, accuracy: 0.0001)
        XCTAssertEqual(samples[5].v.dx / 716.1971, 0.375, accuracy: 0.0001)
        XCTAssertEqual(samples[11].v.dx, 716.1971, accuracy: 0.001)

        let force = SKAction.applyForce(CGVector(dx: 10, dy: 0), duration: 0.2)
        force.timingMode = .easeIn
        let forced = record(force)
        XCTAssertEqual(forced[5].v.dx / 143.2394, 0.375, accuracy: 0.0001)
    }

    /// Torque and angular-impulse actions turn the body frame by frame in the same way.
    func testTorqueAndAngularImpulseActionsTurnTheBodyFrameByFrame() {
        let torqued = record(.applyTorque(0.001, duration: 0.2))
        XCTAssertEqual(torqued[0].w, 0.5371, accuracy: 0.0001)
        XCTAssertEqual(torqued[11].w, 6.4458, accuracy: 0.0001)
        let spun = record(.applyAngularImpulse(0.001, duration: 0.2))
        XCTAssertEqual(spun[0].w, 2.6857, accuracy: 0.0001)
        XCTAssertEqual(spun[11].w, 32.2289, accuracy: 0.0001)
    }

    /// At a point off the center of mass (scene coordinates), they also turn it.
    func testActionsAtAPointOffTheCenterOfMassTurnTheBody() {
        let forced = body("f", at: CGPoint(x: 250, y: 50))
        runAction(.applyForce(CGVector(dx: 0, dy: 10), at: CGPoint(x: 260, y: 50), duration: 0.5), on: forced.node!)
        XCTAssertEqual(forced.velocity.dy, 358.0985, accuracy: 0.01)
        XCTAssertEqual(forced.angularVelocity, 71.6195, accuracy: 0.01)
        let hit = body("i", at: CGPoint(x: 300, y: 50))
        runAction(.applyImpulse(CGVector(dx: 0, dy: 10), at: CGPoint(x: 310, y: 50), duration: 0.5), on: hit.node!)
        XCTAssertEqual(hit.velocity.dy, 716.197, accuracy: 0.01)
        XCTAssertEqual(hit.angularVelocity, 143.239, accuracy: 0.01)
    }

    /// An impulse action with no duration applies nothing; a reversed one pushes the same way.
    func testAnInstantImpulseDoesNothingAndAReversedOnePushesTheSameWay() {
        let instant = body("i", at: CGPoint(x: 100, y: 100))
        runAction(.applyImpulse(CGVector(dx: 10, dy: 0), duration: 0), on: instant.node!)
        runFrames(0.1)
        XCTAssertEqual(instant.velocity, .zero)
        let instantForce = body("f", at: CGPoint(x: 150, y: 100))
        runAction(.applyForce(CGVector(dx: 10, dy: 0), duration: 0), on: instantForce.node!)
        XCTAssertEqual(instantForce.velocity, .zero)

        let reversed = record(SKAction.applyImpulse(CGVector(dx: 10, dy: 0), duration: 0.2).reversed())
        XCTAssertEqual(reversed.last!.v.dx, 716.1971, accuracy: 0.001)
    }

    /// Mass actions interpolate linearly, adding for `by`, and change the density with the mass.
    /// (Reversed mass actions, and a mass of 0 or below, trap, so they aren't recorded.)
    func testMassActionsChangeTheMassAndWithItTheDensity() {
        let body = body("m", at: CGPoint(x: 100, y: 100))
        runAction(.changeMass(to: 2, duration: 0.2), on: body.node!)
        XCTAssertEqual(body.mass, 2, accuracy: 0.0001)
        XCTAssertEqual(body.density, 2 / body.area, accuracy: 0.01)
        body.mass = 3
        runAction(.changeMass(by: 2, duration: 0.2), on: body.node!)
        XCTAssertEqual(body.mass, 5, accuracy: 0.0001)
    }

    /// Charge actions too; reversed ones change nothing.
    func testChargeActionsChangeTheChargeAndReversedOnesDont() {
        let body = body("c", at: CGPoint(x: 100, y: 100))
        XCTAssertEqual(body.charge, 0)
        runAction(.changeCharge(to: 3, duration: 0.2), on: body.node!)
        XCTAssertEqual(body.charge, 3, accuracy: 0.0001)
        runAction(.changeCharge(by: 2, duration: 0.2), on: body.node!)
        XCTAssertEqual(body.charge, 5, accuracy: 0.0001)
        runAction(SKAction.changeCharge(by: 2, duration: 0).reversed(), on: body.node!)
        runAction(SKAction.changeCharge(to: 7, duration: 0).reversed(), on: body.node!)
        XCTAssertEqual(body.charge, 5, accuracy: 0.0001)
    }

    /// `strength(by:)` multiplies, and its reverse divides; a reversed `strength(to:)` does nothing.
    func testStrengthActionsSetOrMultiplyAFieldsStrength() {
        let field = SKFieldNode.radialGravityField()
        scene.addChild(field)
        runAction(.strength(to: 5, duration: 0.2), on: field)
        XCTAssertEqual(field.strength, 5, accuracy: 0.0001)
        field.strength = 2
        runAction(.strength(by: 3, duration: 0.2), on: field)
        XCTAssertEqual(field.strength, 6, accuracy: 0.0001)
        runAction(SKAction.strength(by: 3, duration: 0).reversed(), on: field)
        XCTAssertEqual(field.strength, 2, accuracy: 0.0001)
        runAction(SKAction.strength(to: 3, duration: 0).reversed(), on: field)
        XCTAssertEqual(field.strength, 2, accuracy: 0.0001)
    }

    /// `falloff(to:)` and `falloff(by:)` leave a field's falloff as it is, on any kind of field —
    /// and never finish, even with no duration or on a node that isn't a field, holding up a
    /// sequence or group they're in. Their `duration` reads as given.
    func testFalloffActionsChangeNothingAndNeverFinish() {
        var finished: [String] = []
        let fields = [SKFieldNode.radialGravityField(), SKFieldNode.dragField(), SKFieldNode.springField()]
        for (i, field) in fields.enumerated() {
            field.falloff = 3
            scene.addChild(field)
            field.run(.falloff(to: 1, duration: 0.1)) { finished.append("to\(i)") }
            field.run(.falloff(by: 2, duration: 0)) { finished.append("by\(i)") }
            field.run(.sequence([.falloff(to: 1, duration: 0.1), .run { finished.append("sequence\(i)") }]))
            field.run(.group([.falloff(to: 1, duration: 0.1), .wait(forDuration: 0.2)])) { finished.append("group\(i)") }
        }
        let plain = SKNode()
        scene.addChild(plain)
        plain.run(.falloff(to: 1, duration: 0.1)) { finished.append("plain") }
        runFrames(1)
        XCTAssertEqual(finished, [])
        for field in fields {
            XCTAssertEqual(field.falloff, 3)
            XCTAssertTrue(field.hasActions())
        }
        XCTAssertTrue(plain.hasActions())
        XCTAssertEqual(SKAction.falloff(to: 1, duration: 0.3).duration, 0.3, accuracy: 1e-6)
    }

    /// On a node without a body (or that isn't a field), they finish and do nothing.
    func testPhysicsActionsOnANodeWithoutABodyDoNothing() {
        let plain = SKNode()
        scene.addChild(plain)
        runAction(.group([
            .applyImpulse(CGVector(dx: 1, dy: 0), duration: 0.1),
            .applyTorque(1, duration: 0.1),
            .changeMass(to: 1, duration: 0.1),
            .changeCharge(by: 1, duration: 0.1),
            .strength(to: 1, duration: 0.1),
        ]), on: plain)
        XCTAssertNil(plain.physicsBody)
    }
}
