import AVFoundation
import Foundation

// MARK: - CameraPosition

/// The physical camera used for capture.
///
/// App-level typed position; the `AVCaptureDevice.Position` mapping happens
/// at the `CaptureService` boundary (parse-don't-validate).
enum CameraPosition: Equatable {
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
enum FlashMode: Equatable, CaseIterable {
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
enum ZoomMath {

    /// Clamps a raw zoom value into the device's available zoom range.
    static func clamped(_ value: CGFloat, range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(value, range.lowerBound), range.upperBound)
    }

    /// The zoom factor for `base × magnification`, clamped to `range`.
    static func factor(base: CGFloat, magnification: CGFloat, range: ClosedRange<CGFloat>) -> CGFloat {
        clamped(base * magnification, range: range)
    }

    /// The centered rect of `extent` at zoom `factor`. Factors ≤ 1.0
    /// return the full extent unchanged — this is the geometric counterpart
    /// to the zoom factor (see `factor` above): at `z`, the visible frame
    /// is the centered `1/z` of the full sensor.
    static func cropRect(in extent: CGRect, for zoomFactor: CGFloat) -> CGRect {
        guard zoomFactor > 1.0 else { return extent }
        let cropWidth = extent.width / zoomFactor
        let cropHeight = extent.height / zoomFactor
        let origin = CGPoint(
            x: extent.midX - cropWidth / 2,
            y: extent.midY - cropHeight / 2
        )
        return CGRect(x: origin.x, y: origin.y, width: cropWidth, height: cropHeight)
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
enum GridGeometry {

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
enum FramingMode: CaseIterable, Sendable {
    case photo
    case square

    /// The preview aperture ratio (width / height) this mode composes.
    var previewAspectRatio: CGFloat {
        switch self {
        case .photo: return 4.0 / 3.0
        case .square: return 1.0
        }
    }

    /// The human-readable label surfaced in the UI and UI tests.
    var label: String {
        switch self {
        case .photo: return "Photo"
        case .square: return "Square"
        }
    }

    /// The next mode in the photo → square → photo cycle.
    func next() -> FramingMode {
        switch self {
        case .photo: return .square
        case .square: return .photo
        }
    }
}
// MARK: - ExposureCompensation

/// Exposure bias in EV stops, snapped to 1/3-stop increments. The capture
/// device's `exposureTargetBias` accepts any value in `minExposureTargetBias
/// ... maxExposureTargetBias`; this snaps user input to discrete steps and
/// formats the label (e.g. "+1 2/3", "-2/3", "0").


struct ExposureCompensation: Equatable, Sendable {
    let stops: Double

    static let minStop: Double = -3.0
    static let maxStop: Double = 3.0
    static let step: Double = 1.0 / 3.0
    static let zero = ExposureCompensation(stops: 0)

    init(stops: Double) {
        let clamped = min(max(stops, Self.minStop), Self.maxStop)
        self.stops = (clamped / Self.step).rounded() * Self.step
    }

    func next() -> ExposureCompensation {
        let next = stops + Self.step
        let wrapped = next > Self.maxStop ? Self.minStop : next
        return ExposureCompensation(stops: wrapped)
    }

    var label: String {
        if stops == 0 { return "0" }
        let sign = stops > 0 ? "+" : "−"
        let whole = abs(stops)
        let thirds = (whole * 3).rounded()
        let intPart = Int(thirds) / 3
        let fracPart = Int(thirds.truncatingRemainder(dividingBy: 3))
        if fracPart == 0 { return "\(sign)\(intPart)" }
        if intPart == 0 { return "\(sign)\(fracPart)/3" }
        return "\(sign)\(intPart) \(fracPart)/3"
    }
}
