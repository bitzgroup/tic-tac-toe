import SpriteKit
import XCTest

/// Records how Apple's `SKSpriteNode.size` relates to the node's scale, which
/// bitzgroup/SpriteKit's `SKSpriteNode.size` mirrors: `size` is the sprite's unscaled size times
/// the magnitude of its scale, and assigning it stores the value divided by that magnitude.
final class SKSpriteSizeParityTests: XCTestCase {
    func testSizeIncludesTheScaleMagnitude() {
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        sprite.xScale = 2
        XCTAssertEqual(sprite.size, CGSize(width: 20, height: 20))
        sprite.setScale(3)
        XCTAssertEqual(sprite.size, CGSize(width: 30, height: 60))
        sprite.xScale = -1
        XCTAssertEqual(sprite.size, CGSize(width: 10, height: 60))
    }

    func testAssigningSizeStoresItDividedByTheScale() {
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        sprite.xScale = 2
        sprite.size = CGSize(width: 30, height: 30)
        XCTAssertEqual(sprite.size, CGSize(width: 30, height: 30))
        XCTAssertEqual(sprite.xScale, 2)
        sprite.xScale = 1
        XCTAssertEqual(sprite.size, CGSize(width: 15, height: 30))
    }

    func testAZeroScaleKeepsTheUnscaledSize() {
        let sprite = SKSpriteNode(color: .red, size: CGSize(width: 10, height: 20))
        sprite.xScale = 0
        XCTAssertEqual(sprite.size, CGSize(width: 0, height: 20))
        sprite.xScale = 2
        XCTAssertEqual(sprite.size, CGSize(width: 20, height: 20))
    }

    func testATexturedSpritesSizeScalesTooAndSurvivesATextureSwap() {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 7, height: 5)).image { _ in }
        let sprite = SKSpriteNode(texture: SKTexture(image: image))
        sprite.xScale = 2
        XCTAssertEqual(sprite.size, CGSize(width: 14, height: 5))
        sprite.texture = SKTexture(image: UIGraphicsImageRenderer(size: CGSize(width: 9, height: 9)).image { _ in })
        XCTAssertEqual(sprite.size, CGSize(width: 14, height: 5))
    }
}
