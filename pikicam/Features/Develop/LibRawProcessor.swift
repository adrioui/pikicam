import Foundation
import CoreImage

// MARK: - LibRawProcessor

/// A `RAWProcessor` backed by LibRaw for advanced development (Phase 3).
///
/// LibRaw provides access to AMaZE/DCB demosaic algorithms, per-channel
/// black levels, lens correction data, and highlight reconstruction —
/// all with full control over every processing step.
///
/// ## Phase 3 Integration Plan
///
/// 1. **Cross-compile LibRaw for iOS arm64** using
///    `zhanggenning/CPP-Libraries-for-iOS` build scripts or a custom
///    XCFramework. Link `libz.tbd` and `libc++.tbd`.
///
/// 2. **Create a C bridging layer** (`LibRawBridge.h` / `.m`) exposing:
///    - `libraw_open_buffer(const void* data, size_t size) -> void*`
///    - `libraw_unpack(void* handle) -> int`
///    - `libraw_raw2image(void* handle) -> int`
///    - `libraw_get_raw_image(void* handle) -> const uint16_t*`
///    - `libraw_get_width(void* handle) -> int`
///    - `libraw_get_height(void* handle) -> int`
///    - `libraw_get_color_matrix(void* handle, float out[9]) -> void`
///    - `libraw_get_as_shot_neutral(void* handle, float out[3]) -> void`
///    - `libraw_get_black_levels(void* handle, float out[4]) -> void`
///    - `libraw_get_white_level(void* handle) -> float`
///    - `libraw_amaze_demosaic(void* handle, float* out_rgba) -> int`
///    - `libraw_dcb_demosaic(void* handle, float* out_rgba) -> int`
///    - `libraw_close(void* handle) -> void`
///
/// 3. **Import the bridging header** in the bridging header file.
///
/// 4. **This processor** calls the bridge, extracts raw data + metadata,
///    runs the selected demosaic algorithm, then applies color matrix
///    and tone via the existing Metal pipeline or CPU-side processing.
///
/// ## Why Not Available Yet
/// LibRaw is a C++ library that must be cross-compiled for iOS arm64.
/// This cannot be done on a Linux build machine — it requires Xcode
/// and the iOS SDK. The `RAWDecoder` protocol ensures the app works
/// without LibRaw (falling back to CIRAWFilter or Metal).
///
/// Until LibRaw is integrated, this processor throws for any develop call.
nonisolated struct LibRawProcessor: RAWProcessor {
    func develop(dngData: Data, mode: CaptureMode) throws -> CIImage {
        throw LibRawError.notYetIntegrated
    }
}

// MARK: - LibRawError

enum LibRawError: LocalizedError {
    /// LibRaw has not been compiled and linked yet (Phase 3).
    case notYetIntegrated
    /// LibRaw failed to open the DNG buffer.
    case openFailed
    /// LibRaw failed to unpack the raw data.
    case unpackFailed
    /// The requested demosaic algorithm is not available.
    case unsupportedAlgorithm

    var errorDescription: String? {
        switch self {
        case .notYetIntegrated:
            return "LibRaw integration is not yet available (Phase 3). Using CIRAWFilter fallback."
        case .openFailed:
            return "LibRaw could not open the DNG data."
        case .unpackFailed:
            return "LibRaw could not unpack the raw sensor data."
        case .unsupportedAlgorithm:
            return "The requested demosaic algorithm is not supported by this LibRaw build."
        }
    }
}

// MARK: - HighlightReconstruction

/// Highlight reconstruction algorithms for recovering clipped channels.
///
/// When one or more color channels clip (reach sensor saturation), the
/// demosaiced image shows color casts in the clipped regions. Highlight
/// reconstruction recovers these by interpolating from unclipped channels.
enum HighlightReconstruction: String, CaseIterable, Sendable, Codable {
    /// No highlight reconstruction — clipped values stay clipped.
    case none = "None"
    /// Clip values to white. Simplest, preserves color but loses detail.
    case clip = "Clip"
    /// Reconstruct clipped channels from unclipped channels using luminance.
    case luminance = "Luminance"
    /// Multi-channel reconstruction (LibRaw's highlight mode 2+).
    case multiChannel = "Multi-Channel"

    var description: String {
        switch self {
        case .none:
            return "No reconstruction. Clipped values remain clipped."
        case .clip:
            return "Clip to white. Simple but loses highlight detail."
        case .luminance:
            return "Reconstruct clipped channels from luminance of unclipped channels."
        case .multiChannel:
            return "Multi-channel reconstruction (LibRaw mode 2+). Best quality."
        }
    }
}
