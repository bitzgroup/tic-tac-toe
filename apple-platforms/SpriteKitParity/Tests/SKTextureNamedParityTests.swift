import SpriteKit
import XCTest

/// Records Apple's `SKTexture(imageNamed:)` / `SKSpriteNode(imageNamed:)`, which
/// bitzgroup/SpriteKit mirrors by loading from the host app's `assets/`. `ParityProbe.png` is a
/// 4×2 image bundled with the host app.
final class SKTextureNamedParityTests: XCTestCase {
    func testANamedImageLoadsAtItsPixelSizeWithOrWithoutTheExtension() {
        XCTAssertEqual(SKTexture(imageNamed: "ParityProbe").size(), CGSize(width: 4, height: 2))
        XCTAssertEqual(SKTexture(imageNamed: "ParityProbe.png").size(), CGSize(width: 4, height: 2))
    }

    func testANamedTextureDefaultsToLinearFiltering() {
        XCTAssertEqual(SKTexture(imageNamed: "ParityProbe").filteringMode, .linear)
    }

    func testAMissingImageGivesA128PointPlaceholderNotNil() {
        XCTAssertEqual(SKTexture(imageNamed: "no-such-image").size(), CGSize(width: 128, height: 128))
    }

    func testANamedSpriteTakesTheTextureSizeAndLeavesItsNameUnset() {
        let sprite = SKSpriteNode(imageNamed: "ParityProbe")
        XCTAssertEqual(sprite.size, CGSize(width: 4, height: 2))
        XCTAssertNil(sprite.name)
        XCTAssertNotNil(sprite.texture)
        XCTAssertEqual(SKSpriteNode(imageNamed: "no-such-image").size, CGSize(width: 128, height: 128))
    }
}
