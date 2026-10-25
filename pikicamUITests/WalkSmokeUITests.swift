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
        if back.waitForExistence(timeout: 10) {
            back.tap()
        }
        let archiveBack = app.buttons["archive.back"]
        if !archiveBack.waitForExistence(timeout: 10) {
            let systemBack = app.navigationBars.buttons.firstMatch
            XCTAssertTrue(systemBack.waitForExistence(timeout: 5), "a back control exists")
            systemBack.tap()
        } else {
            archiveBack.tap()
        }
        XCTAssertTrue(shutter.waitForExistence(timeout: 15), "back on camera after archive round-trip")
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

extension WalkSmokeUITests {
    @MainActor
    func testMonoCaptureAppearsInArchive() {
        let app = XCUIApplication()
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        Self.dismissSystemAlerts(springboard)
        let bnw = app.buttons["camera.bnw"]
        XCTAssertTrue(bnw.waitForExistence(timeout: 15))
        bnw.tap()
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        Thread.sleep(forTimeInterval: 2.5)
        Self.dismissSystemAlerts(springboard)
        Thread.sleep(forTimeInterval: 2)
        app.buttons["Open archive"].tap()
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Photo'")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 15), "mono photo appears in archive")
    }
}

extension WalkSmokeUITests {
    @MainActor
    func testRecordVideoClipAppearsInArchive() {
        let app = XCUIApplication()
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        Self.dismissSystemAlerts(springboard)
        let videoMode = app.buttons["camera.mode.video"]
        XCTAssertTrue(videoMode.waitForExistence(timeout: 15))
        videoMode.tap()
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        Thread.sleep(forTimeInterval: 8)
        Self.dismissSystemAlerts(springboard)
        app.buttons["camera.shutter"].tap()
        Thread.sleep(forTimeInterval: 3)
        app.buttons["Open archive"].tap()
        let cell = app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Photo'")).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 15), "clip appears in archive")
    }
}

extension WalkSmokeUITests {
    @MainActor
    func testMonoClipExportsAndSaves() {
        let app = XCUIApplication()
        app.launchArguments = ["-pikicam.dumpclip"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        Self.dismissSystemAlerts(springboard)
        let bnw = app.buttons["camera.bnw"]
        XCTAssertTrue(bnw.waitForExistence(timeout: 15))
        bnw.tap()
        app.buttons["camera.mode.video"].tap()
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        Thread.sleep(forTimeInterval: 6)
        Self.dismissSystemAlerts(springboard)
        app.buttons["camera.shutter"].tap()
        let saved = app.staticTexts["CLIP SAVED."]
        XCTAssertTrue(saved.waitForExistence(timeout: 45), "mono export + save completes")
    }
}

final class ArchiveHealthUITests: XCTestCase {
    @MainActor
    func testArchiveOpensWithoutCrashing() {
        let app = XCUIApplication()
        app.launchArguments = ["-pikicam.reset-migration"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Full Access", "Allow", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
            }
        }
        let archive = app.buttons["Open archive"]
        XCTAssertTrue(archive.waitForExistence(timeout: 15), "archive button visible")
        archive.tap()
        let anyContent = app.staticTexts["NO CAPTURES"].firstMatch
            .waitForExistence(timeout: 6)
            || app.buttons.matching(NSPredicate(format: "label BEGINSWITH 'Photo'")).firstMatch
                .waitForExistence(timeout: 6)
        XCTAssertTrue(anyContent, "archive shows content or empty state")
        Thread.sleep(forTimeInterval: 8)
        let back = app.buttons["archive.back"]
        XCTAssertTrue(back.exists, "archive chrome still present after scan window")
        back.tap()
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(
            shutter.waitForExistence(timeout: 10),
            "archive must stay responsive (regression: whole-library legacy scan froze main thread)"
        )
        XCTAssertTrue(app.state == .runningForeground)
    }

    @MainActor
    func testSaveReachesArchiveGridThroughReadPath() {
        let app = XCUIApplication()
        app.launchArguments = ["-pikicam.archive-diag"]
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Full Access", "Allow", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
            }
        }
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 15), "shutter visible")
        shutter.tap()
        for label in ["Allow Full Access", "Allow", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 4) {
                button.tap()
            }
        }
        Thread.sleep(forTimeInterval: 3)
        let archive = app.buttons["Open archive"]
        XCTAssertTrue(archive.waitForExistence(timeout: 5))
        archive.tap()
        let verdict = app.staticTexts["archive.verdict"]
        XCTAssertTrue(verdict.waitForExistence(timeout: 10), "read-path verdict visible")
        let label = Self.verdictText(verdict)
        XCTAssertTrue(label.contains("READ-PATH OK"), "read path serves the fresh capture, got: \(label)")
        let cell = app.buttons.matching(
            NSPredicate(format: "label BEGINSWITH 'Photo'")
        ).firstMatch
        XCTAssertTrue(cell.waitForExistence(timeout: 10), "capture cell appears in the grid")
    }

    @MainActor
    private static func verdictText(_ element: XCUIElement) -> String {
        for _ in 0..<10 {
            let label = element.label
            if !label.isEmpty && label != "READ-PATH: NO SAVE THIS SESSION" {
                return label
            }
            Thread.sleep(forTimeInterval: 1)
        }
        return element.label
    }
}

final class FrontCameraUITests: XCTestCase {
    @MainActor
    func testFlipToFrontAndBack() {
        let app = XCUIApplication()
        app.launch()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for label in ["Allow While Using App", "Allow Full Access", "Allow", "OK"] {
            let button = springboard.buttons[label]
            if button.waitForExistence(timeout: 2) {
                button.tap()
            }
        }
        let flip = app.buttons["camera.flip"]
        XCTAssertTrue(flip.waitForExistence(timeout: 15), "flip visible")
        flip.tap()
        Thread.sleep(forTimeInterval: 2)
        let shutter = app.buttons["camera.shutter"]
        XCTAssertTrue(shutter.waitForExistence(timeout: 5))
        shutter.tap()
        Thread.sleep(forTimeInterval: 3)
        XCTAssertTrue(app.state == .runningForeground, "front capture must not crash")
        flip.tap()
        Thread.sleep(forTimeInterval: 2)
        XCTAssertTrue(shutter.waitForExistence(timeout: 5), "flip back returns control")
    }
}
