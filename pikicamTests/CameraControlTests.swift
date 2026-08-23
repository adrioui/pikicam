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

    func testFlashModeCyclesOffOn() {
        XCTAssertEqual(FlashMode.off.next(), .on)
        XCTAssertEqual(FlashMode.on.next(), .off)
        // The cycle is closed under repeated application.
        var mode = FlashMode.off
        for _ in 0..<10 { mode = mode.next() }
        XCTAssertEqual(mode, .off)
    }

    func testFlashModeMapsToTorchModes() {
        XCTAssertEqual(FlashMode.off.avTorchMode, .off)
        XCTAssertEqual(FlashMode.on.avTorchMode, .on)
    }

    func testFlashModeLabels() {
        XCTAssertEqual(FlashMode.off.label, "Off")
        XCTAssertEqual(FlashMode.on.label, "On")
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

    // MARK: - Self-timer

    func testSelfTimerCyclesOffThreeTen() {
        XCTAssertEqual(SelfTimerOption.off.next(), .threeSeconds)
        XCTAssertEqual(SelfTimerOption.threeSeconds.next(), .tenSeconds)
        XCTAssertEqual(SelfTimerOption.tenSeconds.next(), .off)
        var option = SelfTimerOption.off
        for _ in 0..<9 { option = option.next() }
        XCTAssertEqual(option, .off, "Cycle is closed under repeated application.")
    }

    func testSelfTimerSecondsAreCorrect() {
        XCTAssertEqual(SelfTimerOption.off.seconds, 0)
        XCTAssertEqual(SelfTimerOption.threeSeconds.seconds, 3)
        XCTAssertEqual(SelfTimerOption.tenSeconds.seconds, 10)
    }

    // MARK: - Capture orientation

    func testCaptureOrientationMapsFromUIDeviceOrientation() {
        XCTAssertEqual(CaptureOrientation(orientation: .portrait), .up)
        XCTAssertEqual(CaptureOrientation(orientation: .portraitUpsideDown), .down)
        XCTAssertEqual(CaptureOrientation(orientation: .landscapeLeft), .left)
        XCTAssertEqual(CaptureOrientation(orientation: .landscapeRight), .right)
        // Face-up/face-down/unknown → portrait (safe default).
        XCTAssertEqual(CaptureOrientation(orientation: .faceUp), .up)
        XCTAssertEqual(CaptureOrientation(orientation: .unknown), .up)
    }

    // MARK: - Aspect ratio

    func testAspectRatioCycleIsClosed() {
        var ratio = AspectRatio.ratio4x3
        for _ in 0..<(AspectRatio.allCases.count * 2) { ratio = ratio.next() }
        XCTAssertEqual(ratio, .ratio4x3)
    }

    func testAspectRatioRatiosAreCorrect() {
        XCTAssertEqual(AspectRatio.ratio4x3.ratio, 4.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(AspectRatio.ratio16x9.ratio, 16.0 / 9.0, accuracy: 0.0001)
        XCTAssertEqual(AspectRatio.ratio1x1.ratio, 1.0, accuracy: 0.0001)
    }

    func testAspectRatioRatiosFollowExtentOrientation() {
        let landscape = CGRect(x: 0, y: 0, width: 4000, height: 3000)
        XCTAssertEqual(AspectRatio.ratio4x3.ratio(in: landscape), 4.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(AspectRatio.ratio16x9.ratio(in: landscape), 16.0 / 9.0, accuracy: 0.0001)

        let portrait = CGRect(x: 0, y: 0, width: 375, height: 812)
        XCTAssertEqual(AspectRatio.ratio4x3.ratio(in: portrait), 3.0 / 4.0, accuracy: 0.0001)
        XCTAssertEqual(AspectRatio.ratio16x9.ratio(in: portrait), 9.0 / 16.0, accuracy: 0.0001)
        XCTAssertEqual(AspectRatio.ratio1x1.ratio(in: portrait), 1.0, accuracy: 0.0001)
    }

    func testAspectRatioLabels() {
        XCTAssertEqual(AspectRatio.ratio4x3.label, "4:3")
        XCTAssertEqual(AspectRatio.ratio16x9.label, "16:9")
        XCTAssertEqual(AspectRatio.ratio1x1.label, "1:1")
    }

    // MARK: - Print crop

    func testPrintCropIntersectsZoomAndAspect() {
        let sensor = CGRect(x: 0, y: 0, width: 4000, height: 3000) // 4:3
        // 16:9 aspect on a 4:3 sensor → width-bound: keeps full sensor width,
        // crops top/bottom (iOS Camera photo convention).
        let crop = PrintCrop.rect(in: sensor, zoomFactor: 1.0, aspect: .ratio16x9)
        XCTAssertEqual(crop.width, sensor.width)
        XCTAssertEqual(crop.height, sensor.width / (16.0 / 9.0), accuracy: 0.0001)
        XCTAssertTrue(sensor.contains(crop))
        XCTAssertEqual(crop.midX, sensor.midX, accuracy: 0.0001)
        XCTAssertEqual(crop.midY, sensor.midY, accuracy: 0.0001)
    }

    func testPrintCropAppliesZoomInsideAspectRect() {
        let sensor = CGRect(x: 0, y: 0, width: 4000, height: 3000)
        let crop = PrintCrop.rect(in: sensor, zoomFactor: 2.0, aspect: .ratio1x1)
        XCTAssertEqual(crop.width, sensor.height / 2, accuracy: 0.0001) // 1:1 square, 2x zoom
        XCTAssertEqual(crop.height, sensor.height / 2, accuracy: 0.0001)
        XCTAssertTrue(sensor.contains(crop))
    }

    func testPrintCrop4x3IsFullSensor() {
        let sensor = CGRect(x: 0, y: 0, width: 4000, height: 3000)
        let crop = PrintCrop.rect(in: sensor, zoomFactor: 1.0, aspect: .ratio4x3)
        XCTAssertEqual(crop, sensor)
    }

    func testPrintCrop16x9OnPortraitViewIsTall() {
        let view = CGRect(x: 0, y: 0, width: 375, height: 812) // portrait screen
        let crop = PrintCrop.rect(in: view, zoomFactor: 1.0, aspect: .ratio16x9)
        // Portrait 9:16 fills the view width and is centered vertically.
        XCTAssertEqual(crop.width, view.width, accuracy: 0.0001)
        XCTAssertEqual(crop.height, view.width / (9.0 / 16.0), accuracy: 0.0001)
        XCTAssertTrue(view.contains(crop))
        XCTAssertEqual(crop.midX, view.midX, accuracy: 0.0001)
        XCTAssertEqual(crop.midY, view.midY, accuracy: 0.0001)
    }

    func testPrintCrop4x3OnPortraitViewIsPortrait() {
        let view = CGRect(x: 0, y: 0, width: 375, height: 812) // portrait screen
        let crop = PrintCrop.rect(in: view, zoomFactor: 1.0, aspect: .ratio4x3)
        XCTAssertEqual(crop.width, view.width, accuracy: 0.0001)
        XCTAssertEqual(crop.height, view.width / (3.0 / 4.0), accuracy: 0.0001)
        XCTAssertTrue(view.contains(crop))
        XCTAssertEqual(crop.midX, view.midX, accuracy: 0.0001)
        XCTAssertEqual(crop.midY, view.midY, accuracy: 0.0001)
    }

    func testPrintCropSquareOnPortraitViewIsCenteredSquare() {
        let view = CGRect(x: 0, y: 0, width: 375, height: 812) // portrait screen
        let crop = PrintCrop.rect(in: view, zoomFactor: 1.0, aspect: .ratio1x1)
        XCTAssertEqual(crop.width, view.width, accuracy: 0.0001)
        XCTAssertEqual(crop.height, view.width, accuracy: 0.0001)
        XCTAssertTrue(view.contains(crop))
        XCTAssertEqual(crop.midX, view.midX, accuracy: 0.0001)
        XCTAssertEqual(crop.midY, view.midY, accuracy: 0.0001)
    }

    // MARK: - Exposure compensation

    func testExposureCompensationSnapsToThirds() {
        XCTAssertEqual(ExposureCompensation(stops: 0.4).stops, 1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(ExposureCompensation(stops: -0.4).stops, -1.0 / 3.0, accuracy: 0.0001)
        XCTAssertEqual(ExposureCompensation(stops: 1.7).stops, 5.0 / 3.0, accuracy: 0.0001)
    }

    func testExposureCompensationClampsAtLimits() {
        XCTAssertEqual(ExposureCompensation(stops: 5.0).stops, ExposureCompensation.maxStop)
        XCTAssertEqual(ExposureCompensation(stops: -5.0).stops, ExposureCompensation.minStop)
    }

    func testExposureCompensationCycleWrapsAtLimits() {
        XCTAssertEqual(ExposureCompensation(stops: ExposureCompensation.maxStop).next().stops,
                       ExposureCompensation.minStop)
        XCTAssertEqual(ExposureCompensation(stops: ExposureCompensation.minStop).next().stops,
                       ExposureCompensation.minStop + ExposureCompensation.step)
    }

    func testExposureCompensationLabelFormats() {
        XCTAssertEqual(ExposureCompensation.zero.label, "0")
        XCTAssertEqual(ExposureCompensation(thirds: 3).label, "+1")
        XCTAssertEqual(ExposureCompensation(thirds: -6).label, "−2")
        XCTAssertEqual(ExposureCompensation(thirds: 2).label, "+2/3")
        XCTAssertEqual(ExposureCompensation(thirds: -1).label, "−1/3")
        XCTAssertEqual(ExposureCompensation(thirds: 5).label, "+1 2/3")
        XCTAssertEqual(ExposureCompensation(thirds: -7).label, "−2 1/3")
    }

    /// Stepping is done in whole thirds (`Int`), so a full cycle around the
    /// −3 … +3 range returns exactly to zero — no floating-point drift
    /// accumulates across repeated adjustments.
    func testExposureCompensationCycleIsDriftFree() {
        var value = ExposureCompensation.zero
        for _ in 0..<(ExposureCompensation.maxThird - ExposureCompensation.minThird + 1) {
            value = value.next()
        }
        XCTAssertEqual(value, .zero, "A full 19-step cycle must return exactly to zero.")
        XCTAssertEqual(value.stops, 0, accuracy: 0.0001)
    }

    // MARK: - Zoom presets

    func testZoomPresetsIncludeStandardStopsWithinRange() {
        XCTAssertEqual(ZoomPresets.factors(in: 1.0...6.0), [1.0, 2.0, 5.0])
        XCTAssertEqual(ZoomPresets.factors(in: 1.0...10.0), [1.0, 2.0, 5.0])
    }

    func testZoomPresetsOmitStopsBeyondRange() {
        XCTAssertEqual(ZoomPresets.factors(in: 1.0...3.0), [1.0, 2.0])
        // A front camera's fixed range surfaces only its lower bound.
        XCTAssertEqual(ZoomPresets.factors(in: 1.0...1.0), [1.0])
    }

    func testZoomPresetSelectionTolerance() {
        XCTAssertTrue(ZoomPresets.isSelected(1.0, of: 1.0))
        XCTAssertTrue(ZoomPresets.isSelected(2.001, of: 2.0))
        XCTAssertFalse(ZoomPresets.isSelected(1.5, of: 2.0))
        XCTAssertFalse(ZoomPresets.isSelected(3.0, of: 2.0))
    }
}
