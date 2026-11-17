import SpriteKit
import XCTest

/// Logs every lifecycle and frame-loop callback the scene itself receives.
private final class LoggingScene: SKScene {
    var log: [String] = []
    var sizeAtLoad: CGSize?
    var updateTimes: [TimeInterval] = []

    override func sceneDidLoad() {
        log.append("sceneDidLoad")
        sizeAtLoad = size
    }

    override func didMove(to view: SKView) { log.append("didMove") }
    override func willMove(from view: SKView) { log.append("willMove") }

    override func update(_ currentTime: TimeInterval) {
        log.append("update")
        updateTimes.append(currentTime)
    }

    override func didEvaluateActions() { log.append("didEvaluateActions") }
    override func didSimulatePhysics() { log.append("didSimulatePhysics") }
    override func didApplyConstraints() { log.append("didApplyConstraints") }
    override func didFinishUpdate() { log.append("didFinishUpdate") }
}

/// A delegate that writes into the scene's own log, so one array shows the interleaving.
private final class LoggingDelegate: NSObject, SKSceneDelegate {
    weak var scene: LoggingScene?
    var updateTimes: [TimeInterval] = []
    var scenesSeen: [SKScene] = []

    func update(_ currentTime: TimeInterval, for scene: SKScene) {
        self.scene?.log.append("delegate.update")
        updateTimes.append(currentTime)
        scenesSeen.append(scene)
    }

    func didEvaluateActions(for scene: SKScene) { self.scene?.log.append("delegate.didEvaluateActions") }
    func didSimulatePhysics(for scene: SKScene) { self.scene?.log.append("delegate.didSimulatePhysics") }
    func didApplyConstraints(for scene: SKScene) { self.scene?.log.append("delegate.didApplyConstraints") }
    func didFinishUpdate(for scene: SKScene) { self.scene?.log.append("delegate.didFinishUpdate") }
}

/// A delegate implementing only `update(_:for:)` — the other methods are optional.
private final class UpdateOnlyDelegate: NSObject, SKSceneDelegate {
    weak var scene: LoggingScene?

    func update(_ currentTime: TimeInterval, for scene: SKScene) {
        self.scene?.log.append("delegate.update")
    }
}

/// Records Apple's `SKScene.sceneDidLoad()` and `SKSceneDelegate` behavior — what
/// bitzgroup/SpriteKit's `PARITY_GAP_PLAN.md` S1/S2 mirror.
final class SKSceneLifecycleParityTests: XCTestCase {
    private var window: UIWindow!
    private var view: SKView!

    override func setUp() {
        super.setUp()
        view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        view = nil
        super.tearDown()
    }

    private func runFrames(_ seconds: Double = 0.3) {
        let done = expectation(description: "frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    /// The callbacks of the first complete frame in [log] (from an `update` or `delegate.update` up
    /// to and including the last `didFinishUpdate` entry before the next frame starts).
    private func firstFrame(_ log: [String]) -> [String] {
        guard let start = log.firstIndex(where: { $0 == "update" || $0 == "delegate.update" }) else { return [] }
        var frame: [String] = []
        for entry in log[start...] {
            let startsFrame = entry == "update" || entry == "delegate.update"
            if startsFrame, frame.contains(where: { $0.hasSuffix("didFinishUpdate") }) { break }
            frame.append(entry)
        }
        return frame
    }

    // MARK: - sceneDidLoad (S1)

    func testSceneDidLoadRunsOnceDuringInitWithTheSizeAlreadySet() {
        let scene = LoggingScene(size: CGSize(width: 123, height: 45))
        XCTAssertEqual(scene.log, ["sceneDidLoad"])
        XCTAssertEqual(scene.sizeAtLoad, CGSize(width: 123, height: 45))
    }

    func testSceneDidLoadRunsForTheNoArgumentInitializerTooWhoseSizeIsOneByOne() {
        let scene = LoggingScene()
        XCTAssertEqual(scene.log, ["sceneDidLoad"])
        XCTAssertEqual(scene.sizeAtLoad, CGSize(width: 1, height: 1))
        XCTAssertEqual(scene.size, CGSize(width: 1, height: 1))
    }

    func testPresentingAndRepresentingNeverCallsSceneDidLoadAgain() {
        let scene = LoggingScene(size: view.bounds.size)
        view.presentScene(scene)
        view.presentScene(SKScene(size: view.bounds.size))
        view.presentScene(scene)
        XCTAssertEqual(scene.log, ["sceneDidLoad", "didMove", "willMove", "didMove"])
    }

    func testChangingTheSizeAfterLoadDoesNotCallSceneDidLoad() {
        let scene = LoggingScene(size: CGSize(width: 10, height: 10))
        scene.size = CGSize(width: 20, height: 20)
        XCTAssertEqual(scene.log, ["sceneDidLoad"])
    }

    // MARK: - Frame order without a delegate

    func testFrameCallbacksRunInThisOrder() {
        let scene = LoggingScene(size: view.bounds.size)
        view.presentScene(scene)
        runFrames()
        XCTAssertEqual(
            firstFrame(scene.log),
            ["update", "didEvaluateActions", "didSimulatePhysics", "didApplyConstraints", "didFinishUpdate"],
        )
    }

    // MARK: - SKSceneDelegate (S2)

    func testADelegateReplacesTheScenesOwnFrameCallbacks() {
        let scene = LoggingScene(size: view.bounds.size)
        let delegate = LoggingDelegate()
        delegate.scene = scene
        scene.delegate = delegate
        view.presentScene(scene)
        runFrames()
        XCTAssertEqual(
            firstFrame(scene.log),
            [
                "delegate.update", "delegate.didEvaluateActions", "delegate.didSimulatePhysics",
                "delegate.didApplyConstraints", "delegate.didFinishUpdate",
            ],
        )
        XCTAssertFalse(scene.log.contains("update"))
        XCTAssertFalse(scene.log.contains("didFinishUpdate"))
    }

    /// The replacement is per method: a callback the delegate doesn't implement still reaches the
    /// scene's own override.
    func testADelegateReplacesOnlyTheCallbacksItImplements() {
        let scene = LoggingScene(size: view.bounds.size)
        let delegate = UpdateOnlyDelegate()
        delegate.scene = scene
        scene.delegate = delegate
        view.presentScene(scene)
        runFrames()
        XCTAssertEqual(
            firstFrame(scene.log),
            ["delegate.update", "didEvaluateActions", "didSimulatePhysics", "didApplyConstraints", "didFinishUpdate"],
        )
        XCTAssertFalse(scene.log.contains("update"))
    }

    func testTheDelegateIsPassedTheSceneAndTheSameKindOfTimestamp() {
        let scene = LoggingScene(size: view.bounds.size)
        view.presentScene(scene)
        runFrames()
        let sceneTime = scene.updateTimes.last ?? 0

        let delegate = LoggingDelegate()
        delegate.scene = scene
        scene.delegate = delegate
        runFrames()
        XCTAssertTrue(delegate.scenesSeen.allSatisfy { $0 === scene })
        // Same clock as the scene's own update(_:) — monotonically continuing, not reset to 0.
        XCTAssertGreaterThan(delegate.updateTimes.first ?? 0, sceneTime)
    }

    func testThePausedSceneCallsNeitherItsOwnCallbacksNorTheDelegates() {
        let scene = LoggingScene(size: view.bounds.size)
        let delegate = LoggingDelegate()
        delegate.scene = scene
        scene.delegate = delegate
        view.presentScene(scene)
        scene.isPaused = true
        scene.log.removeAll()
        runFrames()
        XCTAssertEqual(scene.log, [])
    }

    func testTheDelegateIsHeldWeakly() {
        let scene = LoggingScene(size: view.bounds.size)
        var delegate: LoggingDelegate? = LoggingDelegate()
        weak var weakDelegate = delegate
        scene.delegate = delegate
        delegate = nil
        XCTAssertNil(weakDelegate)
        XCTAssertNil(scene.delegate)
    }

    func testClearingTheDelegateRestoresTheScenesOwnCallbacks() {
        let scene = LoggingScene(size: view.bounds.size)
        let delegate = LoggingDelegate()
        delegate.scene = scene
        scene.delegate = delegate
        view.presentScene(scene)
        runFrames()
        scene.delegate = nil
        scene.log.removeAll()
        runFrames()
        XCTAssertEqual(
            firstFrame(scene.log),
            ["update", "didEvaluateActions", "didSimulatePhysics", "didApplyConstraints", "didFinishUpdate"],
        )
    }
}
