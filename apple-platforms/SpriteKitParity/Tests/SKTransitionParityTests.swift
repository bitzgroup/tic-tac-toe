import SpriteKit
import XCTest

/// Records the defaults of Apple's `SKTransition.pausesIncomingScene`/`pausesOutgoingScene`,
/// which bitzgroup/SpriteKit mirrors. What they do is recorded by `SKTransitionParityUITests`.
final class SKTransitionParityTests: XCTestCase {
    func testBothScenesArePausedByDefault() {
        let transitions: [SKTransition] = [
            .fade(withDuration: 1), .crossFade(withDuration: 1), .push(with: .left, duration: 1),
            .doorway(withDuration: 1), .doorsOpenHorizontal(withDuration: 1), .doorsCloseVertical(withDuration: 1),
        ]
        for transition in transitions {
            XCTAssertTrue(transition.pausesIncomingScene)
            XCTAssertTrue(transition.pausesOutgoingScene)
        }
    }
}
