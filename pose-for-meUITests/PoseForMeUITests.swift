import XCTest

/// End-to-end flows: onboarding, session lifecycle, library/paywall, tabs, settings.
/// Sessions run in the simulator's demo mode (synthetic body), so camera-tracked
/// stretches complete without a physical camera.
final class PoseForMeUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    private func launch(_ extraArguments: [String] = [], skipOnboarding: Bool = true) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-pose4me.resetPro", "YES"]
        if skipOnboarding {
            app.launchArguments += ["-pose4me.skipOnboarding", "YES"]
        }
        app.launchArguments += extraArguments
        app.launch()
        return app
    }

    // MARK: Onboarding

    func testOnboardingFlowReachesHome() {
        let app = launch(["-pose4me.resetSettings", "YES"], skipOnboarding: false)

        XCTAssertTrue(app.staticTexts["Pose4Me"].waitForExistence(timeout: 5))
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Pick your rhythm"].waitForExistence(timeout: 3))
        app.staticTexts["Every 2 hours"].tap()
        app.buttons["Continue"].tap()

        XCTAssertTrue(app.staticTexts["Your camera is your coach"].waitForExistence(timeout: 3))
        app.buttons["Let's stretch"].tap()

        // Notification permission alert comes from SpringBoard, not the app.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.alerts.buttons["Allow"]
        if allow.waitForExistence(timeout: 4) {
            allow.tap()
        }

        XCTAssertTrue(app.buttons["home.stretchNow"].waitForExistence(timeout: 6),
                      "finishing onboarding should land on Home")
    }

    // MARK: Session lifecycle

    func testStartSessionFromHomeAndCancel() {
        let app = launch()

        let stretchNow = app.buttons["home.stretchNow"]
        XCTAssertTrue(stretchNow.waitForExistence(timeout: 6))
        stretchNow.tap()

        let start = app.buttons["session.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 5), "session intro should appear")

        app.buttons["session.close"].tap()
        XCTAssertTrue(stretchNow.waitForExistence(timeout: 5), "closing returns to Home")
    }

    func testFullSessionCompletesInDemoMode() {
        let app = launch([
            "-pose4me.autostart", "overhead-reach",
            "-pose4me.autobegin", "YES",
            "-pose4me.sessionSeconds", "15",
        ])

        // Intro is skipped by autobegin; countdown -> active -> summary.
        let complete = app.staticTexts["Stretch complete!"]
        XCTAssertTrue(complete.waitForExistence(timeout: 60),
                      "demo-mode session should finish on its own")

        app.buttons["session.done"].tap()
        XCTAssertTrue(app.buttons["home.stretchNow"].waitForExistence(timeout: 5))
    }

    func testSessionIntroAutoStartsAfterDemo() {
        let app = launch([
            "-pose4me.autostart", "neck-side-stretch",
            "-pose4me.previewSeconds", "10",
            "-pose4me.sessionSeconds", "15",
        ])

        let start = app.buttons["session.start"]
        XCTAssertTrue(start.waitForExistence(timeout: 6))
        // Without any tap, the demo timer should begin the session by itself.
        let complete = app.staticTexts["Stretch complete!"]
        XCTAssertTrue(complete.waitForExistence(timeout: 75),
                      "session should auto-start after the demo and complete")
    }

    // MARK: Library & paywall

    func testLibraryShowsExercisesAndProLockOpensPaywall() {
        let app = launch()

        app.tabBars.buttons["Library"].tap()
        XCTAssertTrue(app.staticTexts["Overhead Reach"].waitForExistence(timeout: 5))

        // Pro-locked exercise opens the paywall instead of a session.
        app.staticTexts["Torso Twist"].tap()
        XCTAssertTrue(app.staticTexts["Pose4Me Pro"].waitForExistence(timeout: 5),
                      "locked exercise should open the paywall")
        app.buttons["paywall.close"].tap()

        // Free exercise opens the session intro.
        app.staticTexts["Overhead Reach"].tap()
        XCTAssertTrue(app.buttons["session.start"].waitForExistence(timeout: 5))
        app.buttons["session.close"].tap()
    }

    // MARK: Tabs & settings

    func testTabsNavigateAndSettingsShowCustomization() {
        let app = launch()

        app.tabBars.buttons["Progress"].tap()
        XCTAssertTrue(app.staticTexts["Last 14 days"].waitForExistence(timeout: 5))

        app.tabBars.buttons["Settings"].tap()
        XCTAssertTrue(app.staticTexts["Active hours"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Movement demo"].exists)
        XCTAssertTrue(app.staticTexts["Appearance"].exists)

        // Appearance switch is a user-visible feature — flip to Dark and back.
        let appearance = app.segmentedControls.containing(.button, identifier: "Dark").firstMatch
        if appearance.exists {
            appearance.buttons["Dark"].tap()
            appearance.buttons["System"].tap()
        }

        app.tabBars.buttons["Today"].tap()
        XCTAssertTrue(app.buttons["home.stretchNow"].waitForExistence(timeout: 5))
    }
}
