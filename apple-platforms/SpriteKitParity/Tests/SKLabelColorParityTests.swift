import SpriteKit
import XCTest

/// Records how Apple tints an `SKLabelNode` with `color`/`colorBlendFactor` and what its
/// `blendMode` does, which bitzgroup/SpriteKit mirrors. Each test renders a node with
/// `SKView.texture(from:)` and reads back its pixels (premultiplied RGBA, 0–255).
final class SKLabelColorParityTests: XCTestCase {
    private var window: UIWindow!
    private var view: SKView!
    private var scene: SKScene!

    override func setUp() {
        super.setUp()
        view = SKView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
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

    private struct Pixel: Equatable, CustomStringConvertible {
        let r, g, b, a: Int
        init(_ r: Int, _ g: Int, _ b: Int, _ a: Int) { (self.r, self.g, self.b, self.a) = (r, g, b, a) }
        var description: String { "(\(r), \(g), \(b), \(a))" }
        /// Equal within one step, to allow for rounding.
        func isClose(to other: Pixel) -> Bool {
            abs(r - other.r) <= 1 && abs(g - other.g) <= 1 && abs(b - other.b) <= 1 && abs(a - other.a) <= 1
        }
    }

    private func pixels(_ node: SKNode) -> (pixels: [UInt8], width: Int, height: Int) {
        scene.addChild(node)
        defer { node.removeFromParent() }
        let image = view.texture(from: node)!.cgImage()
        let width = image.width
        let height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixels, width, height)
    }

    private func pixel(_ p: [UInt8], _ i: Int) -> Pixel { Pixel(Int(p[i]), Int(p[i + 1]), Int(p[i + 2]), Int(p[i + 3])) }

    /// The most opaque pixel of [node]'s rendering: the inside of a glyph.
    private func solidPixel(_ node: SKNode) -> Pixel {
        let (p, _, _) = pixels(node)
        var best = 0
        for i in stride(from: 0, to: p.count, by: 4) where p[i + 3] > p[best + 3] { best = i }
        return pixel(p, best)
    }

    private func centerPixel(_ node: SKNode) -> Pixel {
        let (p, width, height) = pixels(node)
        return pixel(p, ((height / 2) * width + width / 2) * 4)
    }

    private func label(fontColor: UIColor, color: UIColor? = nil, blend: CGFloat) -> SKLabelNode {
        let label = SKLabelNode(text: "M")
        label.fontName = "Helvetica-Bold"
        label.fontSize = 80
        label.fontColor = fontColor
        if let color { label.color = color }
        label.colorBlendFactor = blend
        return label
    }

    private func assertPixel(_ actual: Pixel, _ expected: Pixel, file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(actual.isClose(to: expected), "\(actual) is not \(expected)", file: file, line: line)
    }

    func testDefaults() {
        let label = SKLabelNode(text: "M")
        var (r, g, b, a) = (CGFloat(0), CGFloat(0), CGFloat(0), CGFloat(0))
        XCTAssertTrue(label.color?.getRed(&r, green: &g, blue: &b, alpha: &a) ?? false)
        XCTAssertEqual([r, g, b, a], [1, 1, 1, 1])
        XCTAssertEqual(label.colorBlendFactor, 0)
        XCTAssertEqual(label.blendMode, .alpha)
    }

    func testAFactorOfZeroLeavesTheFontColor() {
        assertPixel(solidPixel(label(fontColor: .white, color: .red, blend: 0)), Pixel(255, 255, 255, 255))
    }

    /// The text is multiplied by `color`, mixed in by the factor — the same tint a sprite's texture gets.
    func testColorMultipliesTheText() {
        assertPixel(solidPixel(label(fontColor: .white, color: .red, blend: 1)), Pixel(255, 0, 0, 255))
        assertPixel(solidPixel(label(fontColor: .white, color: .red, blend: 0.5)), Pixel(255, 127, 127, 255))
        assertPixel(solidPixel(label(fontColor: .blue, color: .red, blend: 1)), Pixel(0, 0, 0, 255))
        assertPixel(solidPixel(label(fontColor: .blue, color: .red, blend: 0.5)), Pixel(0, 0, 127, 255))
        assertPixel(solidPixel(label(fontColor: UIColor(white: 0.5, alpha: 1), color: .red, blend: 1)), Pixel(128, 0, 0, 255))
        assertPixel(solidPixel(label(fontColor: .yellow, color: .blue, blend: 0.5)), Pixel(127, 127, 0, 255))
    }

    func testColorsAlphaIsMixedInToo() {
        let halfRed = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        assertPixel(solidPixel(label(fontColor: .white, color: halfRed, blend: 1)), Pixel(127, 0, 0, 127))
        assertPixel(solidPixel(label(fontColor: .white, color: halfRed, blend: 0.5)), Pixel(191, 95, 95, 191))
    }

    func testTheFactorIsClamped() {
        assertPixel(solidPixel(label(fontColor: .blue, color: .red, blend: 2)), Pixel(0, 0, 0, 255))
        assertPixel(solidPixel(label(fontColor: .blue, color: .red, blend: -1)), Pixel(0, 0, 255, 255))
    }

    func testSpritesTintTheSameWay() {
        let white = SKTexture(data: Data([UInt8](repeating: 255, count: 64)), size: CGSize(width: 4, height: 4))
        let sprite = SKSpriteNode(texture: white, size: CGSize(width: 20, height: 20))
        sprite.color = UIColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        sprite.colorBlendFactor = 0.5
        assertPixel(solidPixel(sprite), Pixel(191, 95, 95, 191))
    }

    /// An untextured sprite is its color (alpha included) whatever the factor.
    func testAnUntexturedSpriteIsItsColorAtAnyFactor() {
        let sprite = SKSpriteNode(color: UIColor(red: 1, green: 0, blue: 0, alpha: 0.5), size: CGSize(width: 20, height: 20))
        XCTAssertEqual(sprite.colorBlendFactor, 0)
        assertPixel(solidPixel(sprite), Pixel(127, 0, 0, 127))
    }

    /// A label alpha-blends whatever its `blendMode`, tinted or not; a sprite's mode applies.
    func testALabelIgnoresItsBlendMode() {
        let bgColor = UIColor(white: 0.5, alpha: 1)
        let ink = UIColor(red: 0.25, green: 0.5, blue: 1, alpha: 0.5)
        for mode in [SKBlendMode.add, .subtract, .multiply, .multiplyX2, .screen, .replace, .multiplyAlpha] {
            for tinted in [false, true] {
                let background = SKSpriteNode(color: bgColor, size: CGSize(width: 160, height: 160))
                let square = SKLabelNode(text: "\u{25A0}")
                square.fontSize = 120
                square.verticalAlignmentMode = .center
                square.fontColor = tinted ? .white : ink
                if tinted {
                    square.color = ink
                    square.colorBlendFactor = 1
                }
                square.blendMode = mode
                background.addChild(square)
                assertPixel(centerPixel(background), Pixel(95, 127, 191, 255))
            }
        }
        let background = SKSpriteNode(color: bgColor, size: CGSize(width: 160, height: 160))
        let sprite = SKSpriteNode(color: ink, size: CGSize(width: 60, height: 60))
        sprite.blendMode = .add
        background.addChild(sprite)
        assertPixel(centerPixel(background), Pixel(158, 190, 254, 255))
    }

    func testColorizeAnimatesALabel() {
        let label = label(fontColor: .white, blend: 0)
        scene.addChild(label)
        label.run(SKAction.colorize(with: .green, colorBlendFactor: 1, duration: 0))
        let ran = expectation(description: "the action ran")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { ran.fulfill() }
        wait(for: [ran], timeout: 2)
        XCTAssertEqual(label.color, .green)
        XCTAssertEqual(label.colorBlendFactor, 1)
        label.removeFromParent()
        assertPixel(solidPixel(label), Pixel(0, 255, 0, 255))
    }
}
