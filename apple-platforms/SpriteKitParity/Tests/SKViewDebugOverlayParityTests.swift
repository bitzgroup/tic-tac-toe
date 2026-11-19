import SpriteKit
import XCTest

/// Records Apple's `SKView` debug overlays (`showsFPS`, `showsNodeCount`, `showsDrawCount`,
/// `showsQuadCount`, `showsPhysics`, `showsFields`), which bitzgroup/SpriteKit (PARITY_GAP_PLAN.md
/// V4) mirrors. Each test reads the whole view back with `drawHierarchy`, which includes the
/// overlays, as straight RGBA (0–255) over an opaque scene.
///
/// What the screenshots also show, beyond what is asserted here: the statistics are one line,
/// `nodes:7 draws:3 quads:334  58.9 fps` — the enabled counters in that order, one space apart, the
/// frame rate (one decimal) after two spaces — in white 10-point Menlo, right-aligned. `showsFields`
/// is drawn broken on iOS/tvOS simulators (a few lines at the scene's origin, wherever the field
/// is), so it isn't recorded.
final class SKViewDebugOverlayParityTests: XCTestCase {
    private struct Capture {
        let pixels: [UInt8]
        let width: Int
        let height: Int
        let scale: Int

        func pixel(_ x: Int, _ y: Int) -> [Int] {
            let i = (y * width + x) * 4
            return (0..<4).map { Int(pixels[i + $0]) }
        }
    }

    private static let viewSize = CGSize(width: 320, height: 240)

    /// Presents a fresh scene in a fresh 320×240-point view, lets it run, and reads the view back.
    private func capture(background: UIColor = .darkGray, _ configure: (SKView, SKScene) -> Void) -> Capture {
        let view = SKView(frame: CGRect(origin: .zero, size: Self.viewSize))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        defer { window.isHidden = true }
        let scene = SKScene(size: Self.viewSize)
        scene.backgroundColor = background
        scene.physicsWorld.gravity = .zero
        configure(view, scene)
        view.presentScene(scene)
        let ran = expectation(description: "frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { ran.fulfill() }
        wait(for: [ran], timeout: 3)
        let image = UIGraphicsImageRenderer(bounds: view.bounds).image { _ in
            _ = view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
        }.cgImage!
        var p = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let context = CGContext(
            data: &p, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        return Capture(pixels: p, width: image.width, height: image.height, scale: image.width / Int(Self.viewSize.width))
    }

    /// The bounding box, in pixels (top-left origin), of every pixel that differs between two captures.
    private func differenceBox(_ a: Capture, _ b: Capture) -> CGRect? {
        var minX = Int.max, minY = Int.max, maxX = -1, maxY = -1
        for y in 0..<a.height {
            for x in 0..<a.width where a.pixel(x, y) != b.pixel(x, y) {
                minX = min(minX, x); minY = min(minY, y); maxX = max(maxX, x); maxY = max(maxY, y)
            }
        }
        guard maxX >= 0 else { return nil }
        return CGRect(x: minX, y: minY, width: maxX - minX + 1, height: maxY - minY + 1)
    }

    private func sprite(at position: CGPoint, hidden: Bool = false) -> SKSpriteNode {
        let node = SKSpriteNode(color: .red, size: CGSize(width: 20, height: 20))
        node.position = position
        node.isHidden = hidden
        return node
    }

    func testEveryOverlayIsOffByDefault() {
        let view = SKView(frame: CGRect(origin: .zero, size: Self.viewSize))
        XCTAssertFalse(view.showsFPS)
        XCTAssertFalse(view.showsNodeCount)
        XCTAssertFalse(view.showsDrawCount)
        XCTAssertFalse(view.showsQuadCount)
        XCTAssertFalse(view.showsPhysics)
        XCTAssertFalse(view.showsFields)
    }

    /// The statistics sit in the bottom-right corner, 5 points in from the right edge and 2–4
    /// points above the bottom (the box hugs the text's ink, so `fps`'s descender reaches lower than
    /// `nodes:1`), over a box of black at 30% opacity: a white scene shows through at 178.
    func testStatisticsSitBottomRightOverATranslucentBlackBox() throws {
        let plain = capture(background: .white) { _, _ in }
        let shown = capture(background: .white) { view, _ in view.showsNodeCount = true }
        let box = try XCTUnwrap(differenceBox(plain, shown))
        let s = CGFloat(shown.scale)
        XCTAssertEqual(CGFloat(shown.width) - box.maxX, 5 * s)
        XCTAssertTrue((2 * s...4 * s).contains(CGFloat(shown.height) - box.maxY), "\(box)")
        // "nodes:1": 7 Menlo characters, 6 points apart, plus up to 2 points of padding.
        XCTAssertEqual(box.width, (7 * 6 + 1) * s, accuracy: s)
        XCTAssertLessThan(box.height, 13 * s)
        // The box's own color, just inside its top-left corner.
        let inside = shown.pixel(Int(box.minX) + 1, Int(box.minY) + 1)
        XCTAssertTrue(inside == [178, 178, 178, 255] || inside == [179, 179, 179, 255], "\(inside)")
    }

    /// Every counter that is on joins the same line, which grows leftward:
    /// `nodes:2 draws:1 quads:1  58.0 fps`.
    func testCountersShareOneLine() throws {
        func scene(_ shows: Bool) -> Capture {
            capture { view, scene in
                view.showsFPS = shows
                view.showsNodeCount = shows
                view.showsDrawCount = shows
                view.showsQuadCount = shows
                scene.addChild(self.sprite(at: CGPoint(x: 100, y: 150)))
            }
        }
        let plain = scene(false)
        let all = scene(true)
        let box = try XCTUnwrap(differenceBox(plain, all))
        let s = CGFloat(all.scale)
        XCTAssertLessThan(box.height, 15 * s)
        // 32 or 33 characters, as the frame rate reads "1.0" to "60.0".
        XCTAssertTrue(((32 * 6) * s...(33 * 6 + 2) * s).contains(box.width), "\(box)")
    }

    /// `showsNodeCount` counts every node in the scene's tree — hidden ones and plain `SKNode`s too:
    /// three visible sprites, a hidden one and an empty node read exactly like five visible sprites,
    /// and unlike four. (The screenshots show the scene itself counts as well: an empty scene reads
    /// `nodes:1`.)
    func testNodeCountIncludesHiddenAndEmptyNodes() {
        func corner(_ build: @escaping (SKScene) -> Void) -> [[Int]] {
            let c = capture { view, scene in
                view.showsNodeCount = true
                build(scene)
            }
            let s = c.scale
            return (c.height - 20 * s..<c.height).flatMap { y in (c.width - 80 * s..<c.width).map { c.pixel($0, y) } }
        }
        let five = corner { scene in
            for i in 0..<5 { scene.addChild(self.sprite(at: CGPoint(x: 30 + 40 * i, y: 150))) }
        }
        let mixed = corner { scene in
            for i in 0..<3 { scene.addChild(self.sprite(at: CGPoint(x: 30 + 40 * i, y: 150))) }
            scene.addChild(self.sprite(at: CGPoint(x: 150, y: 150), hidden: true))
            scene.addChild(SKNode())
        }
        let four = corner { scene in
            for i in 0..<4 { scene.addChild(self.sprite(at: CGPoint(x: 30 + 40 * i, y: 150))) }
        }
        XCTAssertTrue(five == mixed)
        XCTAssertFalse(five == four)
    }

    /// `showsPhysics` outlines every physics body with a 1-pixel line (not 1 point: also on a 3×
    /// screen) of opaque (102, 204, 204) — (0.4, 0.8, 0.8), drawn above the scene's content — here along the edges
    /// of a 40-point square body on a blue sprite of the same size.
    func testPhysicsOutlinesAreOnePixelOpaqueLinesAboveTheContent() throws {
        func scene(_ shows: Bool) -> Capture {
            capture { view, scene in
                view.showsPhysics = shows
                let body = SKSpriteNode(color: .blue, size: CGSize(width: 40, height: 40))
                body.position = CGPoint(x: 160, y: 120)
                body.physicsBody = SKPhysicsBody(rectangleOf: body.size)
                scene.addChild(body)
            }
        }
        let plain = scene(false)
        let shown = scene(true)
        let s = shown.scale
        let y = shown.height / 2 + 5 * s
        let changed = (0..<shown.width).filter { shown.pixel($0, y) != plain.pixel($0, y) }
        XCTAssertEqual(changed.count, 2, "\(changed)")
        for x in changed { XCTAssertEqual(shown.pixel(x, y), [102, 204, 204, 255]) }
        // One pixel each, on the square's left and right edges (at least one inside the sprite).
        let left = try XCTUnwrap(changed.first)
        let right = try XCTUnwrap(changed.last)
        XCTAssertEqual(Double(right - left), Double(40 * s), accuracy: 1.5)
        XCTAssertTrue([left, right].contains { plain.pixel($0, y) == [0, 0, 255, 255] })
    }
}
