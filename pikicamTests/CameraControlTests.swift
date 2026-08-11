import XCTest
import AVFoundation
@testable import pikicam

/// Unit tests for the camera-control model types (pure logic, no AVFoundation
/// device state): camera position, flash cycling, pinch-zoom math, and the
/// rule-of-thirds grid geometry.
final class CameraControlTests: XCTestCase {

    // MARK: - Camera position

    func testCameraPositionMapsToAVCapturePosition() {
        XCTAssertEqual(CameraPosition.back.avPosition, .back)
        XCTAssertEqual(CameraPosition.front.avPosition, .front)
        XCTAssertEqual(CameraPosition.back.label, "Back")
        XCTAssertEqual(CameraPosition.front.label, "Front")
    }

    // MARK: - Flash

    func testFlashModeCyclesOffOnAuto() {
        XCTAssertEqual(FlashMode.off.next(), .on)
        XCTAssertEqual(FlashMode.on.next(), .auto)
        XCTAssertEqual(FlashMode.auto.next(), .off)
        // The cycle is closed under repeated application.
        var mode = FlashMode.off
        for _ in 0..<12 { mode = mode.next() }
        XCTAssertEqual(mode, .off)
    }

    func testFlashModeMapsToTorchModes() {
        XCTAssertEqual(FlashMode.off.avTorchMode, .off)
        XCTAssertEqual(FlashMode.on.avTorchMode, .on)
        XCTAssertEqual(FlashMode.auto.avTorchMode, .auto)
    }

    func testFlashModeLabels() {
        XCTAssertEqual(FlashMode.off.label, "Off")
        XCTAssertEqual(FlashMode.on.label, "On")
        XCTAssertEqual(FlashMode.auto.label, "Auto")
    }

    // MARK: - Zoom math

    func testZoomFactorScalesBaseByMagnification() {
        let range: ClosedRange<CGFloat> = 1.0...5.0
        XCTAssertEqual(
            ZoomMath.factor(base: 1.0, magnification: 2.0, range: range),
            2.0, accuracy: 0.0001
        )
        XCTAssertEqual(
            ZoomMath.factor(base: 2.0, magnification: 1.5, range: range),
            3.0, accuracy: 0.0001
        )
    }

    func testZoomFactorClampsToAvailableRange() {
        let range: ClosedRange<CGFloat> = 1.0...5.0
        // Below the minimum (pinch-in beyond 1×) clamps to the minimum.
        XCTAssertEqual(
            ZoomMath.factor(base: 1.0, magnification: 0.5, range: range),
            1.0, accuracy: 0.0001
        )
        // Above the maximum (aggressive pinch-out) clamps to the maximum.
        XCTAssertEqual(
            ZoomMath.factor(base: 1.0, magnification: 12.0, range: range),
            5.0, accuracy: 0.0001
        )
        XCTAssertEqual(ZoomMath.clamped(0.2, range: range), 1.0, accuracy: 0.0001)
        XCTAssertEqual(ZoomMath.clamped(9.0, range: range), 5.0, accuracy: 0.0001)
    }

    func testZoomFactorIsIdentityOnFixedRange() {
        // Front cameras typically expose a fixed 1× range: any gesture maps
        // back to 1.0 instead of crashing or mis-scaling.
        let fixed: ClosedRange<CGFloat> = 1.0...1.0
        XCTAssertEqual(
            ZoomMath.factor(base: 1.0, magnification: 3.0, range: fixed),
            1.0, accuracy: 0.0001
        )
    }

    func testZoomLabelFormattingIsLocaleStable() {
        XCTAssertEqual(ZoomMath.label(for: 1.0), "1.0x")
        XCTAssertEqual(ZoomMath.label(for: 2.5), "2.5x")
        XCTAssertEqual(ZoomMath.label(for: 3.27), "3.3x")
    }

    // MARK: - Grid geometry

    func testGridLinesAreAtThirds() {
        let size = CGSize(width: 300, height: 600)
        let xs = GridGeometry.verticalLineXs(in: size)
        XCTAssertEqual(xs.count, 2)
        XCTAssertEqual(xs[0], 100, accuracy: 0.0001)
        XCTAssertEqual(xs[1], 200, accuracy: 0.0001)

        let ys = GridGeometry.horizontalLineYs(in: size)
        XCTAssertEqual(ys.count, 2)
        XCTAssertEqual(ys[0], 200, accuracy: 0.0001)
        XCTAssertEqual(ys[1], 400, accuracy: 0.0001)
    }

    func testGridLineFractions() {
        XCTAssertEqual(GridGeometry.lineFractions.count, 2)
        XCTAssertEqual(GridGeometry.lineFractions[0], 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(GridGeometry.lineFractions[1], 2.0 / 3.0, accuracy: 0.0001)
    }
}
