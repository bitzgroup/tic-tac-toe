#if os(tvOS)
import XCTest

/// Records how Apple's SpriteKit delivers Siri Remote presses (`UIPress`) on tvOS — the behavior
/// bitzgroup/SpriteKit's `SKNode.presses*` mirrors for Android TV remotes and D-pads.
final class SKScenePressesParityUITests: XCTestCase {
    private func launch(_ scenario: String) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-scenario", scenario]
        app.launch()
        sleep(1)
        return app
    }

    private func value(_ key: String, in app: XCUIApplication) -> String {
        let label = app.staticTexts["state"]
        XCTAssertTrue(label.waitForExistence(timeout: 5))
        usleep(300_000)
        let state = label.label
        return state.split(separator: " ").first { $0.hasPrefix("\(key)=") }.map { String($0.dropFirst(key.count + 1)) } ?? ""
    }

    func testSpriteKitDeliversNoPressesToTheSceneByItself() {
        // Neither by default nor with the SKView as first responder; the menu press then leaves
        // the app, since nothing handles it.
        for scenario in ["presses", "viewFirstResponder"] {
            let app = launch(scenario)
            XCUIRemote.shared.press(.select)
            XCUIRemote.shared.press(.up)
            XCTAssertEqual(value("presses", in: app), "", scenario)
            if scenario == "viewFirstResponder" { XCTAssertEqual(value("becameFirstResponder", in: app), "true") }
            XCTAssertEqual(value("childPresses", in: app), "0", scenario)
            app.terminate()
        }
    }

    func testForwardedRemoteButtonsArriveAsBeganThenEndedWithAppleShapedTypes() {
        let app = launch("forwarded")
        for button: XCUIRemote.Button in [.up, .down, .left, .right, .select, .playPause] {
            XCUIRemote.shared.press(button)
        }
        XCTAssertEqual(
            value("presses", in: app),
            [
                "began:up", "ended:up", "began:down", "ended:down", "began:left", "ended:left",
                "began:right", "ended:right", "began:select", "ended:select", "began:playPause", "ended:playPause",
            ].joined(separator: ",")
        )
    }

    func testAForwardedHeldButtonIsOneBeganAndOneEnded() {
        let app = launch("forwarded")
        XCUIRemote.shared.press(.select, forDuration: 1.5)
        XCTAssertEqual(value("presses", in: app), "began:select,ended:select")
    }

    func testAForwardedMenuPressThatIsHandledKeepsTheAppInTheForeground() {
        let app = launch("forwarded")
        XCUIRemote.shared.press(.menu)
        XCTAssertEqual(value("presses", in: app), "began:menu,ended:menu")
        XCTAssertEqual(app.state, .runningForeground)
    }

    func testAForwardedMenuPressPassedOnUpTheResponderChainLeavesTheApp() {
        let app = launch("forwardedPassedOn")
        XCUIRemote.shared.press(.menu)
        XCTAssertTrue(app.wait(for: .runningBackground, timeout: 5) || app.wait(for: .runningBackgroundSuspended, timeout: 5))
    }
}
#endif
