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
/// feature). The honest RAW-compatible equivalent is the **torch**, used as
/// a shutter-time pulse: `on` fires the torch for the exposure, then turns
/// it back off — like a normal camera flash, not a constant work light.
nonisolated enum FlashMode: Equatable, CaseIterable {
    case off
    case on

    /// The next mode in the off → on → off cycle.
    func next() -> FlashMode {
        switch self {
        case .off: return .on
        case .on: return .off
        }
    }

    /// The `AVCaptureDevice.TorchMode` this mode maps to while the torch is
    /// actually firing during capture. `off` never fires.
    var avTorchMode: AVCaptureDevice.TorchMode {
        switch self {
        case .off: return .off
        case .on: return .on
        }
    }

    /// The human-readable label surfaced in the UI and UI tests.
    var label: String {
        switch self {
        case .off: return "Off"
        case .on: return "On"
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

// MARK: - AspectRatio

/// The output aspect ratio of the developed result. The DNG is always
/// captured full-sensor; the aspect is applied as a non-destructive crop at
/// develop/view time. 4:3 is the sensor-native default.
nonisolated public enum AspectRatio: String, CaseIterable, Codable, Sendable {
    case ratio4x3
    case ratio16x9
    case ratio1x1

    /// The landscape width/height ratio (e.g. 4:3 → 4/3).
    /// Use `ratio(in:)` when the extent may be portrait.
    var ratio: CGFloat {
        switch self {
        case .ratio4x3: return 4.0 / 3.0
        case .ratio16x9: return 16.0 / 9.0
        case .ratio1x1: return 1.0
        }
    }

    /// The width/height ratio appropriate for the given image extent.
    /// Sensor extents are typically landscape (4032×3024); view bounds are
    /// typically portrait (e.g. 375×812).  Returns the landscape ratio when
    /// the extent is wider than it is tall, and the portrait ratio (height /
    /// width) when the extent is taller than it is wide, matching the iOS
    /// Camera app convention (the label never changes — 16:9 is always
    /// labelled "16:9" regardless of orientation).
    func ratio(in extent: CGRect) -> CGFloat {
        if extent.width >= extent.height { return ratio }
        return 1.0 / ratio
    }

    var label: String {
        switch self {
        case .ratio4x3: return "4:3"
        case .ratio16x9: return "16:9"
        case .ratio1x1: return "1:1"
        }
    }

    func next() -> AspectRatio {
        let all = AspectRatio.allCases
        let index = all.firstIndex(of: self) ?? 0
        return all[(index + 1) % all.count]
    }
}

// MARK: - PrintCrop

/// The non-destructive print crop: the intersection of the user's framing
/// zoom and the chosen aspect ratio. The DNG stays full-sensor; this geometry
/// is applied only when developing/viewing the result.
nonisolated enum PrintCrop {

    static func rect(in extent: CGRect, zoomFactor: CGFloat, aspect: AspectRatio) -> CGRect {
        zoomRect(intersected: aspectRect(in: extent, aspect: aspect), in: extent, zoomFactor: zoomFactor)
    }

    /// The largest rect of `extent` matching `aspect`, centered.
    ///
    /// Each candidate fills one image axis: widthBound fills the width
    /// (cropping top/bottom), heightBound fills the height (cropping left/
    /// right). For 4:3 sensor + 16:9, widthBound fits and is chosen. For
    /// 4:3 sensor + 1:1, heightBound fits and is chosen. Matches the iOS
    /// Camera photo convention: the wider FOV is preserved by cropping the
    /// shorter axis.
    ///
    /// The aspect ratio is adjusted for the extent's orientation (landscape
    /// vs portrait) so the result is always correct regardless of whether
    /// `extent` is a sensor rectangle (landscape) or a view bounds (portrait).
    private static func aspectRect(in extent: CGRect, aspect: AspectRatio) -> CGRect {
        let r = aspect.ratio(in: extent)
        let widthBound = CGRect(x: 0, y: 0, width: extent.width, height: extent.width / r)
        let heightBound = CGRect(x: 0, y: 0, width: extent.height * r, height: extent.height)
        let fits = widthBound.height <= extent.height ? widthBound : heightBound
        let origin = CGPoint(x: extent.midX - fits.width / 2, y: extent.midY - fits.height / 2)
        return CGRect(x: origin.x, y: origin.y, width: fits.width, height: fits.height)
    }

    /// The centered `1/zoomFactor` rect of `aspectRect`, clamped to `extent`.
    private static func zoomRect(intersected aspectRect: CGRect, in extent: CGRect, zoomFactor: CGFloat) -> CGRect {
        guard zoomFactor > 1.0 else { return aspectRect }
        let width = aspectRect.width / zoomFactor
        let height = aspectRect.height / zoomFactor
        let origin = CGPoint(
            x: max(extent.minX, min(aspectRect.midX - width / 2, aspectRect.maxX - width)),
            y: max(extent.minY, min(aspectRect.midY - height / 2, aspectRect.maxY - height))
        )
        return CGRect(x: origin.x, y: origin.y, width: width, height: height)
    }
}

// MARK: - ZoomPresets

/// Pure math for the quick-zoom preset chips (no AVFoundation state —
/// testable). Presets are the meaningful digital-zoom stops of the current
/// camera's available range: its lower bound (always 1×) plus the standard
/// 2× and 5× stops when the range reaches them.
nonisolated enum ZoomPresets {

    /// The preset factors to surface for `range`, ascending and deduplicated.
    /// A front camera's fixed 1× range yields exactly `[lowerBound]`.
    static func factors(in range: ClosedRange<CGFloat>) -> [CGFloat] {
        var factors = [range.lowerBound]
        for candidate in [CGFloat(2.0), CGFloat(5.0)] where range.contains(candidate) {
            factors.append(candidate)
        }
        return factors
    }

    /// Whether `factor` is close enough to `preset` to highlight its chip.
    static func isSelected(_ factor: CGFloat, of preset: CGFloat) -> Bool {
        abs(factor - preset) < 0.01
    }
}

// MARK: - ExposureCompensation

/// Exposure bias in EV stops, snapped to 1/3-stop increments. The capture
/// device's `exposureTargetBias` accepts any value in `minExposureTargetBias
/// ... maxExposureTargetBias`; this snaps user input to discrete steps and
/// formats the label (e.g. "+1 2/3", "-2/3", "0").
///
/// Stepping happens in whole thirds (`Int`), so repeated adjustments never
/// accumulate floating-point drift; stops are computed only at the boundary
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
