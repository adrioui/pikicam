import AVFoundation
import Foundation

// MARK: - CameraPosition

/// The physical camera used for capture.
///
/// App-level typed position; the `AVCaptureDevice.Position` mapping happens
/// at the `CaptureService` boundary (parse-don't-validate).
nonisolated enum CameraPosition: Equatable {
    case back
    case front

    /// The AVCaptureDevice position backing this camera.
    var avPosition: AVCaptureDevice.Position {
        switch self {
        case .back: return .back
        case .front: return .front
        }
    }

    /// The human-readable label surfaced in the UI and UI tests.
    var label: String {
        switch self {
        case .back: return "Back"
        case .front: return "Front"
        }
    }
}

// MARK: - FlashMode

/// Flash control for the capture session.
///
/// Pikicam captures pure Bayer RAW single exposures, which cannot use
/// `AVCapturePhotoSettings.flashMode` (system flash is a processed-pipeline
/// feature). The honest RAW-compatible equivalent is the **torch**: a
/// continuous light the sensor actually sees. The three states mirror the
/// system Camera app's flash control: off / on / auto.
nonisolated enum FlashMode: Equatable, CaseIterable {
    case off
    case on
    case auto

    /// The next mode in the off → on → auto → off cycle.
    func next() -> FlashMode {
        switch self {
        case .off: return .on
        case .on: return .auto
        case .auto: return .off
        }
    }

    /// The `AVCaptureDevice.TorchMode` this mode maps to.
    var avTorchMode: AVCaptureDevice.TorchMode {
        switch self {
        case .off: return .off
        case .on: return .on
        case .auto: return .auto
        }
    }

    /// The human-readable label surfaced in the UI and UI tests.
    var label: String {
        switch self {
        case .off: return "Off"
        case .on: return "On"
        case .auto: return "Auto"
        }
    }
}

// MARK: - ZoomMath

/// Pure math for pinch-to-zoom (no AVFoundation state — testable).
nonisolated enum ZoomMath {

    /// Clamps a raw zoom value into the device's available zoom range.
    static func clamped(_ value: CGFloat, range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// The zoom factor for `base × magnification`, clamped to `range`.
    static func factor(base: CGFloat, magnification: CGFloat, range: ClosedRange<CGFloat>) -> CGFloat {
        clamped(base * magnification, range: range)
    }

    /// The compact label shown over the preview, e.g. "1.0x" (POSIX locale so
    /// the text — and UI tests asserting on it — never depend on the device's
    /// region settings).
    static func label(for factor: CGFloat) -> String {
        String(format: "%.1fx", locale: Locale(identifier: "en_US_POSIX"), factor)
    }
}

// MARK: - GridGeometry

/// Geometry for the rule-of-thirds (3×3) grid overlay.
nonisolated enum GridGeometry {

    /// The fraction positions of the grid lines along each axis.
    static let lineFractions: [CGFloat] = [1.0 / 3.0, 2.0 / 3.0]

    /// The x positions of the two vertical lines within a view of `size`.
    static func verticalLineXs(in size: CGSize) -> [CGFloat] {
        lineFractions.map { $0 * size.width }
    }

    /// The y positions of the two horizontal lines within a view of `size`.
    static func horizontalLineYs(in size: CGSize) -> [CGFloat] {
        lineFractions.map { $0 * size.height }
    }
}

// MARK: - FramingMode

/// The compositional aperture shown over the full-sensor preview.
///
/// Framing is preview-only: `photo` shows the 4:3 sensor aperture (3:4 in
/// portrait), `square` shows a centered 1:1 compositional aperture over the
/// same full sensor feed. The captured DNG is always the unchanged
/// full-sensor original; no crop is applied, encoded, or persisted.
nonisolated enum FramingMode: CaseIterable, Sendable {
    case photo
    case square
}

// MARK: - ExposureCompensation

/// Exposure bias in EV stops, snapped to 1/3-stop increments. The capture
/// device's `exposureTargetBias` accepts any value in `minExposureTargetBias
/// ... maxExposureTargetBias`; this snaps user input to discrete steps and
/// formats the label (e.g. "+1 2/3", "-2/3", "0").
///
/// Stepping happens in whole thirds (`Int`), so repeated cycling never
/// accumulates floating-point drift; stops are computed only at the boundary
/// where the device needs them.
nonisolated struct ExposureCompensation: Equatable, Sendable {
    /// The bias in whole thirds of an EV stop (each `third` == 1/3 EV).
    let thirds: Int

    static let minThird = -9
    static let maxThird = 9
    static let step: Double = 1.0 / 3.0
    static let zero = ExposureCompensation(thirds: 0)

    /// The EV-stop value of the limits, for device-range clamping.
    static var minStop: Double { Double(minThird) * step }
    static var maxStop: Double { Double(maxThird) * step }

    init(thirds: Int) {
        self.thirds = min(max(thirds, Self.minThird), Self.maxThird)
    }

    init(stops: Double) {
        let clamped = min(max(stops, Self.minStop), Self.maxStop)
        self.init(thirds: Int((clamped / Self.step).rounded()))
    }

    /// The EV-stop value this compensation represents, snapped to thirds.
    var stops: Double {
        Double(thirds) * Self.step
    }

    /// The next step in the −3 … +3 cycle, wrapping from +3 back to −3.
    func next() -> ExposureCompensation {
        let next = thirds + 1
        let wrapped = next > Self.maxThird ? Self.minThird : next
        return ExposureCompensation(thirds: wrapped)
    }

    var label: String {
        if thirds == 0 { return "0" }
        let sign = thirds > 0 ? "+" : "−"
        let whole = abs(thirds) / 3
        let frac = abs(thirds) % 3
        if frac == 0 { return "\(sign)\(whole)" }
        if whole == 0 { return "\(sign)\(frac)/3" }
        return "\(sign)\(whole) \(frac)/3"
    }
}
