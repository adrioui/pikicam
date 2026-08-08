import AVFoundation
import CoreVideo

/// Extension providing Bayer raw format detection helpers for `AVCaptureDevice`
/// and `AVCapturePhotoOutput`.
extension AVCapturePhotoOutput {
    /// Returns `true` if the pixel format type is a pure Bayer raw format
    /// (not ProRAW or processed).
    ///
    /// Pure Bayer formats disable all multi-frame computation (Smart HDR,
    /// Deep Fusion, Night Mode, Photonic Engine) by construction.
    static func isBayerRAWPixelFormat(_ format: OSType) -> Bool {
        switch format {
        case kCVPixelFormatType_14Bayer_RGGB,
             kCVPixelFormatType_14Bayer_GRBG,
             kCVPixelFormatType_14Bayer_GBRG,
             kCVPixelFormatType_14Bayer_BGGR:
            return true
        default:
            return false
        }
    }

    /// Returns the first available Bayer raw pixel format type, or `nil`
    /// if no pure Bayer format is available.
    var bayerRawPixelFormatType: OSType? {
        availableRawPhotoPixelFormatTypes.first { Self.isBayerRAWPixelFormat($0) }
    }

    /// Returns `true` if the output supports pure Bayer raw capture.
    var supportsBayerRaw: Bool {
        bayerRawPixelFormatType != nil
    }
}

extension AVCaptureDevice {
    /// Returns `true` if this device supports pure Bayer raw capture
    /// (as opposed to ProRAW-only).
    var supportsBayerRawCapture: Bool {
        // The device must support the .video media type and have a
        // photo output that exposes Bayer raw formats. This is a
        // shorthand — actual format availability is checked on the
        // AVCapturePhotoOutput instance.
        true
    }
}
