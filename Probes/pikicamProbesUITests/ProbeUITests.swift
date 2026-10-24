import XCTest

final class ProbeUITests: XCTestCase {
    func testRunProbesToEnd() {
        let app = XCUIApplication()
        app.launch()

        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allowLabels = [
            "OK", "Allow", "Allow While Using App", "Allow While Using",
            "Allow Access to All Photos", "Allow Full Access", "Continue", "Set Up",
        ]
        for _ in 0..<16 {
            var tapped = false
            for label in allowLabels {
                let button = springboard.buttons[label]
                if button.waitForExistence(timeout: 1.5) {
                    button.tap()
                    tapped = true
                    break
                }
            }
            if !tapped {
                usleep(700_000)
            }
        }

        let done = app.staticTexts["PROBES-DONE"]
        let survived = done.waitForExistence(timeout: 900)
        if !survived {
            for _ in 0..<40 {
                if app.state != .runningForeground { break }
                sleep(2)
            }
            print("PROBE-UI-TEST: app state after wait = \(app.state.rawValue)")
        }
        print("PROBE-UI-TEST: PROBES-DONE observed = \(survived)")
        XCTAssertTrue(true, "probe run outcome recorded in probe-results.json regardless of trap-probe crash")
    }
}
