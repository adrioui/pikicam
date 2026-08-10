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

        // On a simulator the live UI shows the typed no-camera error
        // (see runtime screenshot: OCR captured this text). Match loosely:
        // SwiftUI replaces the Text's label with the accessibilityLabel,
        // which is prefixed with "Error: ".
        let errorText = app.staticTexts
            .matching(NSPredicate(format: "label CONTAINS[c] 'No back wide camera is available.'"))
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

        // One real capture: RAW DNG + zero-developed print, saved to Photos.
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

    /// Captures the device screen into a named, persisted XCTAttachment.
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
