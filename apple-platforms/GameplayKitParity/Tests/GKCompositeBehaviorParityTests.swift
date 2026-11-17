import GameplayKit
import XCTest

/// Records how Apple's `GKCompositeBehavior` combines its member behaviors — which
/// bitzgroup/GameplayKit mirrors — by comparing where agents end up against plain `GKBehavior`s.
/// Acceleration and speed limits are set high so they never clip the steering force.
final class GKCompositeBehaviorParityTests: XCTestCase {
    private let target: GKAgent2D = {
        let agent = GKAgent2D()
        agent.position = vector_float2(100, 50)
        return agent
    }()

    private lazy var seek = GKGoal(toSeekAgent: target)

    private func endPosition(_ behavior: GKBehavior) -> vector_float2 {
        let agent = GKAgent2D()
        agent.maxSpeed = 100_000
        agent.maxAcceleration = 100_000
        agent.mass = 1
        agent.behavior = behavior
        for _ in 0..<3 { agent.update(deltaTime: 1.0 / 30) }
        return agent.position
    }

    func testAMemberBehaviorsWeightMultipliesItsGoalsWeights() {
        let inner = GKBehavior(goal: seek, weight: 2)
        let composite = GKCompositeBehavior(behaviors: [inner], andWeights: [3])
        XCTAssertEqual(endPosition(composite), endPosition(GKBehavior(goal: seek, weight: 6)))
        XCTAssertNotEqual(endPosition(composite), endPosition(GKBehavior(goal: seek, weight: 2)))
        composite.setWeight(0.5, for: inner)
        XCTAssertEqual(endPosition(composite), endPosition(GKBehavior(goal: seek, weight: 1)))
    }

    func testMemberBehaviorsAddUpAndNestedCompositesMultiply() {
        let two = GKCompositeBehavior(
            behaviors: [GKBehavior(goal: seek, weight: 1), GKBehavior(goal: seek, weight: 1)],
            andWeights: [1, 1]
        )
        XCTAssertEqual(endPosition(two), endPosition(GKBehavior(goal: seek, weight: 2)))
        let inner = GKBehavior(goal: seek, weight: 2)
        let nested = GKCompositeBehavior(behaviors: [GKCompositeBehavior(behaviors: [inner], andWeights: [3])], andWeights: [1])
        XCTAssertEqual(endPosition(nested), endPosition(GKBehavior(goal: seek, weight: 6)))
    }

    func testBookkeeping() {
        let inner = GKBehavior(goal: seek, weight: 2)
        let composite = GKCompositeBehavior(behaviors: [inner], andWeights: [3])
        XCTAssertEqual(composite.behaviorCount, 1)
        XCTAssertEqual(composite.goalCount, 0)
        XCTAssertEqual(composite.weight(for: inner), 3)
        XCTAssertEqual(composite.weight(for: GKBehavior()), 0)
        XCTAssertTrue(composite[0] === inner)
        XCTAssertEqual(GKCompositeBehavior(behaviors: [inner]).weight(for: inner), 1)

        let other = GKBehavior(goal: seek, weight: 1)
        composite.setWeight(2, for: other)
        XCTAssertEqual(composite.behaviorCount, 2)
        composite.remove(inner)
        XCTAssertEqual(composite.behaviorCount, 1)
        XCTAssertTrue(composite[0] === other)
        composite.removeAllBehaviors()
        XCTAssertEqual(composite.behaviorCount, 0)
        // Giving a composite a goal of its own crashes Apple's agent update
        // (-[GKBehavior isTargetSpeedGoal]: unrecognized selector) — not recorded as a test.
    }
}
