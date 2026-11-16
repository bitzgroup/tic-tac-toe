import SpriteKit
import XCTest

/// Records which nodes Apple's `SKCameraNode.containedNodeSet()` returns, which
/// bitzgroup/SpriteKit's mirrors.
final class SKCameraParityTests: XCTestCase {
    private func sprite(_ name: String, at position: CGPoint) -> SKSpriteNode {
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 10))
        sprite.name = name
        sprite.position = position
        return sprite
    }

    func testContainedNodeSetHasEveryDescendantWhoseFrameReachesTheViewport() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 400, height: 400))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        defer { window.isHidden = true }
        let scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)
        let camera = SKCameraNode()
        camera.position = CGPoint(x: 200, y: 200)
        scene.addChild(camera)
        scene.camera = camera

        let inside = sprite("inside", at: CGPoint(x: 200, y: 200))
        scene.addChild(inside)
        inside.addChild(sprite("descendant", at: .zero))
        scene.addChild(sprite("straddlingTheEdge", at: CGPoint(x: 403, y: 200)))
        scene.addChild(sprite("outside", at: CGPoint(x: 900, y: 900)))
        let hidden = sprite("hidden", at: CGPoint(x: 200, y: 200))
        hidden.isHidden = true
        scene.addChild(hidden)
        let empty = SKNode()
        empty.name = "emptyNode"
        empty.position = CGPoint(x: 200, y: 200)
        scene.addChild(empty)

        let contained = camera.containedNodeSet()
        XCTAssertEqual(
            Set(contained.compactMap(\.name)),
            ["inside", "descendant", "straddlingTheEdge", "hidden"]
        )
        XCTAssertFalse(contained.contains(camera))
        XCTAssertFalse(contained.contains(scene))
    }
}
