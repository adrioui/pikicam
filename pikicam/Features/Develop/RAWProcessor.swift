import Foundation
import CoreImage

// MARK: - RAWProcessor Protocol

/// Defines the interface for RAW image processors.
///
/// `CIRAWZeroProcessor` is the current (and only) implementation: Apple's
/// `CIRAWFilter` with every enhancement knob explicitly disabled. Zero-process
/// is the only development recipe — there are no capture modes.
///
/// Marked `nonisolated`: RAW development is pure computation with no UI state,
/// and is invoked from background actors (`DevelopService`), never the main actor.
nonisolated protocol RAWProcessor: Sendable {
    /// Develops a RAW DNG file into a viewable image.
    ///
    /// - Parameter dngData: The raw DNG file data from `AVCapturePhoto.rawFileDataRepresentation()`.
    /// - Returns: A `CIImage` suitable for transient display rendering.
    /// - Throws: `DevelopError` if processing fails.
    func develop(dngData: Data) throws -> CIImage
}

// MARK: - DNG Display Rendition

/// The transient result of developing a RAW DNG for display.
///
/// In-memory only: produced for transient UI presentation (full-screen
/// review of the original DNG). It is never encoded to JPEG, written to
/// disk, or persisted anywhere.
struct DNGDisplayRendition: Sendable {
    /// The developed image (zero-process, oriented for display).
    let ciImage: CIImage

    /// The rendered display bitmap.
    let cgImage: CGImage
}

// MARK: - Errors

enum DevelopError: LocalizedError, Equatable {
    case invalidDNGData
    case filterCreationFailed
    case unsupportedControl(String)
    case renderingFailed

    var errorDescription: String? {
        switch self {
        case .invalidDNGData:
            return "The DNG data is invalid or corrupted."
        case .filterCreationFailed:
            return "Failed to create the RAW development filter."
        case .unsupportedControl(let control):
            return "The RAW developer does not support the '\(control)' control on this device."
        case .renderingFailed:
            return "Failed to render the developed image."
        }
    }
}
