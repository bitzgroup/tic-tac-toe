import SpriteKit
import XCTest

/// A presented 400×400 scene with zero gravity for the physics probes, plus helpers to let the
/// simulation run and to make named bodies.
class SKPhysicsParityTestCase: XCTestCase {
    var window: UIWindow!
    var view: SKView!
    var scene: SKScene!
    var world: SKPhysicsWorld { scene.physicsWorld }

    override func setUp() {
        super.setUp()
        view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        scene = SKScene(size: view.bounds.size)
        scene.physicsWorld.gravity = .zero
        view.presentScene(scene)
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        view = nil
        scene = nil
        super.tearDown()
    }

    /// Lets the presented scene run for about [seconds].
    func runFrames(_ seconds: Double) {
        let done = expectation(description: "frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    /// Adds a node named [name] at [position] carrying [body] to the scene.
    @discardableResult
    func add(_ name: String, _ body: SKPhysicsBody, at position: CGPoint, dynamic: Bool = true) -> SKNode {
        let node = SKNode()
        node.name = name
        node.position = position
        body.isDynamic = dynamic
        node.physicsBody = body
        scene.addChild(node)
        return node
    }

    func name(_ body: SKPhysicsBody?) -> String? { body?.node?.name }
}
