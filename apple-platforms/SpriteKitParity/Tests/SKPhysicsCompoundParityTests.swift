import SpriteKit
import XCTest

/// Records Apple's compound and path-based physics bodies — `init(bodies:)`,
/// `init(polygonFrom:)`, `init(edgeChainFrom:)`, `init(edgeLoopFrom:)` with a path — which
/// bitzgroup/SpriteKit (PARITY_GAP_PLAN.md P4) mirrors. Areas are in square meters of 150 points.
final class SKPhysicsCompoundParityTests: SKPhysicsParityTestCase {
    /// Where a ball of radius 5, dropped at `x` from y 250, is after 1.5 s over `floor` at (200, 100).
    private func drop(onto floor: SKPhysicsBody, at x: CGFloat) -> CGPoint {
        let floorNode = add("floor", floor, at: CGPoint(x: 200, y: 100), dynamic: false)
        let ball = add("ball", SKPhysicsBody(circleOfRadius: 5), at: CGPoint(x: x, y: 250))
        world.gravity = CGVector(dx: 0, dy: -9.8)
        runFrames(1.5)
        let position = ball.position
        floorNode.removeFromParent()
        ball.removeFromParent()
        world.gravity = .zero
        return position
    }

    private func path(_ points: [CGPoint], closed: Bool = true) -> CGPath {
        let path = CGMutablePath()
        path.addLines(between: points)
        if closed { path.closeSubpath() }
        return path
    }

    private func bar(_ x: CGFloat) -> SKPhysicsBody {
        SKPhysicsBody(rectangleOf: CGSize(width: 40, height: 10), center: CGPoint(x: x, y: 0))
    }

    private let ell = [
        CGPoint(x: -60, y: 0), CGPoint(x: 60, y: 0), CGPoint(x: 60, y: 20),
        CGPoint(x: -20, y: 20), CGPoint(x: -20, y: 60), CGPoint(x: -60, y: 60),
    ]

    /// A compound's area is its parts' summed; its density, restitution and friction are the
    /// first body's, everything else the defaults — whatever the other bodies were set to.
    func testACompoundSumsItsPartsAndTakesTheFirstBodysMaterial() {
        let a = SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: -20, y: 0))
        a.density = 2
        a.restitution = 0.9
        a.friction = 0.3
        a.categoryBitMask = 4
        a.linearDamping = 0.5
        let b = SKPhysicsBody(rectangleOf: CGSize(width: 20, height: 20), center: CGPoint(x: 20, y: 0))
        b.isDynamic = false
        let compound = SKPhysicsBody(bodies: [a, b])
        XCTAssertEqual(compound.area, 0.0317404, accuracy: 1e-6)
        XCTAssertEqual(compound.mass, 0.0634808, accuracy: 1e-6)
        XCTAssertEqual(compound.density, 2)
        XCTAssertEqual(compound.restitution, 0.9, accuracy: 1e-6)
        XCTAssertEqual(compound.friction, 0.3, accuracy: 1e-6)
        XCTAssertEqual(compound.linearDamping, 0.1, accuracy: 1e-6)
        XCTAssertEqual(compound.categoryBitMask, UInt32.max)
        XCTAssertTrue(compound.isDynamic)
        compound.density = 3
        XCTAssertEqual(compound.mass, 0.0952212, accuracy: 1e-6)
    }

    /// Edges add no area; a compound nested in another adds no area but still collides; with no
    /// bodies the density is 0. (With an edge first, Apple's density is NaN — recorded, not
    /// mirrored.)
    func testEdgesAndNestedCompoundsAddNoArea() {
        let edge = SKPhysicsBody(edgeFrom: .zero, to: CGPoint(x: 50, y: 0))
        let withEdge = SKPhysicsBody(bodies: [SKPhysicsBody(circleOfRadius: 10), edge])
        XCTAssertEqual(withEdge.area, 0.0139626, accuracy: 1e-6)
        let inner = SKPhysicsBody(bodies: [SKPhysicsBody(circleOfRadius: 10)])
        let nested = SKPhysicsBody(bodies: [SKPhysicsBody(circleOfRadius: 5, center: CGPoint(x: 30, y: 0)), inner])
        XCTAssertEqual(nested.area, 0.0034913, accuracy: 1e-6)
        XCTAssertEqual(SKPhysicsBody(bodies: []).density, 0)
        let edgeFirst = SKPhysicsBody(edgeFrom: .zero, to: CGPoint(x: 10, y: 0))
        XCTAssertTrue(SKPhysicsBody(bodies: [edgeFirst, SKPhysicsBody(circleOfRadius: 10)]).density.isNaN)

        let innerBar = SKPhysicsBody(rectangleOf: CGSize(width: 60, height: 10), center: CGPoint(x: 50, y: 0))
        let nestedFloor = SKPhysicsBody(bodies: [
            SKPhysicsBody(bodies: [innerBar]),
            SKPhysicsBody(circleOfRadius: 5, center: CGPoint(x: -80, y: 0)),
        ])
        XCTAssertEqual(drop(onto: nestedFloor, at: 250).y, 111.31, accuracy: 0.02)
    }

    /// Every part collides, edges included, and a ball falls through the gap between parts.
    func testEveryPartCollidesAndTheGapsDont() {
        XCTAssertEqual(drop(onto: SKPhysicsBody(bodies: [bar(-60), bar(60)]), at: 140).y, 109.87, accuracy: 0.02)
        XCTAssertEqual(drop(onto: SKPhysicsBody(bodies: [bar(-60), bar(60)]), at: 260).y, 109.87, accuracy: 0.02)
        XCTAssertLessThan(drop(onto: SKPhysicsBody(bodies: [bar(-60), bar(60)]), at: 200).y, 0)
        let circleAndEdge = SKPhysicsBody(bodies: [
            SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: -80, y: 0)),
            SKPhysicsBody(edgeFrom: .zero, to: CGPoint(x: 100, y: 0)),
        ])
        XCTAssertEqual(drop(onto: circleAndEdge, at: 250).y, 106.34, accuracy: 0.02)
    }

    /// A compound turns about its parts' shared center of mass, with their inertias moved there.
    func testACompoundTurnsAboutItsPartsSharedCenterOfMass() {
        let dumbbell = SKPhysicsBody(bodies: [
            SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: -20, y: 0)),
            SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: 20, y: 0)),
        ])
        add("dumbbell", dumbbell, at: CGPoint(x: 200, y: 200))
        dumbbell.applyAngularImpulse(0.01)
        XCTAssertEqual(dumbbell.angularVelocity, 17.904924, accuracy: 1e-4)
        dumbbell.applyImpulse(CGVector(dx: 0, dy: 1), at: CGPoint(x: 220, y: 200))
        XCTAssertEqual(dumbbell.velocity.dy, 35.809856, accuracy: 1e-4)
        XCTAssertEqual(dumbbell.angularVelocity, 19.496473, accuracy: 1e-4)

        let offCenter = SKPhysicsBody(bodies: [SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: 30, y: 0))])
        add("off", offCenter, at: CGPoint(x: 100, y: 100))
        offCenter.applyAngularImpulse(0.01)
        XCTAssertEqual(offCenter.angularVelocity, 322.28888, accuracy: 1e-3)
    }

    /// A point query finds a compound on a part, not in the gap between.
    func testPointQueriesFindACompoundByItsParts() {
        let pair = SKPhysicsBody(bodies: [
            SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: -30, y: 0)),
            SKPhysicsBody(circleOfRadius: 10, center: CGPoint(x: 30, y: 0)),
        ])
        add("q", pair, at: CGPoint(x: 200, y: 200))
        runFrames(0.1)
        XCTAssertEqual(name(world.body(at: CGPoint(x: 230, y: 200))), "q")
        XCTAssertNil(world.body(at: CGPoint(x: 200, y: 200)))
    }

    /// A polygon path may be concave or clockwise, and may be left open: it keeps its full area
    /// and collides in its notch. Only the first subpath counts.
    func testAPolygonPathMayBeConcaveAndOnlyItsFirstSubpathCounts() {
        let l = path([
            CGPoint(x: 0, y: 0), CGPoint(x: 30, y: 0), CGPoint(x: 30, y: 10),
            CGPoint(x: 10, y: 10), CGPoint(x: 10, y: 30), CGPoint(x: 0, y: 30),
        ])
        XCTAssertEqual(SKPhysicsBody(polygonFrom: l).area * 22500, 500, accuracy: 0.01)
        let clockwise = path([CGPoint(x: 0, y: 0), CGPoint(x: 0, y: 20), CGPoint(x: 20, y: 20), CGPoint(x: 20, y: 0)])
        XCTAssertEqual(SKPhysicsBody(polygonFrom: clockwise).area * 22500, 400, accuracy: 0.01)
        let open = path([CGPoint(x: 0, y: 0), CGPoint(x: 20, y: 0), CGPoint(x: 20, y: 20)], closed: false)
        XCTAssertEqual(SKPhysicsBody(polygonFrom: open).area * 22500, 200, accuracy: 0.01)
        let corners: [CGPoint] = (0..<12).map { index in
            let angle = Double(index) * .pi / 6
            return CGPoint(x: 10 * cos(angle), y: 10 * sin(angle))
        }
        XCTAssertEqual(SKPhysicsBody(polygonFrom: path(corners)).area * 22500, 300, accuracy: 0.01)
        let two = CGMutablePath()
        two.addRect(CGRect(x: -60, y: 0, width: 20, height: 10))
        two.addRect(CGRect(x: 40, y: 0, width: 20, height: 10))
        XCTAssertEqual(SKPhysicsBody(polygonFrom: two).area * 22500, 200, accuracy: 0.01)
        XCTAssertEqual(drop(onto: SKPhysicsBody(polygonFrom: two), at: 150).y, 115.88, accuracy: 0.02)
        XCTAssertLessThan(drop(onto: SKPhysicsBody(polygonFrom: two), at: 250).y, 0)

        XCTAssertEqual(drop(onto: SKPhysicsBody(polygonFrom: path(ell)), at: 230).y, 126.02, accuracy: 0.02)
        XCTAssertEqual(drop(onto: SKPhysicsBody(polygonFrom: path(ell)), at: 160).y, 166.11, accuracy: 0.02)
    }

    /// A full circle's path makes an exact circle body — a circle's area, and its inertia about
    /// the circle's center. Other curves are flattened: a 20×10 ellipse into 8 edges.
    func testAFullCirclePathMakesACircleAndOtherCurvesAreFlattened() {
        let circle = CGPath(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20), transform: nil)
        XCTAssertEqual(SKPhysicsBody(polygonFrom: circle).area, SKPhysicsBody(circleOfRadius: 10).area)
        let arc = CGMutablePath()
        arc.addArc(center: .zero, radius: 10, startAngle: 0, endAngle: 2 * .pi, clockwise: false)
        arc.closeSubpath()
        XCTAssertEqual(SKPhysicsBody(polygonFrom: arc).area * 22500, 314.159, accuracy: 0.01)
        let offCircle = CGPath(ellipseIn: CGRect(x: 20, y: -10, width: 20, height: 20), transform: nil)
        let offCenter = add("circle", SKPhysicsBody(polygonFrom: offCircle), at: CGPoint(x: 200, y: 200))
        offCenter.physicsBody!.applyAngularImpulse(0.01)
        XCTAssertEqual(offCenter.physicsBody!.angularVelocity, 322.28888, accuracy: 1e-3)

        let ellipse = CGPath(ellipseIn: CGRect(x: -10, y: -5, width: 20, height: 10), transform: nil)
        XCTAssertEqual(SKPhysicsBody(polygonFrom: ellipse).area * 22500, 141.421, accuracy: 0.01)
        let halfDisc = CGMutablePath()
        halfDisc.addArc(center: .zero, radius: 10, startAngle: 0, endAngle: .pi, clockwise: false)
        halfDisc.closeSubpath()
        XCTAssertEqual(SKPhysicsBody(polygonFrom: halfDisc).area * 22500, 141.421, accuracy: 0.01)
        let big = CGPath(ellipseIn: CGRect(x: -100, y: -50, width: 200, height: 100), transform: nil)
        XCTAssertEqual(SKPhysicsBody(polygonFrom: big).area * 22500, 15538.54, accuracy: 0.1)
    }

    /// Edge chains and loops from paths have no area; a chain follows only the first subpath and
    /// stays open, a loop closes it.
    func testEdgePathsFollowTheFirstSubpath() {
        let v = path([CGPoint(x: -100, y: 50), CGPoint(x: 0, y: 0), CGPoint(x: 100, y: 50)], closed: false)
        XCTAssertEqual(SKPhysicsBody(edgeChainFrom: v).area, 0)
        XCTAssertEqual(SKPhysicsBody(edgeLoopFrom: v).area, 0)
        XCTAssertEqual(drop(onto: SKPhysicsBody(edgeChainFrom: v), at: 230).y, 107.08, accuracy: 0.05)
        let cup = path([
            CGPoint(x: -50, y: 100), CGPoint(x: -50, y: 0), CGPoint(x: 50, y: 0), CGPoint(x: 50, y: 100),
        ], closed: false)
        XCTAssertEqual(drop(onto: SKPhysicsBody(edgeChainFrom: cup), at: 200).y, 106.34, accuracy: 0.02)
        XCTAssertEqual(drop(onto: SKPhysicsBody(edgeLoopFrom: cup), at: 200).y, 206.05, accuracy: 0.02)
        let twoSegments = CGMutablePath()
        twoSegments.move(to: CGPoint(x: -60, y: 0))
        twoSegments.addLine(to: CGPoint(x: -20, y: 0))
        twoSegments.move(to: CGPoint(x: 20, y: 0))
        twoSegments.addLine(to: CGPoint(x: 60, y: 0))
        XCTAssertLessThan(drop(onto: SKPhysicsBody(edgeChainFrom: twoSegments), at: 240).y, 0)
        XCTAssertLessThan(drop(onto: SKPhysicsBody(edgeLoopFrom: twoSegments), at: 240).y, 0)
    }
}
