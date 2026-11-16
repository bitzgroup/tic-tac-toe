import SpriteKit
import XCTest

/// Records what Apple actually draws for `SKView.ignoresSiblingOrder` (draw order) and
/// `SKSpriteNode.centerRect` (9-slice stretching), which bitzgroup/SpriteKit mirrors. Each test
/// renders a node with `SKView.texture(from:)` and reads pixels back.
final class SKRenderPixelParityTests: XCTestCase {
    private var window: UIWindow!
    private var view: SKView!
    private var scene: SKScene!

    override func setUp() {
        super.setUp()
        view = SKView(frame: CGRect(x: 0, y: 0, width: 100, height: 100))
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

    private enum Color: Equatable { case red, green, blue, other }

    /// Renders [node] and returns a sampler taking a point measured from the bottom-left of
    /// the node's accumulated frame, in points.
    private func render(_ node: SKNode) -> (CGPoint) -> Color {
        let texture = view.texture(from: node)!
        let image = texture.cgImage()
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let scale = CGFloat(width) / texture.size().width
        return { point in
            let x = Int(point.x * scale)
            let row = height - 1 - Int(point.y * scale) // the bitmap's first row is the top
            let i = (row * width + x) * 4
            switch (pixels[i] > 200, pixels[i + 1] > 200, pixels[i + 2] > 200) {
            case (true, false, false): return .red
            case (false, true, false): return .green
            case (false, false, true): return .blue
            default: return .other
            }
        }
    }

    private func square(_ color: UIColor, _ side: CGFloat = 20) -> SKSpriteNode {
        SKSpriteNode(color: color, size: CGSize(width: side, height: side))
    }

    func testIgnoresSiblingOrderDefaultsToFalse() {
        XCTAssertFalse(view.ignoresSiblingOrder)
    }

    func testWithSiblingOrderEqualZLaterSiblingsAndChildrenDrawOnTop() {
        let container = SKNode()
        container.addChild(square(.red))
        container.addChild(square(.green, 10))
        scene.addChild(container)
        let sample = render(container)
        XCTAssertEqual(sample(CGPoint(x: 10, y: 10)), .green)
        XCTAssertEqual(sample(CGPoint(x: 2, y: 2)), .red)

        let parent = square(.red)
        parent.addChild(square(.blue, 10))
        scene.addChild(parent)
        XCTAssertEqual(render(parent)(CGPoint(x: 10, y: 10)), .blue)
    }

    func testZPositionBeatsSiblingOrderAndAccumulatesFromAncestors() {
        let container = SKNode()
        let back = square(.red)
        back.zPosition = 1
        container.addChild(back)
        container.addChild(square(.green, 10))
        scene.addChild(container)
        XCTAssertEqual(render(container)(CGPoint(x: 10, y: 10)), .red)

        let parent = square(.red)
        let child = square(.blue, 10)
        child.zPosition = -1
        parent.addChild(child)
        scene.addChild(parent)
        XCTAssertEqual(render(parent)(CGPoint(x: 10, y: 10)), .red)
    }

    /// A 3×3 texture: red corners, green edges, blue center.
    private func nineSliceTexture() -> SKTexture {
        let r: [UInt8] = [255, 0, 0, 255]
        let g: [UInt8] = [0, 255, 0, 255]
        let b: [UInt8] = [0, 0, 255, 255]
        let rows = [r + g + r, g + b + g, r + g + r]
        let texture = SKTexture(data: Data(rows.flatMap { $0 }), size: CGSize(width: 3, height: 3))
        texture.filteringMode = .nearest
        return texture
    }

    func testCenterRectDefaultsToTheWholeTexture() {
        XCTAssertEqual(SKSpriteNode(texture: nineSliceTexture()).centerRect, CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    func testCenterRectKeepsCornersAtTextureSizeWhenTheSizeGrows() {
        let sprite = SKSpriteNode(texture: nineSliceTexture())
        sprite.centerRect = CGRect(x: 1.0 / 3, y: 1.0 / 3, width: 1.0 / 3, height: 1.0 / 3)
        sprite.size = CGSize(width: 30, height: 30)
        scene.addChild(sprite)
        let sample = render(sprite)
        XCTAssertEqual(sample(CGPoint(x: 0.5, y: 0.5)), .red)
        XCTAssertEqual(sample(CGPoint(x: 29.5, y: 29.5)), .red)
        XCTAssertEqual(sample(CGPoint(x: 2, y: 2)), .blue)
        XCTAssertEqual(sample(CGPoint(x: 15, y: 0.5)), .green)
        XCTAssertEqual(sample(CGPoint(x: 0.5, y: 15)), .green)
        XCTAssertEqual(sample(CGPoint(x: 15, y: 15)), .blue)
    }

    func testCenterRectAlsoAppliesWhenGrownByScale() {
        let sprite = SKSpriteNode(texture: nineSliceTexture())
        sprite.centerRect = CGRect(x: 1.0 / 3, y: 1.0 / 3, width: 1.0 / 3, height: 1.0 / 3)
        sprite.setScale(10)
        scene.addChild(sprite)
        let sample = render(sprite)
        XCTAssertEqual(sample(CGPoint(x: 0.5, y: 0.5)), .red)
        XCTAssertEqual(sample(CGPoint(x: 2, y: 2)), .blue)
        XCTAssertEqual(sample(CGPoint(x: 15, y: 15)), .blue)
    }

    func testWithoutCenterRectTheWholeTextureStretches() {
        let sprite = SKSpriteNode(texture: nineSliceTexture())
        sprite.size = CGSize(width: 30, height: 30)
        scene.addChild(sprite)
        let sample = render(sprite)
        XCTAssertEqual(sample(CGPoint(x: 5, y: 5)), .red)
        XCTAssertEqual(sample(CGPoint(x: 15, y: 15)), .blue)
    }
}
