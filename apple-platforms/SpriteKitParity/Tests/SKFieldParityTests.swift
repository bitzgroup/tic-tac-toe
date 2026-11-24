import SpriteKit
import XCTest

/// Records `SKFieldNode`'s defaults and how its gravity fields weaken with distance —
/// bitzgroup/SpriteKit (PARITY_GAP_PLAN.md P6) mirrors them. A gravity field accelerates at
/// `strength` meters per second squared (150 points per second squared) divided by the distance
/// from the field node in meters, never less than `minimumRadius` (in points), raised to `falloff`.
final class SKFieldParityTests: XCTestCase {
    /// Records, after each frame's physics, the tracked body's x velocity and a reference body's
    /// y velocity.
    final class Recorder: SKScene {
        var body: SKPhysicsBody?
        var reference: SKPhysicsBody?
        var samples: [(vx: CGFloat, referenceVy: CGFloat)] = []
        override func didSimulatePhysics() {
            if let body { samples.append((body.velocity.dx, reference?.velocity.dy ?? 0)) }
        }
    }

    private var window: UIWindow!
    private var view: SKView!
    private var scene: Recorder!

    override func setUp() {
        super.setUp()
        view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        scene = Recorder(size: view.bounds.size)
        view.presentScene(scene)
        runFrames(0.2)
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        view = nil
        scene = nil
        super.tearDown()
    }

    private func runFrames(_ seconds: Double) {
        let done = expectation(description: "frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    /// Runs a free body [distance] points to the right of [field] for a few frames, next to a
    /// reference body the field doesn't affect (`fieldBitMask` 0) falling under the world's
    /// default gravity, and returns both velocities after each frame's physics.
    private func samples(
        under field: SKFieldNode,
        at distance: CGFloat,
        radius: CGFloat = 2,
        initialVelocity: CGVector = .zero
    ) -> [(vx: CGFloat, referenceVy: CGFloat)] {
        field.position = CGPoint(x: 0, y: 200)
        scene.addChild(field)
        func freeBody(at position: CGPoint) -> SKPhysicsBody {
            let node = SKNode()
            node.position = position
            let body = SKPhysicsBody(circleOfRadius: radius)
            body.linearDamping = 0
            body.collisionBitMask = 0
            node.physicsBody = body
            scene.addChild(node)
            return body
        }
        let body = freeBody(at: CGPoint(x: distance, y: 200))
        body.velocity = initialVelocity
        let reference = freeBody(at: CGPoint(x: -500, y: 200))
        reference.fieldBitMask = 0
        scene.samples = []
        scene.body = body
        scene.reference = reference
        runFrames(0.1)
        scene.body = nil
        scene.reference = nil
        body.node?.removeFromParent()
        reference.node?.removeFromParent()
        field.removeFromParent()
        return scene.samples
    }

    /// The x acceleration (points/s²) [field] gives a body [distance] points to its right — its
    /// velocity after a few frames as a share of the reference body's, which falls at the world's
    /// −9.8 m/s² (−1470 points/s²). The ratio doesn't depend on how many physics steps ran. The
    /// body moves well under a point in that time at the distances used here.
    private func acceleration(of field: SKFieldNode, at distance: CGFloat, radius: CGFloat = 2) -> CGFloat {
        let sample = samples(under: field, at: distance, radius: radius)[2]
        return sample.vx / sample.referenceVy * -1470
    }

    private func constantRadial() -> SKFieldNode {
        let field = SKFieldNode.radialGravityField()
        field.falloff = 0
        return field
    }

    func testDefaults() {
        let radial = SKFieldNode.radialGravityField()
        XCTAssertEqual(radial.falloff, 2)
        XCTAssertEqual(radial.strength, 1)
        XCTAssertEqual(radial.minimumRadius, 0.0045776367, accuracy: 1e-9)
        let others = [
            SKFieldNode.linearGravityField(withVector: vector_float3(0, -1, 0)),
            SKFieldNode.dragField(),
            SKFieldNode.velocityField(withVector: vector_float3(1, 0, 0)),
        ]
        for field in others {
            XCTAssertEqual(field.falloff, 0)
            XCTAssertEqual(field.strength, 1)
            XCTAssertEqual(field.minimumRadius, 0.0045776367, accuracy: 1e-9)
        }
    }

    /// With no falloff, strength 1 is 1 m/s² — 150 points/s², the same units as
    /// `SKPhysicsWorld.gravity` — at any distance and whatever the body's mass. (Pulling towards
    /// the field node, so negative here.)
    func testStrengthIsMetersPerSecondSquared() {
        XCTAssertEqual(acceleration(of: constantRadial(), at: 30), -150, accuracy: 1)
        XCTAssertEqual(acceleration(of: constantRadial(), at: 300), -150, accuracy: 1)
        XCTAssertEqual(acceleration(of: constantRadial(), at: 150, radius: 20), -150, accuracy: 1)
        let strong = constantRadial()
        strong.strength = 3
        XCTAssertEqual(acceleration(of: strong, at: 150), -450, accuracy: 3)
    }

    /// The default falloff of 2 is inverse-square in meters: full strength one meter (150 points)
    /// away, a quarter at two meters, four times at half a meter.
    func testFalloffDividesByTheDistanceInMeters() {
        XCTAssertEqual(acceleration(of: .radialGravityField(), at: 150), -150, accuracy: 1)
        XCTAssertEqual(acceleration(of: .radialGravityField(), at: 300), -37.5, accuracy: 0.3)
        XCTAssertEqual(acceleration(of: .radialGravityField(), at: 75), -600, accuracy: 15)
        let linearFalloff = SKFieldNode.radialGravityField()
        linearFalloff.falloff = 1
        XCTAssertEqual(acceleration(of: linearFalloff, at: 300), -75, accuracy: 0.5)
        let rootFalloff = SKFieldNode.radialGravityField()
        rootFalloff.falloff = 0.5
        XCTAssertEqual(acceleration(of: rootFalloff, at: 300), -106.07, accuracy: 0.7)
    }

    /// `minimumRadius` is in points: 150 points from the field, a minimum of 300 makes it act as
    /// if two meters away (a quarter of its strength), while a minimum of 1 changes nothing.
    func testMinimumRadiusIsInPoints() {
        let far = SKFieldNode.radialGravityField()
        far.minimumRadius = 300
        XCTAssertEqual(acceleration(of: far, at: 150), -37.5, accuracy: 0.3)
        let tiny = SKFieldNode.radialGravityField()
        tiny.minimumRadius = 1
        XCTAssertEqual(acceleration(of: tiny, at: 150), -150, accuracy: 1)
    }

    /// A linear field's vector isn't normalized, and falloff weakens it with distance from the
    /// field node too.
    func testLinearFieldsUseTheirVectorAsGivenAndFallOff() {
        let field = SKFieldNode.linearGravityField(withVector: vector_float3(2, 0, 0))
        XCTAssertEqual(acceleration(of: field, at: 150), 300, accuracy: 2)
        let fallingOff = SKFieldNode.linearGravityField(withVector: vector_float3(1, 0, 0))
        fallingOff.falloff = 2
        XCTAssertEqual(acceleration(of: fallingOff, at: 75), 600, accuracy: 15)
        XCTAssertEqual(acceleration(of: fallingOff, at: 300), 37.5, accuracy: 0.3)
    }

    /// Not mirrored (PARITY_GAP_PLAN.md P7): a drag field slows a body non-linearly, and from a
    /// strength of about 0.1 drives it to the 36000 points/s speed cap instead of stopping it.
    func testDragFieldsDontSimplySlowBodiesDown() {
        let weak = SKFieldNode.dragField()
        weak.strength = 0.01
        let slowed = samples(under: weak, at: 30, initialVelocity: CGVector(dx: 300, dy: 0)).map(\.vx)
        XCTAssertLessThan(slowed[1], 200)
        XCTAssertGreaterThan(slowed[1], 50)
        let strong = SKFieldNode.dragField()
        strong.strength = 0.1
        let capped = samples(under: strong, at: 30, initialVelocity: CGVector(dx: 300, dy: 0)).map(\.vx)
        XCTAssertEqual(capped[2], 36000, accuracy: 10)
    }
}
