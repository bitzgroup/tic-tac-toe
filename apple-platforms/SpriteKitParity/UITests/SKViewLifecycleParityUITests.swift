import XCTest

/// Records what Apple's `SKView` does to scene/view pausing when the app goes to the background
/// and comes back — the behavior bitzgroup/SpriteKit's `SKView.onPause()`/`onResume()` mirror.
final class SKViewLifecycleParityUITests: XCTestCase {
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-scenario", scenario]
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

    private func backgroundAndReturn(_ app: XCUIApplication) {
        #if os(tvOS)
        XCUIRemote.shared.press(.home)
        #else
        XCUIDevice.shared.press(.home)
        #endif
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5) || app.wait(for: .runningBackgroundSuspended, timeout: 5))
        app.activate()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
        sleep(1)
    }

    func testAScenePausedThroughItsOwnIsPausedIsUnpausedOnReturningToTheForeground() {
        let app = launch("pauseScene")
        sleep(1)
        XCTAssertEqual(value("scenePaused", in: state(app)), "true")
        let updatesWhilePaused = value("updates", in: state(app))
        sleep(1)
        XCTAssertEqual(value("updates", in: state(app)), updatesWhilePaused, "a paused scene gets no update(_:)")

        backgroundAndReturn(app)

        XCTAssertEqual(value("scenePaused", in: state(app)), "false")
        XCTAssertNotEqual(value("updates", in: state(app)), updatesWhilePaused)
    }

    func testAPausedViewStaysPausedOnReturningToTheForeground() {
        let app = launch("pauseView")
        sleep(1)
        let before = state(app)
        XCTAssertEqual(value("viewPaused", in: before), "true")
        XCTAssertEqual(value("scenePaused", in: before), "true")

        backgroundAndReturn(app)

        let after = state(app)
        XCTAssertEqual(value("viewPaused", in: after), "true")
        XCTAssertEqual(value("scenePaused", in: after), "true")
        XCTAssertEqual(value("updates", in: after), value("updates", in: before))
    }
}
