import XCTest

final class CameraUITests: XCTestCase {
    @MainActor
    func testSkeletonLaunches() {
        let app = XCUIApplication()
        app.launchArguments = ["-pikicam.fake", "standard"]
        app.launch()
        let brand = app.staticTexts["PIKICAM"]
        XCTAssertTrue(brand.waitForExistence(timeout: 10), "Skeleton root view must show the brand mark")
    }
}
