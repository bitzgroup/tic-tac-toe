import GameplayKit
import XCTest

/// Records Apple's `GKStateMachine` behavior at the edges the documentation leaves open.
final class GKStateMachineParityTests: XCTestCase {
    private final class LoggingState: GKState {
        static var log: [String] = []
        override func didEnter(from previousState: GKState?) {
            Self.log.append("didEnter from \(previousState == nil ? "nil" : "\(type(of: previousState!))")")
        }
        override func willExit(to nextState: GKState) { Self.log.append("willExit to \(type(of: nextState))") }
        override func update(deltaTime seconds: TimeInterval) { Self.log.append("update") }
    }

    private final class OtherState: GKState {}

    override func setUp() {
        LoggingState.log = []
    }

    func testUpdateWithNoCurrentStateDoesNothing() {
        let machine = GKStateMachine(states: [LoggingState(), OtherState()])
        machine.update(deltaTime: 0.1)
        XCTAssertNil(machine.currentState)
        XCTAssertEqual(LoggingState.log, [])
    }

    /// Re-entering the current state is a full transition: `willExit` then `didEnter`, both with the
    /// state itself, and `enter` returns `true` (the default `isValidNextState` allows it).
    func testEnteringTheCurrentStateRunsAFullTransition() {
        let machine = GKStateMachine(states: [LoggingState(), OtherState()])
        XCTAssertTrue(machine.enter(LoggingState.self))
        LoggingState.log = []
        XCTAssertTrue(machine.canEnterState(LoggingState.self))
        XCTAssertTrue(machine.enter(LoggingState.self))
        XCTAssertEqual(LoggingState.log, ["willExit to LoggingState", "didEnter from LoggingState"])
    }

    private final class PlainState: GKState {}

    /// Apple doesn't check registration: `canEnterState`/`enter` report success for a state class
    /// the machine doesn't hold, and `enter` drops `currentState` to `nil`. On the way it passes
    /// `nil` to the current state's `willExit(to:)` — which crashes any Swift override of it, so
    /// this probe's current state doesn't override it. bitzgroup/GameplayKit deliberately rejects
    /// unregistered states instead (recorded in its docs/API_COMPATIBILITY.md).
    func testEnteringAnUnregisteredStateSucceedsAndClearsTheCurrentState() {
        let machine = GKStateMachine(states: [PlainState()])
        XCTAssertTrue(machine.canEnterState(OtherState.self))
        XCTAssertTrue(machine.enter(OtherState.self))
        XCTAssertNil(machine.currentState)

        XCTAssertTrue(machine.enter(PlainState.self))
        XCTAssertTrue(machine.enter(OtherState.self))
        XCTAssertNil(machine.currentState)
    }


}
