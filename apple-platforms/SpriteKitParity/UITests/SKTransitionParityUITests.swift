import XCTest

/// Records what Apple's `SKTransition` door effects draw and how `pausesIncomingScene`/
/// `pausesOutgoingScene` behave, which bitzgroup/SpriteKit mirrors. The host's `transition`
/// scenario goes from four colored quadrants (red bottom left, green bottom right, magenta top
/// left, yellow top right) to a blue scene with a cyan square in the middle; the tests read the
/// screen's pixels part-way through.
final class SKTransitionParityUITests: XCTestCase {
    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-scenario", "transition"] + arguments
        app.launch()
        return app
    }

    private func state(_ app: XCUIApplication) -> String {
        let label = app.staticTexts["state"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        return label.label
    }

    private func value(_ key: String, in state: String) -> String? {
        state.split(separator: " ").first { $0.hasPrefix("\(key)=") }.map { String($0.dropFirst(key.count + 1)) }
    }

    private func elapsedMs(_ app: XCUIApplication) -> Int {
        value("transitionElapsedMs", in: state(app)).flatMap(Int.init) ?? -1
    }

    private func waitForElapsed(_ app: XCUIApplication, _ ms: Int) {
        let deadline = Date().addingTimeInterval(60)
        while Date() < deadline {
            if elapsedMs(app) >= ms { return }
            usleep(50_000)
        }
        XCTFail("transition never reached \(ms) ms")
    }

    /// The screen's colors, each pixel reduced to one letter: R, G, B, M (magenta), Y, C (cyan),
    /// K (black), or ? for anything in between.
    private struct Screen {
        let width: Int
        let height: Int
        let data: [UInt8]

        init(_ image: CGImage) {
            width = image.width
            height = image.height
            var data = [UInt8](repeating: 0, count: width * height * 4)
            let context = CGContext(
                data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )!
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            self.data = data
        }

        /// The color at a point given as fractions of the screen, measured from the bottom left.
        func color(_ fx: Double, _ fy: Double) -> Character {
            let x = min(width - 1, Int(fx * Double(width)))
            let row = min(height - 1, Int((1 - fy) * Double(height)))
            let i = (row * width + x) * 4
            func level(_ v: UInt8) -> Int? { v > 170 ? 1 : (v < 80 ? 0 : nil) }
            guard let r = level(data[i]), let g = level(data[i + 1]), let b = level(data[i + 2]) else { return "?" }
            switch (r, g, b) {
            case (1, 0, 0): return "R"
            case (0, 1, 0): return "G"
            case (0, 0, 1): return "B"
            case (1, 0, 1): return "M"
            case (1, 1, 0): return "Y"
            case (0, 1, 1): return "C"
            case (0, 0, 0): return "K"
            default: return "?"
            }
        }

        /// How far from the start of a line (left end of a row, bottom of a column) the color
        /// first stops being `from`, as a fraction of the screen.
        func edge(horizontal: Bool, at fixed: Double, from: Character) -> Double {
            for step in 0..<1000 {
                let f = (Double(step) + 0.5) / 1000
                if (horizontal ? color(f, fixed) : color(fixed, f)) != from { return f }
            }
            return 1
        }
    }

    /// Apple's door timing: `3t² − 2t³`.
    private func ease(_ t: Double) -> Double { t * t * (3 - 2 * t) }

    /// Screenshots [app] at about [fraction] of a [duration]-second transition, returning the
    /// screen and the range of transition progress the screenshot was taken within.
    private func capture(_ app: XCUIApplication, at fraction: Double, of duration: Double) -> (Screen, ClosedRange<Double>) {
        waitForElapsed(app, Int(fraction * duration * 1000))
        let before = Double(elapsedMs(app)) / 1000 / duration
        let screen = Screen(XCUIScreen.main.screenshot().image.cgImage!)
        let after = Double(elapsedMs(app)) / 1000 / duration
        return (screen, before...after)
    }

    /// Asserts [observed] lies within what [model] gives over [progress], give or take [slack].
    private func assertWithin(
        _ observed: Double, _ model: (Double) -> Double, over progress: ClosedRange<Double>, slack: Double = 0.01,
        _ message: String, line: UInt = #line
    ) {
        let a = model(progress.lowerBound)
        let b = model(progress.upperBound)
        XCTAssertGreaterThanOrEqual(observed, min(a, b) - slack, message, line: line)
        XCTAssertLessThanOrEqual(observed, max(a, b) + slack, message, line: line)
    }

    private let duration = 20.0

    func testDoorsOpenSplitTheOutgoingSceneAndSlideEachHalfOutWithoutScaling() {
        let horizontal = launch(["-transition", "doorsOpenHorizontal", "-duration", "\(duration)"])
        for fraction in [0.3, 0.7] {
            let (screen, progress) = capture(horizontal, at: fraction, of: duration)
            // The left half's right edge, over the stationary incoming scene.
            let edge = screen.edge(horizontal: true, at: 0.25, from: "R")
            assertWithin(edge, { 0.5 - 0.5 * self.ease($0) }, over: progress, "left door at \(progress)")
            // The doors aren't scaled: the quadrant boundary stays at mid-height.
            XCTAssertEqual(screen.color(0.05, 0.49), "R")
            XCTAssertEqual(screen.color(0.05, 0.51), "M")
            // The incoming scene doesn't move: its cyan square stays at the middle.
            XCTAssertEqual(screen.edge(horizontal: false, at: 0.5, from: "B"), 0.375, accuracy: 0.01)
        }
        horizontal.terminate()

        let vertical = launch(["-transition", "doorsOpenVertical", "-duration", "\(duration)"])
        let (screen, progress) = capture(vertical, at: 0.5, of: duration)
        let edge = screen.edge(horizontal: false, at: 0.25, from: "R")
        assertWithin(edge, { 0.5 - 0.5 * self.ease($0) }, over: progress, "bottom door at \(progress)")
        vertical.terminate()
    }

    func testDoorsCloseSlideTheIncomingScenesHalvesInFromTheEdges() {
        let horizontal = launch(["-transition", "doorsCloseHorizontal", "-duration", "\(duration)"])
        var (screen, progress) = capture(horizontal, at: 0.5, of: duration)
        // The incoming scene's left half, from the left edge to where the outgoing scene shows.
        assertWithin(screen.edge(horizontal: true, at: 0.25, from: "B"), { 0.5 * self.ease($0) }, over: progress, "left door at \(progress)")
        horizontal.terminate()

        let vertical = launch(["-transition", "doorsCloseVertical", "-duration", "\(duration)"])
        for fraction in [0.3, 0.7] {
            (screen, progress) = capture(vertical, at: fraction, of: duration)
            let edge = screen.edge(horizontal: false, at: 0.25, from: "B")
            assertWithin(edge, { 0.5 * self.ease($0) }, over: progress, "bottom door at \(progress)")
            // The panel is moved, not squashed: the cyan square's lower half stays 0.125 tall,
            // ending at the panel's edge.
            let cyanStart = screen.edge(horizontal: false, at: 0.5, from: "B")
            if cyanStart < edge - 0.01 {
                XCTAssertEqual(edge - cyanStart, 0.125, accuracy: 0.01)
            }
        }
        vertical.terminate()
    }

    /// The incoming scene of a doorway transition comes forward from about 0.42 of its size, as
    /// `1 / (1 + distance)` with the distance eased like the doors. A fit to the recorded sizes
    /// (within 0.03 of each), not Apple's exact formula.
    func testDoorwayBringsTheIncomingSceneForwardOverBlack() {
        let app = launch(["-transition", "doorway", "-duration", "\(duration)"])
        let scale: (Double) -> Double = { 1 / (1 + (1 / 0.42 - 1) * (1 - self.ease($0))) }
        for fraction in [0.3, 0.5, 0.8] {
            let (screen, progress) = capture(app, at: fraction, of: duration)
            let bottom = screen.edge(horizontal: false, at: 0.5, from: "K")
            assertWithin(1 - 2 * bottom, scale, over: progress, slack: 0.03, "incoming scale at \(progress)")
        }
        app.terminate()
    }

    private func counts(_ state: String) -> (outgoing: Int, incoming: Int) {
        (Int(value("updates", in: state) ?? "") ?? -1, Int(value("incomingUpdates", in: state) ?? "") ?? -1)
    }

    func testByDefaultBothScenesArePausedUntilTheTransitionEnds() {
        // Reading the state takes a while, so the transition is long enough to check it while running.
        let app = launch(["-transition", "crossFade", "-duration", "12"])
        waitForElapsed(app, 500)
        let early = state(app)
        sleep(1)
        let later = state(app)
        XCTAssertLessThan(Int(value("transitionElapsedMs", in: later) ?? "") ?? .max, 12000)
        XCTAssertEqual(value("scenePaused", in: later), "true")
        XCTAssertEqual(value("incomingPaused", in: later), "true")
        XCTAssertEqual(counts(later).outgoing, counts(early).outgoing, "the outgoing scene gets no update(_:)")
        // Apple gives the incoming scene one update before pausing it.
        XCTAssertLessThanOrEqual(counts(later).incoming, 1)

        waitForElapsed(app, 13000)
        let after = state(app)
        XCTAssertEqual(value("presented", in: after), "incoming")
        XCTAssertEqual(value("scenePaused", in: after), "false")
        XCTAssertEqual(value("incomingPaused", in: after), "false")
        sleep(1)
        XCTAssertGreaterThan(counts(state(app)).incoming, counts(after).incoming)
        XCTAssertEqual(counts(state(app)).outgoing, counts(after).outgoing, "a replaced scene stops running")
        app.terminate()
    }

    func testScenesTheTransitionDoesntPauseKeepRunning() {
        let app = launch(["-transition", "crossFade", "-duration", "12", "-pausesIncoming", "false", "-pausesOutgoing", "false"])
        waitForElapsed(app, 500)
        let early = state(app)
        sleep(1)
        let later = state(app)
        XCTAssertLessThan(Int(value("transitionElapsedMs", in: later) ?? "") ?? .max, 12000)
        XCTAssertEqual(value("scenePaused", in: later), "false")
        XCTAssertEqual(value("incomingPaused", in: later), "false")
        XCTAssertGreaterThan(counts(later).outgoing, counts(early).outgoing)
        XCTAssertGreaterThan(counts(later).incoming, counts(early).incoming)
        app.terminate()
    }
}
