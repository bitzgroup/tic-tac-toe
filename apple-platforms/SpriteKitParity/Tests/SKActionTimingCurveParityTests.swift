import SpriteKit
import XCTest

/// Records the curves behind Apple's `SKActionTimingMode`s, which Apple doesn't document —
/// bitzgroup/SpriteKit (PARITY_GAP_PLAN.md A10) mirrors them. Sampled frame by frame from a
/// one-second `moveBy`, every mode fits a cubic exactly:
///
/// - `easeIn` is 2t² − t³ (a quarter of the way: 7/64; halfway: 3/8)
/// - `easeOut` is its mirror, 1 − easeIn(1 − t) = t + t² − t³ (halfway: 5/8)
/// - `easeInEaseOut` is 3t² − 2t³ (halfway: 1/2)
final class SKActionTimingCurveParityTests: XCTestCase {
    /// Keeps the frame's time and, after each frame's actions, the tracked node's x position.
    final class Clock: SKScene {
        var now: TimeInterval = 0
        var samples: [(time: TimeInterval, x: CGFloat)] = []
        var tracked: SKNode?
        override func update(_ currentTime: TimeInterval) { now = currentTime }
        override func didEvaluateActions() {
            if let tracked { samples.append((now, tracked.position.x)) }
        }
    }

    private var window: UIWindow!
    private var view: SKView!
    private var scene: Clock!

    override func setUp() {
        super.setUp()
        view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        scene = Clock(size: view.bounds.size)
        view.presentScene(scene)
        waitFrames(0.2)
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        view = nil
        scene = nil
        super.tearDown()
    }

    private func waitFrames(_ seconds: TimeInterval) {
        let done = expectation(description: "frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    /// Runs a one-second, 1000-point `moveBy` with [mode] and returns each frame's
    /// (time since the move started, fraction of the distance covered).
    private func record(_ mode: SKActionTimingMode) -> [(t: CGFloat, progress: CGFloat)] {
        let node = SKNode()
        scene.addChild(node)
        let move = SKAction.moveBy(x: 1000, y: 0, duration: 1)
        move.timingMode = mode
        var start: TimeInterval = 0
        scene.samples = []
        scene.tracked = node
        node.run(.sequence([.run { [unowned self] in start = self.scene.now }, move]))
        waitFrames(1.3)
        scene.tracked = nil
        node.removeFromParent()
        return scene.samples
            .map { (CGFloat($0.time - start), $0.x / 1000) }
            .filter { $0.t > 0 && $0.t < 1 }
    }

    private func assertFollows(
        _ mode: SKActionTimingMode,
        _ curve: (CGFloat) -> CGFloat,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let samples = record(mode)
        XCTAssertGreaterThan(samples.count, 30, file: file, line: line)
        for sample in samples {
            XCTAssertEqual(sample.progress, curve(sample.t), accuracy: 0.0002, "t = \(sample.t)", file: file, line: line)
        }
    }

    func testLinearIsTheIdentity() {
        assertFollows(.linear) { $0 }
    }

    func testEaseInIsTwoTSquaredMinusTCubed() {
        assertFollows(.easeIn) { t in 2 * t * t - t * t * t }
    }

    func testEaseOutMirrorsEaseIn() {
        assertFollows(.easeOut) { t in t + t * t - t * t * t }
    }

    func testEaseInEaseOutIsSmoothstep() {
        assertFollows(.easeInEaseOut) { t in 3 * t * t - 2 * t * t * t }
    }
}
