import SpriteKit
import XCTest

/// Records how Apple's `SKView.isPaused` and `SKScene.isPaused` interact — the behavior
/// bitzgroup/SpriteKit's `SKView.isPaused` mirrors. Backgrounding is covered by the UI tests.
final class SKViewPauseParityTests: XCTestCase {
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

    func testPausingTheViewPausesThePresentedSceneAndUnpausingUnpausesIt() {
        let scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)
        view.isPaused = true
        XCTAssertTrue(scene.isPaused)
        view.isPaused = false
        XCTAssertFalse(scene.isPaused)
    }

    func testSettingTheViewsUnchangedPausedStateLeavesTheSceneAlone() {
        let scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)
        scene.isPaused = true
        view.isPaused = false
        XCTAssertTrue(scene.isPaused)
    }

    func testUnpausingTheSceneOfAPausedViewLeavesTheViewPaused() {
        let scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)
        view.isPaused = true
        scene.isPaused = false
        XCTAssertTrue(view.isPaused)
        XCTAssertFalse(scene.isPaused)
    }

    func testPresentingAPausedSceneUnpausesIt() {
        let scene = SKScene(size: view.bounds.size)
        scene.isPaused = true
        view.presentScene(scene)
        XCTAssertFalse(scene.isPaused)
    }

    func testPresentingIntoAPausedViewUnpausesBothTheViewAndTheIncomingScene() {
        view.presentScene(SKScene(size: view.bounds.size))
        view.isPaused = true
        let next = SKScene(size: view.bounds.size)
        next.isPaused = true
        view.presentScene(next)
        XCTAssertFalse(next.isPaused)
        XCTAssertFalse(view.isPaused)
    }

    // presentScene(_:transition:) is not recorded here: SKTransition.pausesIncomingScene (true by
    // default) pauses the incoming scene during the transition, and a hosted unit test doesn't
    // render frames reliably enough for the transition to complete.
}
