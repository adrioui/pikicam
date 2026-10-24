import XCTest

final class CameraUITests: XCTestCase {
    @MainActor
    private func launchApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-pikicam.fake", "standard"]
        app.launch()
        return app
    }

    @MainActor
    func testLaunchShowsCameraZones() {
        let app = launchApp()
        let badge = app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH '[ RAW'")).firstMatch
        XCTAssertTrue(badge.waitForExistence(timeout: 10), "status badge")
        XCTAssertTrue(app.buttons["Shutter"].exists, "shutter actuator")
        XCTAssertTrue(app.buttons["PHOTO MODE"].exists, "mode strip photo")
        XCTAssertTrue(app.buttons["VIDEO MODE"].exists, "mode strip video")
        XCTAssertTrue(app.buttons["SCAN MODE"].exists, "mode strip scan")
        XCTAssertTrue(app.buttons["CROP"].exists, "crop chip")
    }

    @MainActor
    func testFakeCaptureUpdatesThumbnail() {
        let app = launchApp()
        let shutter = app.buttons["Shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 10))
        shutter.tap()
        let thumbnail = app.images["camera.thumbnail"].firstMatch
        let appeared = thumbnail.waitForExistence(timeout: 15)
        XCTAssertTrue(appeared, "thumbnail should appear after a fake capture")
    }

    @MainActor
    func testLensRailSwitches() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["26 MILLIMETRE LENS"].waitForExistence(timeout: 10))
    }

    @MainActor
    func testLineMatrixDormantLinesAreInactive() {
        let app = launchApp()
        XCTAssertTrue(app.buttons["N° 00 Artisanal"].waitForExistence(timeout: 10))
        XCTAssertFalse(app.buttons["N° 03 Fragrance"].exists, "dormant lines must not be buttons")
    }
}
