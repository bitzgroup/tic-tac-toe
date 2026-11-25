import SpriteKit
import XCTest

/// Records what Apple's `SKEmitterNode` draws for its keyframe sequences, `targetNode`,
/// `particleRenderOrder`, `particleAction` and color settings, and its defaults —
/// bitzgroup/SpriteKit (PARITY_GAP_PLAN.md E1) mirrors them. Each test emits one still particle
/// (two for the draw-order tests), fast-forwards it with `advanceSimulationTime(_:)`, renders the
/// scene with `SKView.texture(from:)` and reads the lit pixels back.
final class SKEmitterParityTests: XCTestCase {
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
        scene.backgroundColor = .black
        view.presentScene(scene)
    }

    override func tearDown() {
        window.isHidden = true
        window = nil
        view = nil
        scene = nil
        super.tearDown()
    }

    private func runFrames(_ seconds: Double) {
        let done = expectation(description: "frames")
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { done.fulfill() }
        wait(for: [done], timeout: seconds + 2)
    }

    // MARK: - Reading pixels

    private struct Pixels {
        let data: [UInt8]
        let width: Int
        let height: Int
        let scale: Double

        /// The premultiplied color at a point, in points from the bottom left.
        func rgb(_ x: Double, _ y: Double) -> [Double] {
            let col = Int((x + 0.5) * scale), row = height - 1 - Int((y + 0.5) * scale)
            let i = (row * width + col) * 4
            return (0..<3).map { Double(data[i + $0]) / 255 }
        }
    }

    private func render() -> Pixels {
        let texture = view.texture(from: scene)!
        let image = texture.cgImage()
        let width = image.width, height = image.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let context = CGContext(
            data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return Pixels(data: data, width: width, height: height, scale: Double(width) / Double(texture.size().width))
    }

    /// The lit pixels' bounds (in whole points, y up) and average premultiplied color.
    private struct Lit {
        var x: ClosedRange<Int>?
        var y: ClosedRange<Int>?
        var rgb: [Double] = [0, 0, 0]
    }

    private func lit() -> Lit {
        let pixels = render()
        var minX = Int.max, maxX = Int.min, minY = Int.max, maxY = Int.min, count = 0
        var sum = [0.0, 0.0, 0.0]
        for row in 0..<pixels.height {
            for col in 0..<pixels.width {
                let i = (row * pixels.width + col) * 4
                let rgb = (0..<3).map { Double(pixels.data[i + $0]) / 255 }
                if rgb.max()! < 0.02 { continue }
                let x = Int(Double(col) / pixels.scale), y = Int(Double(pixels.height - 1 - row) / pixels.scale)
                minX = min(minX, x); maxX = max(maxX, x); minY = min(minY, y); maxY = max(maxY, y)
                count += 1
                for c in 0..<3 { sum[c] += rgb[c] }
            }
        }
        guard count > 0 else { return Lit() }
        return Lit(x: minX...maxX, y: minY...maxY, rgb: sum.map { $0 / Double(count) })
    }

    private func assertLit(
        _ lit: Lit,
        x: ClosedRange<Int>,
        y: ClosedRange<Int>,
        rgb: [Double] = [1, 1, 1],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertEqual(lit.x, x, "x", file: file, line: line)
        XCTAssertEqual(lit.y, y, "y", file: file, line: line)
        assertRGB(lit.rgb, rgb, file: file, line: line)
    }

    private func assertRGB(
        _ actual: [Double],
        _ expected: [Double],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for (a, e) in zip(actual, expected) {
            XCTAssertEqual(a, e, accuracy: 0.01, "\(actual)", file: file, line: line)
        }
    }

    // MARK: - Emitters

    private func whiteTexture() -> SKTexture {
        let texture = SKTexture(data: Data(repeating: 255, count: 4 * 4 * 4), size: CGSize(width: 4, height: 4))
        texture.filteringMode = .nearest
        return texture
    }

    /// An emitter at the scene's center that emits one still, white, 10-point particle living
    /// [lifetime] seconds, after its first second.
    private func emitter(lifetime: CGFloat = 2) -> SKEmitterNode {
        let emitter = SKEmitterNode()
        emitter.particleTexture = whiteTexture()
        emitter.particleSize = CGSize(width: 10, height: 10)
        emitter.particleBirthRate = 1000
        emitter.numParticlesToEmit = 1
        emitter.particleLifetime = lifetime
        emitter.particleSpeed = 0
        emitter.emissionAngle = 0
        emitter.particleColor = .white
        emitter.position = CGPoint(x: 50, y: 50)
        return emitter
    }

    /// Adds [emitter] to the scene, fast-forwards it by [seconds] and returns what's drawn.
    private func litAfter(_ seconds: TimeInterval, _ emitter: SKEmitterNode) -> Lit {
        scene.addChild(emitter)
        emitter.advanceSimulationTime(seconds)
        defer { emitter.removeFromParent() }
        return lit()
    }

    private func sequence(_ values: [Double], _ times: [Double] = [0, 1]) -> SKKeyframeSequence {
        SKKeyframeSequence(keyframeValues: values, times: times.map { NSNumber(value: $0) })
    }

    // MARK: - Defaults

    func testDefaults() {
        let emitter = SKEmitterNode()
        XCTAssertEqual(emitter.emissionAngle, .pi / 2, accuracy: 0.000001)
        XCTAssertEqual(emitter.particleLifetime, 0)
        XCTAssertEqual(emitter.particleAlpha, 1)
        XCTAssertEqual(emitter.particleScale, 1)
        XCTAssertEqual(emitter.particleColorBlendFactor, 0)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        emitter.particleColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        XCTAssertEqual([red, green, blue, alpha], [1, 1, 1, 0])
        XCTAssertEqual(emitter.particleRenderOrder, .oldestLast)
        XCTAssertNil(emitter.targetNode)
        XCTAssertNil(emitter.particleAction)
        XCTAssertNil(emitter.particleColorSequence)
        XCTAssertNil(emitter.particleColorBlendFactorSequence)
        XCTAssertNil(emitter.particleAlphaSequence)
        XCTAssertNil(emitter.particleScaleSequence)
    }

    func testAParticleWithNoLifetimeIsNeverDrawn() {
        XCTAssertNil(litAfter(0.5, emitter(lifetime: 0)).x)
    }

    // MARK: - Keyframe sequences

    func testSequencesAreSampledByTheFractionOfTheParticleLifetime() {
        // Born at 0, living 2 seconds: ages 0.5, 1 and 1.5 are a quarter, half and three quarters.
        for (age, brightness) in [(0.5, 0.75), (1.0, 0.5), (1.5, 0.25)] {
            let emitter = emitter()
            emitter.particleAlphaSequence = sequence([1, 0])
            assertLit(litAfter(age, emitter), x: 45...54, y: 45...54, rgb: Array(repeating: brightness, count: 3))
        }
        // Keyframe times past 1 are never reached.
        let emitter = emitter()
        emitter.particleAlphaSequence = sequence([1, 0], [0, 2])
        assertLit(litAfter(0.5, emitter), x: 45...54, y: 45...54, rgb: [0.875, 0.875, 0.875])
    }

    func testAnAlphaSequenceReplacesTheAlphaAndItsSpeed() {
        let plain = emitter()
        plain.particleAlpha = 0.5
        plain.particleAlphaSpeed = -0.2
        assertLit(litAfter(0.5, plain), x: 45...54, y: 45...54, rgb: [0.4, 0.4, 0.4])

        let sequenced = emitter()
        sequenced.particleAlpha = 0.5
        sequenced.particleAlphaSpeed = -0.2
        sequenced.particleAlphaSequence = sequence([1, 0])
        assertLit(litAfter(0.5, sequenced), x: 45...54, y: 45...54, rgb: [0.75, 0.75, 0.75])
    }

    func testAScaleSequenceReplacesTheScaleAndItsSpeed() {
        for (age, bounds) in [(0.5, 42...57), (1.0, 40...59), (1.5, 37...62)] {
            let emitter = emitter()
            emitter.particleScale = 3
            emitter.particleScaleSpeed = 1
            emitter.particleScaleSequence = sequence([1, 3])
            assertLit(litAfter(age, emitter), x: bounds, y: bounds)
        }
        // A sequence's own interpolation mode applies.
        let stepped = emitter()
        let steps = sequence([1, 3])
        steps.interpolationMode = .step
        stepped.particleScaleSequence = steps
        assertLit(litAfter(0.9, stepped), x: 45...54, y: 45...54)
    }

    func testAColorBlendFactorSequenceReplacesTheBlendFactor() {
        let emitter = emitter()
        emitter.particleColor = .red
        emitter.particleColorBlendFactorSequence = sequence([0, 1])
        assertLit(litAfter(1.0, emitter), x: 45...54, y: 45...54, rgb: [1, 0.5, 0.5])
    }

    func testTheBlendFactorMixesColorAndAlphaTowardTheParticleColor() {
        let halfRed = SKColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        // White at alpha 1 mixed halfway to red at alpha 0.5: (1, 0.5, 0.5) at alpha 0.75.
        let mixed = emitter()
        mixed.particleColor = halfRed
        mixed.particleColorBlendFactor = 0.5
        assertLit(litAfter(0.5, mixed), x: 45...54, y: 45...54, rgb: [0.75, 0.375, 0.375])

        let unblended = emitter()
        unblended.particleColor = halfRed
        assertLit(litAfter(0.5, unblended), x: 45...54, y: 45...54)

        // The default color is transparent white, so blending fully toward it hides the particle.
        let transparent = emitter()
        transparent.particleColor = SKEmitterNode().particleColor
        transparent.particleColorBlendFactor = 1
        XCTAssertNil(litAfter(0.5, transparent).x)
    }

    func testAColorSequenceReplacesOnlyTheColor() {
        let halfRed = SKColor(red: 1, green: 0, blue: 0, alpha: 0.5)
        let unblended = emitter()
        unblended.particleColorSequence = SKKeyframeSequence(keyframeValues: [halfRed], times: [0])
        assertLit(litAfter(0.5, unblended), x: 45...54, y: 45...54)

        let mixed = emitter()
        mixed.particleColorBlendFactor = 0.5
        mixed.particleColorSequence = SKKeyframeSequence(keyframeValues: [halfRed], times: [0])
        assertLit(litAfter(0.5, mixed), x: 45...54, y: 45...54, rgb: [0.75, 0.375, 0.375])
    }

    // MARK: - targetNode

    func testWithoutATargetParticlesMoveWithTheEmitter() {
        let emitter = emitter()
        scene.addChild(emitter)
        emitter.advanceSimulationTime(0.1)
        emitter.position = CGPoint(x: 20, y: 50)
        assertLit(lit(), x: 15...24, y: 45...54)
    }

    func testATargetKeepsParticlesWhereTheyWereBorn() {
        let emitter = emitter()
        emitter.targetNode = scene
        scene.addChild(emitter)
        emitter.advanceSimulationTime(0.1)
        emitter.position = CGPoint(x: 20, y: 50)
        assertLit(lit(), x: 45...54, y: 45...54)
        runFrames(0.2)
        assertLit(lit(), x: 45...54, y: 45...54)
    }

    func testParticlesMoveWithTheirTargetAndTakeItsAlpha() {
        let target = SKNode()
        target.position = CGPoint(x: 10, y: 0)
        scene.addChild(target)
        let emitter = emitter()
        emitter.targetNode = target
        scene.addChild(emitter)
        emitter.advanceSimulationTime(0.1)
        assertLit(lit(), x: 45...54, y: 45...54)

        target.position = CGPoint(x: -20, y: 0)
        assertLit(lit(), x: 15...24, y: 45...54)
        target.alpha = 0.5
        assertLit(lit(), x: 15...24, y: 45...54, rgb: [0.5, 0.5, 0.5])

        // The emitter's own alpha and visibility no longer apply; removing it removes its particles.
        target.alpha = 1
        emitter.alpha = 0.5
        assertLit(lit(), x: 15...24, y: 45...54)
        emitter.isHidden = true
        assertLit(lit(), x: 15...24, y: 45...54)
        emitter.removeFromParent()
        XCTAssertNil(lit().x)
    }

    /// An emitter rotated a quarter turn and scaled 2×, emitting one 4-point particle.
    private func turnedEmitter() -> SKEmitterNode {
        let emitter = emitter()
        emitter.zRotation = .pi / 2
        emitter.setScale(2)
        emitter.particleSize = CGSize(width: 4, height: 4)
        return emitter
    }

    func testWithoutATargetTheEmitterTransformsMotionAndSize() {
        let moving = turnedEmitter()
        moving.particleSpeed = 10
        // Along the emitter's +x — the scene's +y — at twice the speed, and twice the size.
        assertLit(litAfter(1.0, moving), x: 46...53, y: 66...73)

        let accelerating = turnedEmitter()
        accelerating.setScale(1)
        accelerating.xAcceleration = 20
        assertLit(litAfter(1.0, accelerating), x: 48...51, y: 58...61)
    }

    func testWithATargetMotionAndSizeAreInTheTargetsCoordinates() {
        let moving = turnedEmitter()
        moving.targetNode = scene
        moving.particleSpeed = 10
        // The emission angle, speed and size ignore the emitter's rotation and scale.
        assertLit(litAfter(1.0, moving), x: 58...61, y: 48...51)

        let accelerating = turnedEmitter()
        accelerating.targetNode = scene
        accelerating.setScale(1)
        accelerating.xAcceleration = 20
        assertLit(litAfter(1.0, accelerating), x: 58...61, y: 48...51)
    }

    // MARK: - Draw order

    /// Two overlapping particles: an older one (green) born at 1 s and 6 points right of the
    /// emitter by 2.5 s, and a younger one (red) born at 2 s and 2 points right.
    private func twoParticles(_ configure: (SKEmitterNode) -> Void) -> Pixels {
        let emitter = emitter(lifetime: 10)
        emitter.numParticlesToEmit = 2
        emitter.particleBirthRate = 1
        emitter.particleSpeed = 4
        emitter.particleColorBlendFactor = 1
        let colors = SKKeyframeSequence(keyframeValues: [SKColor.red, SKColor.green], times: [0, 0.1])
        colors.interpolationMode = .step
        emitter.particleColorSequence = colors
        configure(emitter)
        scene.addChild(emitter)
        emitter.advanceSimulationTime(2.5)
        defer { emitter.removeFromParent() }
        return render()
    }

    func testTheNewestParticleIsDrawnOnTopInEveryRenderOrder() {
        for order in [SKParticleRenderOrder.oldestLast, .oldestFirst, .dontCare] {
            let pixels = twoParticles { $0.particleRenderOrder = order }
            assertRGB(pixels.rgb(59, 50), [0, 1, 0])
            assertRGB(pixels.rgb(52, 50), [1, 0, 0])
        }
    }

    func testTheZPositionSpeedDoesNotReorderParticles() {
        for speed in [1.0, -1.0] {
            assertRGB(twoParticles { $0.particleZPositionSpeed = speed }.rgb(52, 50), [1, 0, 0])
        }
    }

    func testTheZPositionOrdersParticlesAgainstOtherNodesButItsSpeedDoesNot() {
        for (z, speed, onTop) in [(0.0, 0.0, false), (1.0, 0.0, true), (0.0, 2.0, false), (1.0, -2.0, true)] {
            let sprite = SKSpriteNode(color: .blue, size: CGSize(width: 40, height: 40))
            sprite.position = CGPoint(x: 50, y: 50)
            sprite.zPosition = 0.5
            scene.addChild(sprite)
            let emitter = emitter()
            emitter.particleZPosition = z
            emitter.particleZPositionSpeed = speed
            scene.addChild(emitter)
            // By 0.5 s, a speed of ±2 would have moved the particle past the sprite.
            emitter.advanceSimulationTime(0.5)
            assertRGB(render().rgb(50, 50), onTop ? [1, 1, 1] : [0, 0, 1])
            emitter.removeFromParent()
            sprite.removeFromParent()
        }
    }

    // MARK: - particleAction

    /// On iOS/tvOS simulators, a particle action changes nothing that's drawn — not with
    /// `advanceSimulationTime(_:)`, not over real frames.
    func testAParticleActionChangesNothingDrawn() {
        let actions: [SKAction] = [
            .moveBy(x: 20, y: 0, duration: 0.3),
            .scale(to: 2, duration: 0.3),
            .fadeAlpha(to: 0.5, duration: 0.3),
            .colorize(with: .blue, colorBlendFactor: 1, duration: 0.3),
        ]
        for action in actions {
            let advanced = emitter()
            advanced.particleAction = action
            assertLit(litAfter(1.0, advanced), x: 45...54, y: 45...54)

            let running = emitter(lifetime: 5)
            running.particleAction = action
            scene.addChild(running)
            runFrames(0.8)
            assertLit(lit(), x: 45...54, y: 45...54)
            running.removeFromParent()
        }
    }
}
