import XCTest

final class WalkSmokeUITests: XCTestCase {
    @MainActor
    func testShootPhotoAppearsInArchive() {
        let app = XCUIApplication()
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        Self.dismissSystemAlerts(springboard)
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 15), "shutter visible")
        shutter.tap()
        Thread.sleep(forTimeInterval: 1.5)
        Self.dismissSystemAlerts(springboard)
        let archive = app.buttons["Open archive"]
        XCTAssertTrue(archive.waitForExistence(timeout: 5))
        archive.tap()
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Photo'")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 15), "captured photo appears in archive")
        cell.tap()
        let back = app.buttons["photo.back"]
        XCTAssertTrue(back.waitForExistence(timeout: 10))
        back.tap()
        let archiveBack = app.buttons["archive.back"]
        XCTAssertTrue(archiveBack.waitForExistence(timeout: 5))
        archiveBack.tap()
        XCTAssertTrue(shutter.waitForExistence(timeout: 10), "back on camera after archive round-trip")
    }

    @MainActor
    private static func dismissSystemAlerts(_ springboard: XCUIApplication) {
        let labels = ["Allow While Using App", "Allow Full Access", "Allow", "OK"]
        for _ in 0..<6 {
            var dismissed = false
            for label in labels {
                let button = springboard.buttons[label]
                if button.exists {
                    button.tap()
                    dismissed = true
                    Thread.sleep(forTimeInterval: 1.0)
                    break
                }
            }
            if !dismissed {
                return
            }
        }
    }
}
