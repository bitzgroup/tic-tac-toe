import SpriteKit
import XCTest

/// Records Apple's `SKShapeNode` `isAntialiased` (and the antialiased outline's edge profile),
/// `blendMode`, `lineLength` and the stroke's share of `frame`, which bitzgroup/SpriteKit mirrors. Pixel tests render with `SKView.texture(from:)`
/// and read back premultiplied RGBA (0–255).
final class SKShapeNodeStyleParityTests: XCTestCase {
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

    /// How many pixels are neither fully transparent nor fully opaque — the antialiased edge.
    private func partialPixelCount(_ node: SKNode) -> Int {
        let rendered = pixels(node).pixels
        let alphas = stride(from: 3, to: rendered.count, by: 4).map { rendered[$0] }
        return alphas.filter { $0 > 0 && $0 < 255 }.count
    }

    private func centerPixel(_ node: SKNode) -> [Int] {
        let (p, width, height) = pixels(node)
        let i = ((height / 2) * width + width / 2) * 4
        return (0..<4).map { Int(p[i + $0]) }
    }

    private func assertClose(_ actual: [Int], _ expected: [Int], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertTrue(zip(actual, expected).allSatisfy { abs($0 - $1) <= 1 }, "\(actual) is not \(expected)", file: file, line: line)
    }

    func testDefaults() {
        let shape = SKShapeNode(rectOf: CGSize(width: 40, height: 40))
        XCTAssertTrue(shape.isAntialiased)
        XCTAssertEqual(shape.blendMode, .alpha)
        XCTAssertEqual(shape.lineWidth, 1)
        XCTAssertEqual(shape.glowWidth, 0)
    }

    /// Antialiasing smooths an outline's edges but never a fill's.
    func testAntialiasingSmoothsOutlinesOnly() {
        func fill(_ antialiased: Bool) -> SKShapeNode {
            let shape = SKShapeNode(circleOfRadius: 30)
            shape.fillColor = .white
            shape.lineWidth = 0
            shape.isAntialiased = antialiased
            return shape
        }
        func stroke(_ antialiased: Bool) -> SKShapeNode {
            let shape = SKShapeNode(circleOfRadius: 30)
            shape.lineWidth = 3
            shape.isAntialiased = antialiased
            return shape
        }
        XCTAssertEqual(partialPixelCount(fill(true)), 0)
        XCTAssertEqual(partialPixelCount(fill(false)), 0)
        XCTAssertGreaterThan(partialPixelCount(stroke(true)), 0)
        XCTAssertEqual(partialPixelCount(stroke(false)), 0)
    }

    /// A horizontal outline's alpha down one pixel column, top to bottom, leaving out clear pixels.
    private func column(_ alphas: [UInt8], width: Int, height: Int) -> [Int] {
        (0..<height).map { Int(alphas[($0 * width + width / 2) * 4 + 3]) }.filter { $0 > 0 }
    }

    /// `node` centered in a clear 120-point square, so `texture(from:)` doesn't crop to the node's
    /// own frame (whose antialiasing padding would put its edges between pixels).
    private func framed(_ node: SKNode) -> SKNode {
        let holder = SKSpriteNode(color: .clear, size: CGSize(width: 120, height: 120))
        holder.addChild(node)
        return holder
    }

    private func horizontalLine(halfLength: CGFloat, lineWidth: CGFloat) -> SKShapeNode {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: -halfLength, y: 0))
        path.addLine(to: CGPoint(x: halfLength, y: 0))
        let line = SKShapeNode(path: path)
        line.lineWidth = lineWidth
        return line
    }

    /// Each edge fades linearly over 1.7 screen pixels — opaque 1.12 pixels inside it, clear 0.58
    /// outside — so a pixel-aligned edge reads 162 then 12, on a 3x iPhone and a 1x Apple TV alike.
    func testAnAntialiasedEdgeFadesOverOnePointSevenPixels() {
        for lineWidth in [CGFloat(4), 10] {
            let (p, width, height) = pixels(framed(horizontalLine(halfLength: 30, lineWidth: lineWidth)))
            let profile = column(p, width: width, height: height)
            let opaque = Int(lineWidth * view.contentScaleFactor) - 2
            XCTAssertEqual(profile, [12, 162] + Array(repeating: 255, count: opaque) + [162, 12])
        }
    }

    /// The fade is sized at the node's own scale: scaling the node by 4 stretches it to about 6.8
    /// pixels a side.
    func testTheFadeScalesWithTheNode() {
        let line = horizontalLine(halfLength: 30, lineWidth: 2)
        line.setScale(4)
        let (p, width, height) = pixels(framed(line))
        let profile = column(p, width: width, height: height)
        let partial = profile.filter { $0 < 255 }.count
        XCTAssertTrue((12...14).contains(partial), "\(profile)")
    }

    /// The scene's `scaleMode` scales the fade too: a scene drawn at twice its size fades over 3.4
    /// pixels, one drawn at half its size over 0.85. (`texture(from:)` ignores `scaleMode`, so this
    /// reads the view back instead.)
    func testTheFadeScalesWithTheScene() {
        func profile(sceneSide: CGFloat) -> [Int] {
            let scaled = SKScene(size: CGSize(width: sceneSide, height: sceneSide))
            scaled.scaleMode = .aspectFit
            scaled.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            scaled.backgroundColor = .black
            scaled.addChild(horizontalLine(halfLength: sceneSide / 4, lineWidth: 4 * sceneSide / 200))
            view.presentScene(scaled)
            RunLoop.main.run(until: Date().addingTimeInterval(0.5))
            let image = UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
                _ = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
            }.cgImage!
            var p = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = CGContext(
                data: &p, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            // The red channel: the line is white on an opaque black background.
            return (0..<image.height).map { Int(p[($0 * image.width + image.width / 2) * 4]) }.filter { $0 > 0 }
        }
        let unscaled = profile(sceneSide: 200)
        XCTAssertEqual(unscaled.filter { $0 < 255 }, [12, 162, 162, 12])
        let doubled = profile(sceneSide: 100).filter { $0 < 255 }
        XCTAssertTrue((6...8).contains(doubled.count), "\(doubled)")
        let halved = profile(sceneSide: 400).filter { $0 < 255 }
        XCTAssertLessThanOrEqual(halved.count, 2, "\(halved)")
    }

    /// `blendMode` applies to fill and outline alike, the same as a sprite's.
    func testBlendModeAppliesToFillAndOutline() {
        let ink = UIColor(red: 0.25, green: 0.5, blue: 1, alpha: 0.5)
        let expected: [(SKBlendMode, [Int])] = [
            (.alpha, [95, 127, 191, 255]), (.add, [158, 190, 254, 255]), (.subtract, [112, 96, 64, 255]),
            (.multiply, [15, 31, 63, 127]), (.multiplyX2, [31, 63, 127, 127]), (.screen, [143, 159, 191, 255]),
            (.replace, [31, 63, 127, 127]), (.multiplyAlpha, [79, 95, 127, 255]),
        ]
        for (mode, pixel) in expected {
            let background = SKSpriteNode(color: UIColor(white: 0.5, alpha: 1), size: CGSize(width: 160, height: 160))
            let fill = SKShapeNode(rectOf: CGSize(width: 60, height: 60))
            fill.fillColor = ink
            fill.lineWidth = 0
            fill.blendMode = mode
            background.addChild(fill)
            assertClose(centerPixel(background), pixel)

            let background2 = SKSpriteNode(color: UIColor(white: 0.5, alpha: 1), size: CGSize(width: 160, height: 160))
            let outline = SKShapeNode(rectOf: CGSize(width: 60, height: 60))
            outline.strokeColor = ink
            outline.lineWidth = 20
            outline.blendMode = mode
            outline.position = CGPoint(x: 30, y: 0) // its left edge crosses the center
            background2.addChild(outline)
            assertClose(centerPixel(background2), pixel)
        }
    }

    /// A drawn outline widens the frame by its width, plus 0.85 points a side when antialiased.
    func testAnOutlineWidensTheFrame() {
        for lineWidth in [CGFloat(0.5), 1, 3, 20] {
            for antialiased in [true, false] {
                let shape = SKShapeNode(rectOf: CGSize(width: 40, height: 40))
                shape.lineWidth = lineWidth
                shape.isAntialiased = antialiased
                XCTAssertEqual(shape.frame.width, 40 + lineWidth + (antialiased ? 1.7 : 0), accuracy: 0.001)
            }
        }
        let line = CGMutablePath()
        line.move(to: .zero)
        line.addLine(to: CGPoint(x: 40, y: 0))
        let open = SKShapeNode(path: line)
        open.lineWidth = 2
        open.isAntialiased = false
        XCTAssertEqual(open.frame, CGRect(x: 0, y: -1, width: 40, height: 2)) // butt caps add no length

        let glowing = SKShapeNode(rectOf: CGSize(width: 40, height: 40))
        glowing.lineWidth = 2
        glowing.glowWidth = 5
        XCTAssertEqual(glowing.frame.width, 53.7, accuracy: 0.001)

        let clear = SKShapeNode(rectOf: CGSize(width: 40, height: 40))
        clear.lineWidth = 3
        clear.strokeColor = .clear
        XCTAssertEqual(clear.frame.width, 40)
    }

    /// A sharp corner's miter tip isn't part of the frame: it stops at the segments' own corners.
    func testTheFrameLeavesOutMiters() {
        let peak = CGMutablePath()
        peak.move(to: .zero)
        peak.addLine(to: CGPoint(x: 20, y: 40))
        peak.addLine(to: CGPoint(x: 40, y: 0))
        let shape = SKShapeNode(path: peak)
        shape.lineWidth = 4
        shape.isAntialiased = false
        XCTAssertEqual(shape.frame.minX, -1.789, accuracy: 0.01)
        XCTAssertEqual(shape.frame.maxY, 40.894, accuracy: 0.01)
    }

    /// Simulators report a length of 0 for every path, even rendered.
    func testLineLengthIsZeroOnSimulators() {
        let shape = SKShapeNode(rect: CGRect(x: 0, y: 0, width: 10, height: 20))
        XCTAssertEqual(shape.lineLength, 0)
        scene.addChild(shape)
        _ = view.texture(from: shape)
        XCTAssertEqual(shape.lineLength, 0)
        XCTAssertEqual(SKShapeNode(circleOfRadius: 10).lineLength, 0)
    }
}
