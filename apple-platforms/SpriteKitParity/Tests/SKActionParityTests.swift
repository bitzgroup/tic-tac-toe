import SpriteKit
import XCTest

/// Records what Apple's `SKAction`s leave a node at once they finish — the behavior
/// bitzgroup/SpriteKit's action factories mirror. Actions run in a presented scene; each test waits
/// for the action's completion block, so mostly end states are recorded, not per-frame curves.
final class SKActionParityTests: XCTestCase {
    private var window: UIWindow!
    private var view: SKView!
    private var scene: SKScene!

    override func setUp() {
        super.setUp()
        view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        view = nil
        scene = nil
        super.tearDown()
    }

    /// Runs `action` on `node` (added to the scene if it has no parent) and waits for it to finish.
    private func run(_ action: SKAction, on node: SKNode) {
        if node.parent == nil { scene.addChild(node) }
        let done = expectation(description: "action finished")
        node.run(action) { done.fulfill() }
        wait(for: [done], timeout: 5)
    }

    /// Lets the scene render frames for `seconds`.
    private func waitFrames(_ seconds: TimeInterval) {
        let done = expectation(description: "frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    // MARK: scale(by:) is multiplicative

    func testScaleByMultipliesTheCurrentScale() {
        let node = SKNode()
        node.xScale = 2
        node.yScale = 3
        run(SKAction.scale(by: 2, duration: 0.05), on: node)
        XCTAssertEqual(node.xScale, 4, accuracy: 0.001)
        XCTAssertEqual(node.yScale, 6, accuracy: 0.001)
    }

    func testScaleXByYMultipliesEachAxis() {
        let node = SKNode()
        node.xScale = 2
        node.yScale = 3
        run(SKAction.scaleX(by: 2, y: 0.5, duration: 0.05), on: node)
        XCTAssertEqual(node.xScale, 4, accuracy: 0.001)
        XCTAssertEqual(node.yScale, 1.5, accuracy: 0.001)
    }

    func testReversedScaleByDividesByTheFactor() {
        let node = SKNode()
        node.xScale = 2
        node.yScale = 3
        run(SKAction.scale(by: 2, duration: 0.05).reversed(), on: node)
        XCTAssertEqual(node.xScale, 1, accuracy: 0.001)
        XCTAssertEqual(node.yScale, 1.5, accuracy: 0.001)
    }

    // MARK: rotate(toAngle:)

    func testRotateToAngleInterpolatesTheLongWayByDefaultAndEndsOnTheTarget() {
        let node = SKNode()
        node.zRotation = 0.1
        scene.addChild(node)
        node.run(SKAction.rotate(toAngle: 6, duration: 1))
        waitFrames(0.5)
        // Halfway between 0.1 and 6 — not near 0, where the shortest arc would be.
        XCTAssertGreaterThan(node.zRotation, 1)
        XCTAssertLessThan(node.zRotation, 5)
        waitFrames(0.7)
        XCTAssertEqual(node.zRotation, 6, accuracy: 0.001)
    }

    func testRotateToAngleShortestUnitArcTakesTheShortWayAndEndsExactlyOnTheTarget() {
        let node = SKNode()
        node.zRotation = 0.1
        scene.addChild(node)
        node.run(SKAction.rotate(toAngle: 6, duration: 1, shortestUnitArc: true))
        waitFrames(0.5)
        // Between 6 and 6.38 (= 0.1 + 2π): the short way, expressed relative to the target.
        XCTAssertGreaterThan(node.zRotation, 6)
        XCTAssertLessThan(node.zRotation, 6.4)
        waitFrames(0.7)
        XCTAssertEqual(node.zRotation, 6, accuracy: 0.001)
    }

    func testRotateToAngleShortestUnitArcEndsOnTheTargetFromMoreThanATurnAway() {
        let node = SKNode()
        node.zRotation = 7
        run(SKAction.rotate(toAngle: 0.5, duration: 0.05, shortestUnitArc: true), on: node)
        XCTAssertEqual(node.zRotation, 0.5, accuracy: 0.001)
    }

    // MARK: single-axis move/scale/resize (A1)

    func testMoveToYLeavesXAlone() {
        let node = SKNode()
        node.position = CGPoint(x: 1, y: 2)
        run(SKAction.moveTo(y: 9, duration: 0.05), on: node)
        XCTAssertEqual(node.position, CGPoint(x: 1, y: 9))
    }

    func testScaleXToLeavesYAlone() {
        let node = SKNode()
        node.xScale = 2
        node.yScale = 3
        run(SKAction.scaleX(to: 5, duration: 0.05), on: node)
        XCTAssertEqual(node.xScale, 5, accuracy: 0.001)
        XCTAssertEqual(node.yScale, 3, accuracy: 0.001)
    }

    func testResizeToWidthAndHeightChangeOneDimensionEach() {
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        run(SKAction.resize(toWidth: 30, duration: 0.05), on: sprite)
        XCTAssertEqual(sprite.size, CGSize(width: 30, height: 20))
        run(SKAction.resize(toHeight: 40, duration: 0.05), on: sprite)
        XCTAssertEqual(sprite.size, CGSize(width: 30, height: 40))
    }

    func testScaleToSizeSetsTheScaleThatGivesASpriteThatSizeWhateverItsCurrentScale() {
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        sprite.xScale = 2
        run(SKAction.scale(to: CGSize(width: 40, height: 10), duration: 0.05), on: sprite)
        XCTAssertEqual(sprite.xScale, 4, accuracy: 0.001)
        XCTAssertEqual(sprite.yScale, 0.5, accuracy: 0.001)
        // A sprite's `size` includes its scale (see SKSpriteSizeParityTests).
        XCTAssertEqual(sprite.size, CGSize(width: 40, height: 10))
    }

    func testScaleToSizeLeavesANonSpriteAlone() {
        let shape = SKShapeNode(rectOf: CGSize(width: 10, height: 20))
        run(SKAction.scale(to: CGSize(width: 40, height: 10), duration: 0.05), on: shape)
        XCTAssertEqual(shape.xScale, 1)
        XCTAssertEqual(shape.yScale, 1)
    }

    // MARK: setTexture (A3)

    private func texture(width: CGFloat, height: CGFloat) -> SKTexture {
        SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: width, height: height)).image { _ in })
    }

    func testSetTextureIsInstantAndKeepsTheSpritesSize() {
        let action = SKAction.setTexture(texture(width: 7, height: 5))
        XCTAssertEqual(action.duration, 0)
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        run(action, on: sprite)
        XCTAssertNotNil(sprite.texture)
        XCTAssertEqual(sprite.size, CGSize(width: 10, height: 20))
    }

    func testSetTextureResizeSizesTheSpriteToTheTexture() {
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        run(SKAction.setTexture(texture(width: 7, height: 5), resize: true), on: sprite)
        XCTAssertEqual(sprite.size, CGSize(width: 7, height: 5))
    }

    // MARK: duration (A8)

    func testCompositeDurationsAreDerivedFromTheirChildren() {
        let move = SKAction.moveBy(x: 1, y: 0, duration: 0.5)
        XCTAssertEqual(SKAction.sequence([move, move]).duration, 1, accuracy: 0.001)
        let group = SKAction.group([SKAction.wait(forDuration: 0.3), SKAction.wait(forDuration: 0.7)])
        XCTAssertEqual(group.duration, 0.7, accuracy: 0.001)
        XCTAssertEqual(SKAction.repeat(SKAction.wait(forDuration: 0.2), count: 3).duration, 0.6, accuracy: 0.001)
    }

    func testSettingALeafActionsDurationChangesHowLongItRuns() {
        let move = SKAction.moveBy(x: 10, y: 0, duration: 5)
        move.duration = 0.05
        let node = SKNode()
        let start = Date()
        run(move, on: node)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1)
        XCTAssertEqual(node.position.x, 10, accuracy: 0.001)
    }

    func testSettingASequencesDurationDoesNotChangeHowLongItRuns() {
        let sequence = SKAction.sequence([
            SKAction.moveBy(x: 10, y: 0, duration: 0.5),
            SKAction.moveBy(x: 10, y: 0, duration: 0.5),
        ])
        sequence.duration = 0.1
        let node = SKNode()
        let start = Date()
        run(sequence, on: node)
        XCTAssertGreaterThan(Date().timeIntervalSince(start), 0.8)
        XCTAssertEqual(node.position.x, 20, accuracy: 0.01)
    }

    // MARK: node speed (N2, A4)

    func testANodesSpeedScalesItsDescendantsActions() {
        let parent = SKNode()
        parent.speed = 2
        let child = SKNode()
        parent.addChild(child)
        scene.addChild(parent)
        let start = Date()
        run(SKAction.wait(forDuration: 0.6), on: child)
        XCTAssertLessThan(Date().timeIntervalSince(start), 0.5)
    }

    func testAZeroSpeedNodeRunsNothing() {
        let node = SKNode()
        node.speed = 0
        scene.addChild(node)
        node.run(SKAction.moveBy(x: 5, y: 0, duration: 0.05))
        waitFrames(0.3)
        XCTAssertEqual(node.position, .zero)
        XCTAssertTrue(node.hasActions())
    }

    func testSpeedToSetsTheNodesSpeed() {
        let node = SKNode()
        run(SKAction.speed(to: 3, duration: 0.05), on: node)
        XCTAssertEqual(node.speed, 3, accuracy: 0.001)
    }

    func testSpeedByMultipliesAndItsReverseDivides() {
        let node = SKNode()
        node.speed = 3
        run(SKAction.speed(by: 0.5, duration: 0.05), on: node)
        XCTAssertEqual(node.speed, 1.5, accuracy: 0.001)
        let other = SKNode()
        other.speed = 3
        run(SKAction.speed(by: 0.5, duration: 0.05).reversed(), on: other)
        XCTAssertEqual(other.speed, 6, accuracy: 0.001)
    }
}
