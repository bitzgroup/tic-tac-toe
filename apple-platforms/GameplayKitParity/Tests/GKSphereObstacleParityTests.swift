import GameplayKit
import XCTest

/// Records how Apple's agents avoid `GKSphereObstacle` and `GKCircleObstacle`, which
/// bitzgroup/GameplayKit (PARITY_GAP_PLAN.md G3) mirrors. Only the direction of the swerve is
/// asserted, not exact positions: the steering formulas aren't the same.
///
/// Every run: radius-1 agent, maxSpeed 5, maxAcceleration 20, 240 steps of 1/60 s, weights 10 to
/// avoid a radius-2 obstacle with maxPredictionTime 2 and 1 to keep speed 5.
final class GKSphereObstacleParityTests: XCTestCase {
    private func goals(_ obstacle: GKObstacle) -> GKBehavior {
        GKBehavior(goals: [GKGoal(toAvoid: [obstacle], maxPredictionTime: 2), GKGoal(toReachTargetSpeed: 5)], andWeights: [10, 1])
    }

    private func sphere(_ x: Float, _ y: Float, _ z: Float) -> GKSphereObstacle {
        let sphere = GKSphereObstacle(radius: 2)
        sphere.position = vector_float3(x, y, z)
        return sphere
    }

    private func circle(_ x: Float, _ y: Float) -> GKCircleObstacle {
        let circle = GKCircleObstacle(radius: 2)
        circle.position = vector_float2(x, y)
        return circle
    }

    /// A 3D agent starting at the origin heading along +z (its default heading).
    private func run3D(_ obstacle: GKObstacle) -> vector_float3 {
        let agent = GKAgent3D()
        agent.maxSpeed = 5
        agent.maxAcceleration = 20
        agent.radius = 1
        agent.speed = 5
        agent.behavior = goals(obstacle)
        for _ in 0..<240 { agent.update(deltaTime: 1.0 / 60) }
        return agent.position
    }

    /// A 2D agent starting at the origin heading along +x.
    private func run2D(_ obstacle: GKObstacle) -> vector_float2 {
        let agent = GKAgent2D()
        agent.maxSpeed = 5
        agent.maxAcceleration = 20
        agent.radius = 1
        agent.rotation = 0
        agent.speed = 5
        agent.behavior = goals(obstacle)
        for _ in 0..<240 { agent.update(deltaTime: 1.0 / 60) }
        return agent.position
    }

    private func assertStraight3D(_ p: vector_float3, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(p.x, 0, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(p.y, 0, accuracy: 0.01, file: file, line: line)
        XCTAssertEqual(p.z, 20, accuracy: 0.01, file: file, line: line)
    }

    func testASphereObstacleStartsAtTheOrigin() {
        let sphere = GKSphereObstacle(radius: 2)
        XCTAssertEqual(sphere.radius, 2)
        XCTAssertEqual(sphere.position, vector_float3(0, 0, 0))
        sphere.radius = 3
        sphere.position = vector_float3(1, 2, 3)
        XCTAssertEqual(sphere.radius, 3)
        XCTAssertEqual(sphere.position, vector_float3(1, 2, 3))
    }

    /// The probes below lean on this: a new 3D agent heads along +z, and setting speed moves it there.
    func testA3DAgentHeadsAlongPlusZByDefault() {
        let agent = GKAgent3D()
        XCTAssertEqual(agent.velocity, vector_float3(0, 0, 0))
        agent.speed = 2
        XCTAssertEqual(agent.velocity, vector_float3(0, 0, 2))
    }

    func testA3DAgentSwervesAwayFromASphereAhead() {
        let offRight = run3D(sphere(0.5, 0, 10))
        XCTAssertLessThan(offRight.x, -5)
        XCTAssertEqual(offRight.y, 0, accuracy: 0.01)
        XCTAssertGreaterThan(offRight.z, 10)

        XCTAssertGreaterThan(run3D(sphere(-0.5, 0, 10)).x, 5)

        let offUp = run3D(sphere(0, 0.5, 10))
        XCTAssertLessThan(offUp.y, -5)
        XCTAssertEqual(offUp.x, 0, accuracy: 0.01)
    }

    func testA3DAgentIgnoresASphereItWouldClear() {
        assertStraight3D(run3D(sphere(6, 0, 10)))
        assertStraight3D(run3D(sphere(3.5, 0, 10))) // 3.5 > 1 + 2 radii
        assertStraight3D(run3D(sphere(0.5, 0, -5))) // behind it
    }

    /// Apple keeps every agent in one 3D space where a 2D (x, y) is (x, 0, y): a circle at (x, y)
    /// is a sphere at (x, 0, y) to a 3D agent.
    func testA3DAgentTreatsACircleAtXYAsASphereAtX0Y() {
        XCTAssertLessThan(run3D(circle(0.5, 10)).x, -5)
        assertStraight3D(run3D(circle(10, 0.5)))
    }

    /// ...and a sphere at (x, y, z) is a circle at (x, z) to a 2D agent.
    func testA2DAgentTreatsASphereAtXYZAsACircleAtXZ() {
        XCTAssertLessThan(run2D(circle(10, 0.5)).y, -5) // baseline
        XCTAssertLessThan(run2D(sphere(10, 0, 0.5)).y, -5)
        let ignored = run2D(sphere(10, 0.5, 50))
        XCTAssertEqual(ignored.x, 20, accuracy: 0.01)
        XCTAssertEqual(ignored.y, 0, accuracy: 0.01)
    }

    func testMovingAnObstacleAfterAnAgentUsedItTakesEffect() {
        let moved = circle(10, 0.5)
        _ = run2D(moved)
        moved.position = vector_float2(10, -0.5)
        XCTAssertGreaterThan(run2D(moved).y, 5)
    }
}
