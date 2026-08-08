import Foundation
import CoreImage

// MARK: - Capture Mode

/// The development mode for a RAW capture.
///
/// - `zero`: All enhancement knobs explicitly disabled. The "zero-process" signature look.
/// - `standard`: Apple's default CIRAWFilter processing (comparison baseline).
/// - `rawOnly`: Only the DNG is saved; the processed print is not persisted.
enum CaptureMode: String, CaseIterable, Sendable {
    case zero
    case standard
    case rawOnly

    var displayName: String {
        switch self {
        case .zero: "Zero"
        case .standard: "Standard"
        case .rawOnly: "RAW Only"
        }
    }
}

// MARK: - Develop Result

/// The result of developing a RAW file into a viewable image.
struct DevelopResult: Sendable {
    /// JPEG-encoded image data ready for display or saving.
    let jpegData: Data

    /// The underlying CIImage (scene-referred, linear or gamma-corrected).
    let ciImage: CIImage
}

// MARK: - RAWProcessor Protocol

/// Defines the interface for RAW image processors.
///
/// `CIRAWZeroProcessor` is the current (and only) implementation: Apple's
/// `CIRAWFilter` with every enhancement knob explicitly disabled.
///
/// Marked `nonisolated`: RAW development is pure computation with no UI state,
/// and is invoked from background actors (`DevelopService`), never the main actor.
nonisolated protocol RAWProcessor: Sendable {
    /// Develops a RAW DNG file into a viewable image using the specified mode.
    ///
    /// - Parameters:
    ///   - dngData: The raw DNG file data from `AVCapturePhoto.rawFileDataRepresentation()`.
    ///   - mode: The development mode determining which enhancements are applied.
    /// - Returns: A `CIImage` suitable for display or further rendering.
    /// - Throws: `DevelopError` if processing fails.
    func develop(dngData: Data, mode: CaptureMode) throws -> CIImage
}

// MARK: - Errors

enum DevelopError: LocalizedError {
    case invalidDNGData
    case filterCreationFailed
    case renderingFailed
    case jpegEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidDNGData:
            return "The DNG data is invalid or corrupted."
        case .filterCreationFailed:
            return "Failed to create the RAW development filter."
        case .renderingFailed:
            return "Failed to render the developed image."
        case .jpegEncodingFailed:
            return "Failed to encode the developed image as JPEG."
        }
    }
}
