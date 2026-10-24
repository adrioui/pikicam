import XCTest

final class WalkDiagnosisUITests: XCTestCase {
    @MainActor
    func testWalkStepsOneThroughThree() {
        let app = XCUIApplication()
        app.launch()
        WalkTap.allowCameraIfAsked(app)
        WalkTap.enter(app)

        let shutter = app.buttons["Shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 20), "shutter visible after ENTER")
        shutter.tap()
        Thread.sleep(forTimeInterval: 12)
        XCTAssertTrue(app.state == .runningForeground, "app must still be running after a capture attempt")
    }
}

enum WalkTap {
    @MainActor
    static func allowCameraIfAsked(_ app: XCUIApplication) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 3) {
                button.tap()
                return
            }
        }
    }

    @MainActor
    static func enter(_ app: XCUIApplication) {
        let enter = app.buttons["[ ENTER ]"]
        if enter.waitForExistence(timeout: 5) {
            enter.tap()
        }
    }
}
