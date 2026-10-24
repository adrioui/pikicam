import Testing
import XCTest

@testable import pikicam

struct ClampingTests {
    static let limits: ClosedRange<Double> = 33...3168

    @Test func isoClampsInsideLimits() {
        #expect(ISO(clamping: 100, to: Self.limits).value == 100)
        #expect(ISO(clamping: 10, to: Self.limits).value == 33)
        #expect(ISO(clamping: 9000, to: Self.limits).value == 3168)
    }

    @Test func isoSaturatesNaNAndInfinity() {
        #expect(ISO(clamping: .nan, to: Self.limits).value == 33)
        #expect(ISO(clamping: .infinity, to: Self.limits).value == 3168)
        #expect(ISO(clamping: -.infinity, to: Self.limits).value == 33)
    }

    @Test func shutterSpeedSaturatesNaNAndInfinity() {
        let limits: ClosedRange<Double> = 1.0 / 71429...1.0 / 30
        #expect(ShutterSpeed(clamping: .nan, to: limits).seconds == limits.lowerBound)
        #expect(ShutterSpeed(clamping: .infinity, to: limits).seconds == limits.upperBound)
        #expect(ShutterSpeed(clamping: -.infinity, to: limits).seconds == limits.lowerBound)
    }

    @Test func shutterSpeedLabel() {
        #expect(ShutterSpeed(seconds: 1.0 / 125).label == "1/125")
        #expect(ShutterSpeed(seconds: 2).label == "2\"")
    }

    @Test func evSnapsToThirdStopsAndSaturates() {
        #expect(EV(clamping: 0.34).value == EV(1.0 / 3.0).value)
        #expect(EV(clamping: .nan).value == 0)
        #expect(EV(clamping: 100).value == 8)
        #expect(EV(clamping: -100).value == -8)
    }

    @Test func lensPositionSaturates() {
        #expect(LensPosition(clamping: .nan).value == 0)
        #expect(LensPosition(clamping: .infinity).value == 1)
        #expect(LensPosition(clamping: -1).value == 0)
        #expect(LensPosition(clamping: 2).value == 1)
    }

    @Test func normalizedPointSaturatesToCentre() {
        #expect(NormalizedPoint(x: .nan, y: .infinity).x == 0.5)
        #expect(NormalizedPoint(x: .nan, y: .infinity).y == 0.5)
        #expect(NormalizedPoint(x: -1, y: 2).x == 0)
        #expect(NormalizedPoint(x: -1, y: 2).y == 1)
    }

    @Test func kelvinAndTintClamp() {
        #expect(Kelvin(clamping: 1000).value == 2000)
        #expect(Kelvin(clamping: 20000).value == 10000)
        #expect(Tint(clamping: -999).value == -150)
        #expect(Tint(clamping: 999).value == 150)
    }
}

struct FrameGeometryTests {
    @Test func nativeAspectCoversWholeSensor() {
        let geometry = FrameGeometry(aspect: .native, crop: 1, sensorWidth: 4, sensorHeight: 3)
        #expect(geometry.normalizedRect == CGRect(x: 0, y: 0, width: 1, height: 1))
    }

    @Test func wideSensorWithSquareAspectTrimsWidth() {
        let geometry = FrameGeometry(aspect: .square, crop: 1, sensorWidth: 4, sensorHeight: 3)
        #expect(abs(geometry.normalizedRect.width - 0.75) < 1e-9)
        #expect(geometry.normalizedRect.height == 1)
    }

    @Test func cropZoomsTowardCentre() {
        let geometry = FrameGeometry(aspect: .native, crop: 2, sensorWidth: 4, sensorHeight: 3)
        #expect(abs(geometry.normalizedRect.width - 0.5) < 1e-9)
        #expect(abs(geometry.normalizedRect.midX - 0.5) < 1e-9)
    }

    @Test func pixelRectIsIntegral() {
        let geometry = FrameGeometry(aspect: .square, crop: 1, sensorWidth: 4032, sensorHeight: 3024)
        let rect = geometry.pixelRect(for: 4032, pixelHeight: 3024)
        #expect(rect.origin.x.rounded() == rect.origin.x)
        #expect(rect.width.rounded() == rect.width)
    }

    @Test func overlayAndDevelopRectsAgreeAtThreeSizes() {
        let geometry = FrameGeometry(aspect: .sixteenNines, crop: 1.5, sensorWidth: 4032, sensorHeight: 3024)
        for size in [
            CGSize(width: 390, height: 300), CGSize(width: 800, height: 600), CGSize(width: 1000, height: 1200),
        ] {
            let overlay = CGRect(origin: .zero, size: size)
            let normalized = geometry.normalizedRect
            let expected = CGRect(
                x: normalized.minX * size.width,
                y: normalized.minY * size.height,
                width: normalized.width * size.width,
                height: normalized.height * size.height
            )
            let developed = geometry.pixelRect(for: Int(size.width), pixelHeight: Int(size.height))
            #expect(abs(developed.width - expected.width) <= 2, "integral rounding shifts at most 1 px per edge")
            #expect(abs(developed.height - expected.height) <= 2, "integral rounding shifts at most 1 px per edge")
            _ = overlay
        }
    }

    @Test func cropSaturatesNaN() {
        let geometry = FrameGeometry(aspect: .native, crop: .nan, sensorWidth: 4, sensorHeight: 3)
        #expect(geometry.normalizedRect.width == 1)
    }
}

struct MonoTests {
    @Test func weightsRejectNegativesAndNonUnitSums() {
        #expect(MonoWeights(validating: -0.1, g: 0.7, b: 0.4) == nil)
        #expect(MonoWeights(validating: 0.5, g: 0.5, b: 0.5) == nil)
        #expect(MonoWeights(validating: 0.5, g: 0.5, b: 0.0) != nil)
        #expect(MonoWeights(validating: 0.22897, g: 0.69174, b: 0.07929) != nil)
    }

    @Test func neutralPresetMatchesP3LuminanceRow() {
        let weights = MonoPreset.neutral.weights
        #expect(abs(weights.r - 0.22897) < 1e-4)
        #expect(abs(weights.g - 0.69174) < 1e-4)
        #expect(abs(weights.b - 0.07929) < 1e-4)
    }

    @Test func everyPresetSumsToOne() {
        for preset in MonoPreset.allCases {
            let w = preset.weights
            #expect(abs(w.r + w.g + w.b - 1) <= 1e-5)
        }
    }

    @Test func redPresetDirection() {
        let red = MonoPreset.red.weights
        #expect(red.r > red.g && red.g > red.b)
    }
}

struct LineProfileTests {
    @Test func tableMatchesV2Mapping() {
        #expect(LineProfile.line(0)?.name == "Artisanal")
        #expect(LineProfile.line(4)?.look == LineProfile.line(0)?.look)
        #expect(LineProfile.line(1)?.look?.contrast ?? 0 < 0)
        #expect(LineProfile.line(10)?.look?.contrast ?? 0 > 0)
        #expect(LineProfile.line(14)?.mono?.preset == .neutral)
        #expect(LineProfile.line(22)?.bindsLens == nil)
    }

    @Test func dormantLinesCarryReasons() {
        for line in LineProfile.table where line.isDormant {
            #expect(line.dormantReason != nil)
        }
        #expect(LineProfile.line(11)?.bindsLens == .telephoto)
        #expect(LineProfile.line(11)?.isDormant == true)
    }
}
