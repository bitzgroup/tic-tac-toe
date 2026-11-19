import SpriteKit
import XCTest

private final class TaggedSprite: SKSpriteNode {
    var tag = 0
}

private final class Delegate: NSObject, SKSceneDelegate, SKPhysicsContactDelegate {}

/// Records what Apple's `SKNode.copy()` copies, which bitzgroup/SpriteKit (PARITY_GAP_PLAN.md N4)
/// mirrors: a deep copy of the node and its subtree, detached from any parent.
final class SKNodeCopyParityTests: XCTestCase {
    private func configuredSprite() -> SKSpriteNode {
        let node = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        node.name = "n"
        node.position = CGPoint(x: 3, y: 4)
        node.zPosition = 2
        node.zRotation = 1
        node.xScale = 2
        node.alpha = 0.5
        node.isHidden = true
        node.isPaused = true
        node.speed = 3
        node.isUserInteractionEnabled = true
        node.colorBlendFactor = 0.25
        node.anchorPoint = CGPoint(x: 0, y: 1)
        node.blendMode = .add
        return node
    }

    func testTheCopyHasTheSamePropertiesAndNoParent() {
        let scene = SKScene(size: CGSize(width: 100, height: 100))
        let node = configuredSprite()
        scene.addChild(node)
        let copy = node.copy() as! SKSpriteNode
        XCTAssertNil(copy.parent)
        XCTAssertNil(copy.scene)
        XCTAssertEqual(copy.name, "n")
        XCTAssertEqual(copy.position, CGPoint(x: 3, y: 4))
        XCTAssertEqual(copy.zPosition, 2)
        XCTAssertEqual(copy.zRotation, 1)
        XCTAssertEqual(copy.xScale, 2)
        XCTAssertEqual(copy.alpha, 0.5)
        XCTAssertTrue(copy.isHidden)
        XCTAssertTrue(copy.isPaused)
        XCTAssertEqual(copy.speed, 3)
        XCTAssertTrue(copy.isUserInteractionEnabled)
        XCTAssertEqual(copy.size, node.size)
        XCTAssertEqual(copy.color, node.color)
        XCTAssertEqual(copy.colorBlendFactor, 0.25)
        XCTAssertEqual(copy.anchorPoint, CGPoint(x: 0, y: 1))
        XCTAssertEqual(copy.blendMode, .add)
    }

    /// Children are copied too, all the way down, each copy parented to the copied parent; a
    /// shape's path is copied rather than shared.
    func testChildrenAreCopiedDeeply() {
        let node = SKNode()
        let label = SKLabelNode(text: "child")
        label.fontSize = 13
        node.addChild(label)
        let shape = SKShapeNode(circleOfRadius: 3)
        shape.fillColor = .blue
        shape.lineWidth = 4
        label.addChild(shape)
        let copy = node.copy() as! SKNode
        let copiedLabel = copy.children.first as! SKLabelNode
        XCTAssertFalse(copiedLabel === label)
        XCTAssertTrue(copiedLabel.parent === copy)
        XCTAssertEqual(copiedLabel.text, "child")
        XCTAssertEqual(copiedLabel.fontSize, 13)
        let copiedShape = copiedLabel.children.first as! SKShapeNode
        XCTAssertFalse(copiedShape === shape)
        XCTAssertEqual(copiedShape.lineWidth, 4)
        XCTAssertEqual(copiedShape.fillColor, .blue)
        XCTAssertFalse(copiedShape.path === shape.path)
        XCTAssertEqual(copiedShape.path?.boundingBox, shape.path?.boundingBox)
    }

    /// The physics body is copied (a new body, attached to the copy) with its settings and its
    /// velocity; `userData` is a new dictionary holding the same values; constraints and textures
    /// are shared.
    func testWhatIsCopiedAndWhatIsShared() {
        let texture = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 2, height: 2)).image { _ in })
        let node = SKSpriteNode(texture: texture)
        node.physicsBody = SKPhysicsBody(circleOfRadius: 5)
        node.physicsBody!.mass = 7
        node.physicsBody!.categoryBitMask = 4
        node.physicsBody!.velocity = CGVector(dx: 100, dy: 0)
        node.userData = ["k": NSMutableArray(array: [1])]
        node.constraints = [SKConstraint.zRotation(SKRange(constantValue: 0))]
        let copy = node.copy() as! SKSpriteNode
        XCTAssertTrue(copy.texture === texture)
        let body = copy.physicsBody!
        XCTAssertFalse(body === node.physicsBody)
        XCTAssertTrue(body.node === copy)
        XCTAssertEqual(body.mass, 7, accuracy: 0.001)
        XCTAssertEqual(body.categoryBitMask, 4)
        XCTAssertEqual(body.velocity, CGVector(dx: 100, dy: 0))
        XCTAssertFalse(copy.userData === node.userData)
        XCTAssertTrue((copy.userData!["k"] as AnyObject) === (node.userData!["k"] as AnyObject))
        XCTAssertTrue(copy.constraints!.first === node.constraints!.first)
    }

    /// Running actions are copied under their keys, as new actions that start over: a node copied
    /// halfway through a move moves the whole distance again from where it was copied.
    func testRunningActionsAreCopiedAndStartOver() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        defer { window.isHidden = true }
        let scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)
        let mover = SKNode()
        scene.addChild(mover)
        mover.run(SKAction.moveBy(x: 100, y: 0, duration: 0.6), withKey: "move")
        let half = expectation(description: "half")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { half.fulfill() }
        wait(for: [half], timeout: 2)
        let copy = mover.copy() as! SKNode
        XCTAssertNotNil(copy.action(forKey: "move"))
        XCTAssertFalse(copy.action(forKey: "move") === mover.action(forKey: "move"))
        let start = copy.position.x
        XCTAssertGreaterThan(start, 10)
        scene.addChild(copy)
        let done = expectation(description: "done")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { done.fulfill() }
        wait(for: [done], timeout: 3)
        XCTAssertEqual(copy.position.x, start + 100, accuracy: 0.01)
    }

    /// A copied subclass instance keeps its class, but not its Swift stored properties: the copy is
    /// made through `NSCoding`, which a subclass has to extend to carry its own.
    func testASubclassKeepsItsClassButNotItsOwnProperties() {
        let node = TaggedSprite(color: .red, size: CGSize(width: 1, height: 1))
        node.tag = 9
        let copy = node.copy()
        XCTAssertTrue(copy is TaggedSprite)
        XCTAssertEqual((copy as? TaggedSprite)?.tag, 0)
    }

    /// A crop node's mask is copied too, not shared.
    func testACropNodesMaskIsCopied() {
        let crop = SKCropNode()
        crop.maskNode = SKSpriteNode(color: .red, size: CGSize(width: 4, height: 4))
        let copy = crop.copy() as! SKCropNode
        XCTAssertNotNil(copy.maskNode)
        XCTAssertFalse(copy.maskNode === crop.maskNode)
        XCTAssertEqual((copy.maskNode as? SKSpriteNode)?.size, CGSize(width: 4, height: 4))
    }

    /// A copied scene keeps its settings; its camera is the copy of the original camera node; its
    /// delegates aren't copied.
    func testACopiedScenePointsAtItsOwnCameraAndDropsDelegates() {
        let scene = SKScene(size: CGSize(width: 100, height: 50))
        scene.scaleMode = .aspectFit
        scene.anchorPoint = CGPoint(x: 0.5, y: 0.5)
        scene.backgroundColor = .red
        scene.physicsWorld.gravity = CGVector(dx: 1, dy: 2)
        scene.physicsWorld.speed = 0.5
        let delegate = Delegate()
        scene.delegate = delegate
        scene.physicsWorld.contactDelegate = delegate
        let holder = SKNode()
        let camera = SKCameraNode()
        holder.addChild(camera)
        scene.addChild(holder)
        scene.camera = camera
        let copy = scene.copy() as! SKScene
        XCTAssertEqual(copy.size, CGSize(width: 100, height: 50))
        XCTAssertEqual(copy.scaleMode, .aspectFit)
        XCTAssertEqual(copy.anchorPoint, CGPoint(x: 0.5, y: 0.5))
        XCTAssertEqual(copy.backgroundColor, .red)
        XCTAssertEqual(copy.physicsWorld.gravity, CGVector(dx: 1, dy: 2))
        XCTAssertEqual(copy.physicsWorld.speed, 0.5)
        XCTAssertTrue(copy.camera === copy.children.first?.children.first)
        XCTAssertNil(copy.delegate)
        XCTAssertNil(copy.physicsWorld.contactDelegate)
    }

    func testAnEmitterKeepsItsSettings() {
        let emitter = SKEmitterNode()
        emitter.particleBirthRate = 5
        emitter.particleLifetime = 2
        emitter.particleColor = .green
        let copy = emitter.copy() as! SKEmitterNode
        XCTAssertEqual(copy.particleBirthRate, 5)
        XCTAssertEqual(copy.particleLifetime, 2)
        XCTAssertEqual(copy.particleColor, .green)
    }
}
