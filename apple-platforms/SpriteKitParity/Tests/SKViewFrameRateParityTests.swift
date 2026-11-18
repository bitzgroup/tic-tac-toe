import SpriteKit
import XCTest

private final class TimingScene: SKScene {
    var updates = 0
    override func update(_ currentTime: TimeInterval) { updates += 1 }
}

/// Records how Apple's `SKView.preferredFramesPerSecond` sets the frame rate on a 60 Hz display,
/// which bitzgroup/SpriteKit (PARITY_GAP_PLAN.md V3) mirrors.
///
/// Every rate is measured on one view, changed in turn: several views alive in one test process
/// were seen to disturb each other's rates.
final class SKViewFrameRateParityTests: XCTestCase {
    func testTheRateIsReadBackAsSet() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertEqual(view.preferredFramesPerSecond, 60)
        for fps in [30, 45, 0, -3, 1000] {
            view.preferredFramesPerSecond = fps
            XCTAssertEqual(view.preferredFramesPerSecond, fps)
        }
    }

    /// Only whole fractions of 60 are possible; a rate runs at the nearest one, ties going up
    /// (11 and 25). Not every rate follows that: Apple runs 24 and 45 at 30, the only two of 11...60
    /// that differ (a sweep of all fifty), so they aren't asserted here.
    func testTheViewRunsAtTheNearestWholeFractionOfTheDisplayRate() throws {
        guard UIScreen.main.maximumFramesPerSecond == 60 else { throw XCTSkip("needs a 60 Hz display") }
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        let scene = TimingScene(size: view.bounds.size)
        view.presentScene(scene)

        let expected: [(Int, Int)] = [
            (60, 60), (30, 30), (20, 20), (15, 15),
            (50, 60), (46, 60), (40, 30), (26, 30), (25, 30), (23, 20), (18, 20), (17, 15), (14, 15),
            (13, 12), (11, 12),
            (-5, 60), (120, 60), (1000, 60),
            // Last, as a change away from a once-a-second rate waits for that second's frame.
            (1, 1), (0, 1),
        ]
        for (fps, rate) in expected {
            view.preferredFramesPerSecond = fps
            let settled = expectation(description: "settled")
            let settle = rate == 1 ? 1.2 : 0.4
            DispatchQueue.main.asyncAfter(deadline: .now() + settle) { scene.updates = 0; settled.fulfill() }
            wait(for: [settled], timeout: 3)
            let measured = expectation(description: "measured")
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { measured.fulfill() }
            wait(for: [measured], timeout: 4)
            XCTAssertEqual(Double(scene.updates) / 2, Double(rate), accuracy: rate == 1 ? 0.5 : 1.5, "preferredFramesPerSecond \(fps)")
        }
        window.isHidden = true
    }
}
