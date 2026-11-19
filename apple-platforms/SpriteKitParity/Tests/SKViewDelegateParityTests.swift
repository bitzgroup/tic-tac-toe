import SpriteKit
import XCTest

private final class CountingScene: SKScene {
    var updates: [TimeInterval] = []
    var finishedUpdates = 0
    override func update(_ currentTime: TimeInterval) { updates.append(currentTime) }
    override func didFinishUpdate() { finishedUpdates += 1 }
}

private final class Gate: NSObject, SKViewDelegate {
    var allow = true
    var times: [TimeInterval] = []
    func view(_ view: SKView, shouldRenderAtTime time: TimeInterval) -> Bool {
        times.append(time)
        return allow
    }
}

/// Records Apple's `SKView.delegate` (`SKViewDelegate.view(_:shouldRenderAtTime:)`),
/// `shouldCullNonVisibleNodes` and `isAsynchronous`, which bitzgroup/SpriteKit
/// (PARITY_GAP_PLAN.md V5) mirrors.
final class SKViewDelegateParityTests: XCTestCase {
    private func wait(_ seconds: Double) {
        let waited = expectation(description: "waited")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { waited.fulfill() }
        wait(for: [waited], timeout: seconds + 2)
    }

    func testDefaults() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        XCTAssertTrue(view.shouldCullNonVisibleNodes)
        XCTAssertTrue(view.isAsynchronous)
        XCTAssertNil(view.delegate)
    }

    /// The delegate is asked once a frame, before `update`, with the time `update` then gets.
    /// Answering `false` skips the frame — no `update`, no actions — and the skipped time isn't
    /// lost: once frames run again, a 100-points-a-second move catches up on all of it at once.
    /// A paused view doesn't ask at all.
    func testTheDelegateGatesEachFrame() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        defer { window.isHidden = true }
        let scene = CountingScene(size: view.bounds.size)
        let gate = Gate()
        view.delegate = gate
        let mover = SKNode()
        scene.addChild(mover)
        mover.run(SKAction.moveBy(x: 100, y: 0, duration: 1))
        view.presentScene(scene)
        wait(0.3)
        XCTAssertGreaterThan(scene.updates.count, 5)
        XCTAssertEqual(gate.times.count, scene.updates.count)
        XCTAssertEqual(scene.finishedUpdates, scene.updates.count)
        XCTAssertEqual(gate.times.suffix(3), scene.updates.suffix(3))

        gate.allow = false
        let updates = scene.updates.count
        let asked = gate.times.count
        let x = mover.position.x
        wait(0.3)
        XCTAssertGreaterThan(gate.times.count - asked, 5)
        XCTAssertEqual(scene.updates.count, updates)
        XCTAssertEqual(mover.position.x, x)

        gate.allow = true
        wait(0.1)
        // 0.3 s skipped plus 0.1 s run: about 40 points, not the 10 that 0.1 s alone would move.
        XCTAssertGreaterThan(mover.position.x - x, 30)

        view.isPaused = true
        let askedBeforePause = gate.times.count
        wait(0.3)
        XCTAssertEqual(gate.times.count, askedBeforePause)
    }
}
