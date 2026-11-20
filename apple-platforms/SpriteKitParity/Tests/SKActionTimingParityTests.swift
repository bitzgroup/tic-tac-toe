import SpriteKit
import XCTest

/// Records how Apple's actions spend time: `wait(forDuration:withRange:)` draws a new length on
/// every run, and a `group` hands on the time its last action didn't need — which
/// bitzgroup/SpriteKit (PARITY_GAP_PLAN.md A7) mirrors.
final class SKActionTimingParityTests: XCTestCase {
    /// Keeps the frame's time and, after each frame's actions, the tracked nodes' x positions.
    final class Clock: SKScene {
        var now: TimeInterval = 0
        var frames: [[CGFloat]] = []
        var tracked: [SKNode] = []
        override func update(_ currentTime: TimeInterval) { now = currentTime }
        override func didEvaluateActions() {
            if !tracked.isEmpty { frames.append(tracked.map { $0.position.x }) }
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

    /// A ranged wait reports its base duration, and draws a new length within the range on every
    /// pass of a `repeat` and on every node the same action runs on.
    func testARangedWaitDrawsANewLengthOnEveryRun() {
        let wait = SKAction.wait(forDuration: 0.3, withRange: 0.4)
        XCTAssertEqual(wait.duration, 0.3, accuracy: 1e-6)
        var first: [TimeInterval] = []
        var second: [TimeInterval] = []
        for (index, node) in [SKNode(), SKNode()].enumerated() {
            scene.addChild(node)
            node.run(.repeat(.sequence([wait, .run { [unowned self] in
                if index == 0 { first.append(self.scene.now) } else { second.append(self.scene.now) }
            }]), count: 8))
        }
        waitFrames(5)
        let firstGaps = zip(first.dropFirst(), first).map { $0 - $1 }
        let secondGaps = zip(second.dropFirst(), second).map { $0 - $1 }
        XCTAssertEqual(firstGaps.count, 7)
        for gap in firstGaps + secondGaps {
            XCTAssertGreaterThanOrEqual(gap, 0.1 - 0.02)
            XCTAssertLessThanOrEqual(gap, 0.5 + 0.02)
        }
        XCTAssertGreaterThan(Set(firstGaps.map { ($0 * 60).rounded() }).count, 2)
        XCTAssertNotEqual(firstGaps.map { ($0 * 60).rounded() }, secondGaps.map { ($0 * 60).rounded() })
        XCTAssertEqual(wait.duration, 0.3, accuracy: 1e-6)
    }

    /// A group inside a sequence hands on the time its last action didn't need: the next action
    /// runs exactly as it does after a plain wait of the same length — 1000 points a second,
    /// 11.67 points one frame (1/60 s) after the 0.105-second wait ends.
    func testAGroupHandsOnTheTimeItsLastActionDidntNeed() {
        let plain = SKNode()
        let grouped = SKNode()
        let nested = SKNode()
        for node in [plain, grouped, nested] { scene.addChild(node) }
        scene.tracked = [plain, grouped, nested]
        let move = SKAction.moveBy(x: 1000, y: 0, duration: 1)
        plain.run(.sequence([.wait(forDuration: 0.105), move]))
        grouped.run(.sequence([.group([.wait(forDuration: 0.105), .wait(forDuration: 0.05)]), move]))
        let longerSequence = SKAction.sequence([.wait(forDuration: 0.03), .wait(forDuration: 0.075)])
        nested.run(.sequence([.group([.wait(forDuration: 0.05), longerSequence]), move]))
        waitFrames(0.5)
        let moving = scene.frames.filter { $0[0] > 0 }
        XCTAssertGreaterThan(moving.count, 5)
        XCTAssertEqual(moving[0][0], 11.6667, accuracy: 0.01)
        for frame in moving {
            XCTAssertEqual(frame[1], frame[0], accuracy: 0.001)
            XCTAssertEqual(frame[2], frame[0], accuracy: 0.001)
        }
    }
}
