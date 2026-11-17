#if os(iOS)
import XCTest

/// Records Apple's `UITouch.tapCount`, `timestamp` and `force` as a scene receives them — what
/// bitzgroup/SpriteKit's `SKTouch` (PARITY_GAP_PLAN.md I5) mirrors. The host's `touches` scenario
/// logs each delivered touch as `<phase initial><tapCount>`: `b1` is a `touchesBegan` with
/// `tapCount` 1, `m`/`e`/`c` are moved/ended/cancelled.
final class SKTouchTapCountParityUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        super.setUp()
        app = XCUIApplication()
        app.launchArguments = ["-scenario", "touches"]
        app.launch()
        sleep(1)
    }

    override func tearDown() {
        app.terminate()
        super.tearDown()
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    private var center: XCUICoordinate { point(0.5, 0.6) }

    private func value(_ key: String) -> String {
        sleep(1)
        let label = app.staticTexts["state"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        return label.label.split(separator: " ").first { $0.hasPrefix("\(key)=") }.map { String($0.dropFirst(key.count + 1)) } ?? ""
    }

    private var touches: [String] { value("touches").split(separator: ",").map(String.init) }

    func testASingleTapHasTapCountOne() {
        center.tap()
        XCTAssertEqual(touches, ["b1", "e1"])
    }

    func testQuickTapsInOnePlaceCountUp() {
        center.doubleTap()
        XCTAssertEqual(touches, ["b1", "e1", "b2", "e2"])
    }

    func testThreeQuickTapsCountToThree() {
        app.windows.firstMatch.tap(withNumberOfTaps: 3, numberOfTouches: 1)
        XCTAssertEqual(touches, ["b1", "e1", "b2", "e2", "b3", "e3"])
    }

    func testAQuickTapCloseByContinuesTheCount() {
        center.tap()
        point(0.51, 0.61).tap()
        XCTAssertEqual(touches, ["b1", "e1", "b2", "e2"])
    }

    func testAPauseRestartsTheCount() {
        center.tap()
        sleep(1)
        center.tap()
        XCTAssertEqual(touches, ["b1", "e1", "b1", "e1"])
    }

    func testAQuickTapFarAwayRestartsTheCount() {
        center.tap()
        point(0.2, 0.9).tap()
        XCTAssertEqual(touches, ["b1", "e1", "b1", "e1"])
    }

    /// A touch held too long stops being a tap: it ends with `tapCount` 0.
    func testALongPressEndsWithTapCountZero() {
        center.press(forDuration: 1.5)
        XCTAssertEqual(touches, ["b1", "e0"])
    }

    /// A drag keeps its count while it moves, then ends with 0.
    func testADragMovesWithItsCountAndEndsWithZero() {
        center.press(forDuration: 0.1, thenDragTo: point(0.5, 0.9))
        let log = touches
        XCTAssertEqual(log.first, "b1")
        XCTAssertEqual(log.last, "e0")
        XCTAssertGreaterThan(log.count, 2)
        XCTAssertTrue(log.dropFirst().dropLast().allSatisfy { $0 == "m1" }, "\(log)")
    }

    /// Each finger of a multi-finger tap keeps its own count.
    func testEachFingerOfATwoFingerTapCountsOnItsOwn() {
        app.windows.firstMatch.tap(withNumberOfTaps: 2, numberOfTouches: 2)
        XCTAssertEqual(touches, ["b1", "b1", "e1", "e1", "b2", "b2", "e2", "e2"])
    }

    /// `timestamp` is on the `systemUptime` clock: a touch is delivered within moments of it.
    func testTimestampIsOnTheSystemUptimeClock() {
        center.doubleTap()
        XCTAssertGreaterThanOrEqual(Int(value("minTimestampLagMs")) ?? -1, 0)
        XCTAssertLessThan(Int(value("maxTimestampLagMs")) ?? 1000, 250)
    }

    /// Without force-sensing hardware (the simulator, and iPhones without 3D Touch), both are 0.
    func testForceIsZeroWithoutForceSensingHardware() {
        center.tap()
        XCTAssertEqual(value("forces"), "0.0/0.0")
    }
}
#endif
