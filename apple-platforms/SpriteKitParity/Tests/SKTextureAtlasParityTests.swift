import SpriteKit
import XCTest

/// Records Apple's `SKTextureAtlas` (`init(named:)`, `init(dictionary:)`, preloading) and
/// `SKTexture` preloading, which bitzgroup/SpriteKit (PARITY_GAP_PLAN.md T2) mirrors by packing an
/// `assets/<name>.atlas/` folder at runtime. `ParityAtlas.atlas` is bundled with the host app:
/// `red.png` (4×2), `blue.png` (3×5) and `framed.png` (8×8, a 4×4 green square in a transparent
/// border).
final class SKTextureAtlasParityTests: XCTestCase {
    private func image(_ size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    /// Names keep their extensions; a texture is found with or without one; sizes are the images'
    /// pixel sizes, a transparent border included.
    func testANamedAtlasListsItsImagesWithTheirExtensions() {
        let atlas = SKTextureAtlas(named: "ParityAtlas")
        XCTAssertEqual(atlas.textureNames.sorted(), ["blue.png", "framed.png", "red.png"])
        XCTAssertEqual(atlas.textureNamed("red").size(), CGSize(width: 4, height: 2))
        XCTAssertEqual(atlas.textureNamed("red.png").size(), CGSize(width: 4, height: 2))
        XCTAssertEqual(atlas.textureNamed("blue").size(), CGSize(width: 3, height: 5))
        XCTAssertEqual(atlas.textureNamed("framed").size(), CGSize(width: 8, height: 8))
        XCTAssertEqual(atlas.textureNamed("red").filteringMode, .linear)
        XCTAssertEqual(SKTextureAtlas(named: "ParityAtlas.atlas").textureNames.count, 3)
    }

    /// An unknown name gives the 128×128 missing-image placeholder, not nil; a missing atlas is empty.
    func testMissingNamesAndAtlases() {
        XCTAssertEqual(SKTextureAtlas(named: "ParityAtlas").textureNamed("nope").size(), CGSize(width: 128, height: 128))
        let missing = SKTextureAtlas(named: "NoSuchAtlas")
        XCTAssertEqual(missing.textureNames, [])
        XCTAssertEqual(missing.textureNamed("red").size(), CGSize(width: 128, height: 128))
    }

    /// Keys are kept as given, and found with or without an extension either way. Values may be
    /// images, file paths or file URLs; sizes are pixel sizes.
    func testADictionaryAtlas() {
        let atlas = SKTextureAtlas(dictionary: ["one": image(CGSize(width: 6, height: 4)), "two.png": image(CGSize(width: 2, height: 3))])
        XCTAssertEqual(atlas.textureNames.sorted(), ["one", "two.png"])
        XCTAssertEqual(atlas.textureNamed("one").size(), CGSize(width: 6, height: 4))
        XCTAssertEqual(atlas.textureNamed("one.png").size(), CGSize(width: 6, height: 4))
        XCTAssertEqual(atlas.textureNamed("two").size(), CGSize(width: 2, height: 3))
        XCTAssertEqual(atlas.textureNamed("three").size(), CGSize(width: 128, height: 128))

        let path = Bundle.main.path(forResource: "ParityProbe", ofType: "png")!
        let files = SKTextureAtlas(dictionary: ["path": path, "url": URL(fileURLWithPath: path)])
        XCTAssertEqual(files.textureNamed("path").size(), CGSize(width: 4, height: 2))
        XCTAssertEqual(files.textureNamed("url").size(), CGSize(width: 4, height: 2))
    }

    /// Every preload calls back once, off the main thread; preloading by name includes a missing
    /// atlas as an empty one, without an error.
    func testPreloadingCallsBackOffTheMainThread() {
        let atlas = SKTextureAtlas(named: "ParityAtlas")
        var mainThread: [Bool] = []
        let lock = NSLock()
        let calls = expectation(description: "preloads")
        calls.expectedFulfillmentCount = 4
        // The callbacks can run concurrently on different background threads.
        let record = {
            lock.lock()
            mainThread.append(Thread.isMainThread)
            lock.unlock()
            calls.fulfill()
        }
        atlas.preload(completionHandler: record)
        SKTextureAtlas.preloadTextureAtlases([atlas], withCompletionHandler: record)
        SKTexture.preload([atlas.textureNamed("red")], withCompletionHandler: record)
        atlas.textureNamed("blue").preload(completionHandler: record)
        wait(for: [calls], timeout: 5)
        XCTAssertEqual(mainThread, [false, false, false, false])

        let named = expectation(description: "named")
        SKTextureAtlas.preloadTextureAtlasesNamed(["ParityAtlas", "NoSuchAtlas"]) { error, atlases in
            XCTAssertNil(error)
            XCTAssertEqual(atlases.map { $0.textureNames.count }, [3, 0])
            XCTAssertFalse(Thread.isMainThread)
            named.fulfill()
        }
        wait(for: [named], timeout: 5)
    }

    /// Stretched far past its pixel size, an atlas texture keeps hard, clean edges like a
    /// standalone texture: nothing bleeds in from its neighbors in the atlas.
    func testAStretchedAtlasTextureDoesNotBleed() {
        let view = SKView(frame: CGRect(x: 0, y: 0, width: 200, height: 200))
        let window = UIWindow(frame: view.frame)
        window.addSubview(view)
        window.isHidden = false
        defer { window.isHidden = true }
        let scene = SKScene(size: view.bounds.size)
        view.presentScene(scene)
        for name in ["red", "blue"] {
            let holder = SKSpriteNode(color: .black, size: CGSize(width: 100, height: 100))
            let sprite = SKSpriteNode(texture: SKTextureAtlas(named: "ParityAtlas").textureNamed(name))
            sprite.size = CGSize(width: 80, height: 80)
            holder.addChild(sprite)
            let image = view.texture(from: holder)!.cgImage()
            var p = [UInt8](repeating: 0, count: image.width * image.height * 4)
            let context = CGContext(
                data: &p, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let colors = Set(stride(from: 0, to: p.count, by: 4).map { Array(p[$0..<$0 + 3]) })
            XCTAssertEqual(colors, [[0, 0, 0], name == "red" ? [255, 0, 0] : [0, 0, 255]], name)
        }
    }
}
