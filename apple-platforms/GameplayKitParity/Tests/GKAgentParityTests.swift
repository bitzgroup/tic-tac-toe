import GameplayKit
import XCTest

/// Records Apple's `GKAgent2D`/`GKAgent3D` defaults and how `speed`, `rotation` and `velocity`
/// relate, which bitzgroup/GameplayKit (PARITY_GAP_PLAN.md G10) mirrors.
final class GKAgentParityTests: XCTestCase {
    func testAgentDefaults() {
        for agent in [GKAgent2D(), GKAgent3D()] as [GKAgent] {
            XCTAssertEqual(agent.speed, 0)
            XCTAssertEqual(agent.maxSpeed, 1)
            XCTAssertEqual(agent.maxAcceleration, 1)
            XCTAssertEqual(agent.mass, 1)
            XCTAssertEqual(agent.radius, 0.5)
        }
        XCTAssertEqual(GKAgent2D().rotation, .pi / 2, accuracy: 1e-6)
        XCTAssertEqual(GKAgent2D().velocity, vector_float2(0, 0))
        XCTAssertEqual(GKAgent3D().velocity, vector_float3(0, 0, 0))
    }

    /// Velocity is read-only: it is always the heading times `speed`, and setting either moves it.
    func testA2DAgentsVelocityIsItsHeadingTimesSpeed() {
        let agent = GKAgent2D()
        agent.speed = 3
        XCTAssertEqual(agent.velocity.x, 0, accuracy: 1e-5) // heading pi/2: along +y
        XCTAssertEqual(agent.velocity.y, 3, accuracy: 1e-5)
        agent.rotation = 0
        XCTAssertEqual(agent.velocity, vector_float2(3, 0))
        XCTAssertEqual(agent.speed, 3)
    }

    func testANegativeSpeedIsKeptAndPointsVelocityBackward() {
        let agent = GKAgent2D()
        agent.rotation = 0
        agent.speed = -2
        XCTAssertEqual(agent.speed, -2)
        XCTAssertEqual(agent.velocity.x, -2, accuracy: 1e-5)
        XCTAssertEqual(agent.rotation, 0)
    }

    func testAZeroSpeedKeepsTheRotation() {
        let agent = GKAgent2D()
        agent.rotation = 1
        agent.speed = 0
        XCTAssertEqual(agent.velocity, vector_float2(0, 0))
        XCTAssertEqual(agent.rotation, 1)

        let still = GKAgent2D()
        still.rotation = 0.5
        still.maxSpeed = 5
        still.update(deltaTime: 1)
        XCTAssertEqual(still.rotation, 0.5)
        XCTAssertEqual(still.position, vector_float2(0, 0))
    }

    func testA2DRotationIsWrappedIntoZeroToTwoPi() {
        let agent = GKAgent2D()
        agent.rotation = 7
        XCTAssertEqual(agent.rotation, 7 - 2 * .pi, accuracy: 1e-5)
        agent.rotation = -1
        XCTAssertEqual(agent.rotation, 2 * .pi - 1, accuracy: 1e-5)
    }

    /// A coasting agent moves at `speed`, capped at `maxSpeed` — but only once it updates.
    func testACoastingAgentMovesAtItsSpeedCappedByMaxSpeed() {
        let capped = GKAgent2D()
        capped.rotation = 0
        capped.maxSpeed = 2
        capped.speed = 5
        XCTAssertEqual(capped.speed, 5)
        capped.update(deltaTime: 1)
        XCTAssertEqual(capped.position, vector_float2(2, 0))
        XCTAssertEqual(capped.speed, 2)

        let free = GKAgent2D()
        free.rotation = 0
        free.maxSpeed = 10
        free.speed = 5
        free.update(deltaTime: 1)
        XCTAssertEqual(free.position, vector_float2(5, 0))

        let byDefault = GKAgent2D() // maxSpeed 1
        byDefault.rotation = 0
        byDefault.speed = 5
        byDefault.update(deltaTime: 1)
        XCTAssertEqual(byDefault.position, vector_float2(1, 0))
    }

    func testSteeringKeepsSpeedAndRotationInStepWithVelocity() {
        let agent = GKAgent2D()
        agent.rotation = 0
        agent.maxSpeed = 5
        agent.maxAcceleration = 100
        agent.speed = 1
        let target = GKAgent2D()
        target.position = vector_float2(0, 10)
        agent.behavior = GKBehavior(goal: GKGoal(toSeekAgent: target), weight: 1)
        for _ in 0..<10 { agent.update(deltaTime: 0.05) }
        XCTAssertEqual(agent.speed, simd_length(agent.velocity), accuracy: 1e-4)
        XCTAssertEqual(agent.rotation, atan2(agent.velocity.y, agent.velocity.x), accuracy: 1e-4)
        XCTAssertGreaterThan(agent.position.y, agent.position.x)
    }

    // MARK: - GKAgent3D

    /// The rotation matrix's first column is the heading; a new agent heads along +z.
    func testA3DAgentsVelocityIsTheRotationsFirstColumnTimesSpeed() {
        let agent = GKAgent3D()
        XCTAssertEqual(agent.rotation.columns.0, vector_float3(0, 0, 1))
        agent.speed = 3
        XCTAssertEqual(agent.velocity, vector_float3(0, 0, 3))
        agent.rotation = matrix_identity_float3x3
        XCTAssertEqual(agent.velocity, vector_float3(3, 0, 0))
        agent.speed = -1
        XCTAssertEqual(agent.velocity.x, -1, accuracy: 1e-6)
    }

    func testRightHandedDoesNotChangeTheDefaultHeading() {
        let agent = GKAgent3D()
        agent.rightHanded = false
        agent.speed = 1
        XCTAssertEqual(agent.velocity, vector_float3(0, 0, 1))
    }

    func testA3DAgentCoastsAlongZAtItsDefaultMaxSpeed() {
        let agent = GKAgent3D()
        agent.speed = 5
        agent.update(deltaTime: 1)
        XCTAssertEqual(agent.position, vector_float3(0, 0, 1))
        XCTAssertEqual(agent.speed, 1)
    }

    // A mass of 0 makes Apple's agents' positions NaN on update, so it isn't probed.
}
