import XCTest

/// Runtime UI tests: launch the app and exercise the real flows, no mocks.
///
/// - On the **simulator** (no Bayer sensor) the live UI surfaces the typed
///   `CaptureError.cameraUnavailable` state we observed in the runtime
///   screenshot and log.
/// - On a **physical device** the real camera exists, so the test walks the
///   first-launch permission flow, performs one real capture (RAW DNG +
///   zero-developed print saved to the Photos library), and attaches a
///   screenshot at every stage. Screenshots are `XCTAttachment`s with
///   `.keepAlways` lifetime; export them from the .xcresult with
///   `xcrun xcresulttool export attachments`.
final class SmokeLaunchTest: XCTestCase {

    /// True when running under the iOS Simulator.
    private var isSimulator: Bool {
        #if targetEnvironment(simulator)
            return true
        #else
            return false
        #endif
    }

    // MARK: - Simulator

    /// Launch + camera-unavailable error state, only meaningful on the
    /// simulator (no back wide camera, so `CaptureError.cameraUnavailable`
    /// renders in the live UI).
    func testLaunchAndCameraUnavailableErrorShown() throws {
        try XCTSkipUnless(
            isSimulator,
            "Simulator-only: a physical device has a back wide camera."
        )

        let app = XCUIApplication(bundleIdentifier: "piki.pikicam")
        app.launch()

        // Runtime smoke: the app reaches the foreground and stays alive.
        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "App did not reach runningForeground state within timeout."
        )
        attachScreenshot(of: app, named: "01-launch-simulator")

        // On a simulator the live UI shows one of two typed states, depending
        // on what the fresh sim grants (see runtime screenshots):
        // - With camera+photos granted: `CaptureError.cameraUnavailable`
        //   ("No back wide camera is available.").
        // - On a fresh sim without grants: the app stops before configuring
        //   the session at `CameraViewModelError.missingPermissions`
        //   ("Camera and photo library access are required.").
        // Either is the honest typed state for this environment; match loosely
        // (SwiftUI exposes the accessibilityLabel, prefixed with "Error: ").
        let errorText = app.staticTexts
            .matching(NSPredicate(
                format: "label CONTAINS[c] 'No back wide camera is available.' "
                    + "OR label CONTAINS[c] 'Camera and photo library access are required.'"))
            .firstMatch
        XCTAssertTrue(
            errorText.waitForExistence(timeout: 5),
            "Expected simulator camera-unavailable message to render."
        )
        attachScreenshot(of: app, named: "02-camera-unavailable-simulator")
    }

    // MARK: - Device

    /// Physical-device walkthrough: the entire real user flow with screenshots.
    ///
    /// 1. Launch the app.
    /// 2. If this is first install, grant camera + photo-library access
    ///    through the real system prompts (SpringBoard-hosted alerts are
    ///    driven directly — interruption monitors cannot construct their
    ///    element queries on recent iOS).
    /// 3. Wait for the live camera UI, screenshot it.
    /// 4. Take one real capture: RAW DNG + zero-developed print saved to
    ///    Photos. Screenshot the in-flight and final states.
    /// 5. Assert no typed error surfaced and the app stayed alive.
    func testDeviceCaptureWalkthrough() throws {
        try XCTSkipIf(
            isSimulator,
            "Device-only: requires a real Bayer sensor and Photos library."
        )

        let app = XCUIApplication(bundleIdentifier: "piki.pikicam")
        app.launch()
        attachScreenshot(of: app, named: "01-launch")

        XCTAssertTrue(
            app.wait(for: .runningForeground, timeout: 10),
            "App did not reach runningForeground state within timeout."
        )

        // First install: the permission interstitial leads to two real system
        // prompts (camera, then photo-library add-only).
        if app.buttons["Continue"].waitForExistence(timeout: 5) {
            attachScreenshot(of: app, named: "02-permission-interstitial")
            app.buttons["Continue"].tap()
            // Record the camera prompt itself before accepting it.
            RunLoop.current.run(until: Date().addingTimeInterval(1.5))
            attachScreenshot(of: app, named: "02b-permission-prompt")
            acceptSystemPermissions(app: app, waitFor: app.buttons["Capture photo"])
        }

        let shutter = app.buttons["Capture photo"]
        XCTAssertTrue(
            shutter.waitForExistence(timeout: 30),
            "Camera UI did not appear on the device within timeout. "
                + "If a permission was denied, reset pikicam permissions in Settings and re-run."
        )
        // Let the preview's first frames land so the screenshot shows the
        // live camera feed, not a black buffer.
        RunLoop.current.run(until: Date().addingTimeInterval(2))
        attachScreenshot(of: app, named: "03-camera-live-preview")

        // Camera controls: grid, flash, camera flip, pinch zoom (see
        // CameraControls + the standalone HUD views for identifiers).
        let gridToggle = app.buttons["grid-toggle"]
        XCTAssertTrue(gridToggle.waitForExistence(timeout: 5),
                      "Camera control HUD did not appear on the device.")
        attachScreenshot(of: app, named: "03b-camera-controls")

        // 3×3 grid overlay appears and disappears with its toggle.
        gridToggle.tap()
        XCTAssertTrue(app.otherElements["grid-overlay"].waitForExistence(timeout: 3),
                      "Grid overlay did not appear after toggling the grid.")
        attachScreenshot(of: app, named: "03c-grid-overlay")
        gridToggle.tap()
        XCTAssertTrue(app.otherElements["grid-overlay"].waitForNonExistence(timeout: 3),
                      "Grid overlay did not disappear after toggling the grid off.")

        // Flash (torch) cycles off → on → auto → off on the back camera.
        let flashToggle = app.buttons["flash-toggle"]
        XCTAssertTrue(flashToggle.exists, "Flash control missing while on the back camera.")
        flashToggle.tap()
        waitForValue(flashToggle, "On")
        flashToggle.tap()
        waitForValue(flashToggle, "Auto")
        flashToggle.tap()
        waitForValue(flashToggle, "Off")

        // Front camera: flip, verify state + zoom reset, flip back.
        let flip = app.buttons["front-camera-toggle"]
        flip.tap()
        waitForValue(flip, "Front")
        XCTAssertTrue(app.buttons["flash-toggle"].waitForNonExistence(timeout: 3),
                      "Flash control must disappear on the front camera (no torch).")
        attachScreenshot(of: app, named: "03d-front-camera")
        flip.tap()
        waitForValue(flip, "Back")
        XCTAssertTrue(app.buttons["flash-toggle"].waitForExistence(timeout: 3),
                      "Flash control did not return on the back camera.")

        // Pinch-to-zoom: the zoom indicator leaves and returns to 1.0x.
        // The pinch must target the app's root element (the ZStack carrying
        // the MagnificationGesture) — the AVCaptureVideoPreviewLayer-backed
        // preview element swallows synthetic pinch events.
        let zoomIndicator = app.staticTexts["zoom-indicator"]
        XCTAssertTrue(zoomIndicator.exists, "Zoom indicator missing from the HUD.")
        XCTAssertTrue(app.otherElements["preview-pinch-area"].exists,
                      "Preview pinch area missing.")
        app.pinch(withScale: 2.0, velocity: 0.8)
        waitFor(NSPredicate(format: "value != '1.0x'"), on: zoomIndicator, timeout: 5)
        attachScreenshot(of: app, named: "03e-zoomed")
        // Pinch-in back toward 1.0x: velocity must be negative when scale < 1
        // (XCUIElement.pinch raises NSInvalidArgumentException otherwise). Use
        // a decisive scale so the zoom-out reliably lands below the current
        // factor and clamps back to the 1.0x minimum.
        app.pinch(withScale: 0.1, velocity: -2.0)
        waitFor(NSPredicate(format: "value == '1.0x'"), on: zoomIndicator, timeout: 5)

        // One real capture: RAW DNG + zero-developed print, saved to Photos.
        // (The hardware volume buttons are the dedicated shutter — see
        // VolumeButtonCaptureView — while the on-screen button remains a
        // secondary path; this walkthrough drives the on-screen shutter.)
        shutter.tap()

        // The shutter disables while the capture → develop → save pipeline
        // is in flight, then re-enables when it finishes.
        XCTAssertTrue(
            shutter.wait(for: \.isEnabled, toEqual: false, timeout: 5),
            "Capture never entered the in-flight (disabled) state."
        )
        attachScreenshot(of: app, named: "04-capture-in-flight")
        XCTAssertTrue(
            shutter.wait(for: \.isEnabled, toEqual: true, timeout: 120),
            "Capture did not finish within 120s (button stayed disabled)."
        )
        RunLoop.current.run(until: Date().addingTimeInterval(1))
        attachScreenshot(of: app, named: "05-after-capture")

        assertNoErrorShown(in: app)
        XCTAssertEqual(
            app.state,
            .runningForeground,
            "App left the foreground during capture (crash?)."
        )
    }

    // MARK: - Helpers

    /// Accepts the camera ("OK"), photo-library add-only ("Allow"), and
    /// full-access ("Allow Full Access") system prompts.
    ///
    /// On iOS 26 the prompts are hosted by SpringBoard and interruption
    /// monitors fail to build queries for them ("Failed to construct element
    /// query matching interruption"), so we drive SpringBoard directly. The
    /// loop exits once the given `target` exists or no alert is frontmost
    /// (permissions may already be granted).
    private func acceptSystemPermissions(app: XCUIApplication, waitFor target: XCUIElement) {
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let deadline = Date().addingTimeInterval(30)
        var idleChecks = 0

        while Date() < deadline && !target.exists {
            let ok = springboard.buttons["OK"].firstMatch
            let allow = springboard.buttons["Allow"].firstMatch
            let allowFullAccess = springboard.buttons["Allow Full Access"].firstMatch

            if ok.exists {
                ok.tap()
                idleChecks = 0
            } else if allowFullAccess.exists {
                allowFullAccess.tap()
                idleChecks = 0
            } else if allow.exists {
                allow.tap()
                idleChecks = 0
            } else {
                idleChecks += 1
                // No alert frontmost for a few rounds — either the prompts
                // were already granted or none appeared. Let the caller's
                // waitForExistence decide.
                if idleChecks >= 4 { break }
            }
            RunLoop.current.run(until: Date().addingTimeInterval(0.5))
        }
        XCTAssertTrue(
            app.state == .runningForeground || target.exists,
            "App is not in the foreground after the permission flow.")
    }

    /// Asserts the live UI is not showing a typed pipeline error.
    private func assertNoErrorShown(in app: XCUIApplication) {
        let errorText = app.staticTexts
            .matching(NSPredicate(format: "label BEGINSWITH 'Error:'"))
            .firstMatch
        XCTAssertFalse(
            errorText.waitForExistence(timeout: 2),
            "Capture surfaced an error: \(errorText.label)"
        )
    }

    /// Waits until `element`'s accessibility value equals `value`.
    private func waitForValue(_ element: XCUIElement, _ value: String, timeout: TimeInterval = 5) {
        let predicate = NSPredicate(format: "value == %@", value)
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Element \(element) did not reach value '\(value)' within \(timeout)s "
                + "(current value: \(String(describing: element.value)))."
        )
    }

    /// Waits until `predicate` matches `element`.
    private func waitFor(_ predicate: NSPredicate, on element: XCUIElement, timeout: TimeInterval = 5) {
        let expectation = XCTNSPredicateExpectation(predicate: predicate, object: element)
        XCTAssertEqual(
            XCTWaiter().wait(for: [expectation], timeout: timeout),
            .completed,
            "Predicate \(predicate) never matched \(element) within \(timeout)s "
                + "(current value: \(String(describing: element.value)))."
        )
    }

    /// Captures the device screen into a named, persisted XCTAttachment.
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
