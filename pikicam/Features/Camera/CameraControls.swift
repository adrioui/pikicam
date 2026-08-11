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

    /// The compact label shown over the preview, e.g. "1.0x" (POSIX locale so
    /// the text — and UI tests asserting on it — never depend on the
    /// device's region settings).
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

// MARK: - CropMath

/// Geometry for mapping a framing zoom factor to a print crop.
///
/// Pure-Bayer RAW only captures at 1× (AVFoundation raises an uncaught ObjC
/// exception for RAW + zoom > 1 — see `CaptureService.capturePhoto`), so the
/// capture runs at 1× and the framing zoom is restored immediately. The DNG
/// is therefore full-sensor and the developed print must be cropped to the
/// field of view the user composed: at factor `z`, the visible frame is the
/// centered `1/z` of the full sensor.
enum CropMath {

    /// The centered rect of `extent` representing the field of view at
    /// `factor`. Factors ≤ 1.0 (no zoom) return the full extent unchanged.
    /// The crop keeps the image's native resolution (a rect crop, no
    /// resampling).
    static func rect(in extent: CGRect, for factor: CGFloat) -> CGRect {
        guard factor > 1.0 else { return extent }
        let cropWidth = extent.width / factor
        let cropHeight = extent.height / factor
        let origin = CGPoint(
            x: extent.midX - cropWidth / 2,
            y: extent.midY - cropHeight / 2
        )
        return CGRect(x: origin.x, y: origin.y, width: cropWidth, height: cropHeight)
    }
}
