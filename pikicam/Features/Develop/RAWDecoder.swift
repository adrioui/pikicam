import Foundation
import CoreImage

// MARK: - RAWDecoder

/// A protocol for raw DNG decoding backends.
///
/// This protocol isolates the specific raw decoding library (CIRAWFilter,
/// custom Metal pipeline, or LibRaw) behind a common interface. The
/// `DevelopService` uses a `RAWDecoder` to obtain raw sensor data and
/// metadata, then passes it to a `RAWProcessor` for development.
///
/// ## Phase 1
/// `CIRAWDecoder` wraps `CIRAWFilter` — the only available backend.
///
/// ## Phase 2
/// `MetalDecoder` reads Bayer data directly via `CVMetalTextureCache`.
///
/// ## Phase 3
/// `LibRawDecoder` uses LibRaw's `open_buffer`/`unpack`/`raw2image` path
/// for full access to raw sensor data and DNG metadata.
protocol RAWDecoder: Sendable {
    /// Decodes the raw DNG data into a `CIImage` containing the Bayer mosaic.
    ///
    /// - Parameter dngData: Raw DNG file bytes.
    /// - Returns: A `CIImage` representing the raw sensor data.
    /// - Throws: `DecodeError` if decoding fails.
    func decode(_ dngData: Data) throws -> CIImage

    /// Extracts DNG metadata (color matrices, black/white levels, CFA pattern).
    ///
    /// - Parameter dngData: Raw DNG file bytes.
    /// - Returns: A `DNGMetadata` struct with all extracted values.
    /// - Throws: `DecodeError` if metadata extraction fails.
    func extractMetadata(_ dngData: Data) throws -> DNGMetadata
}

// MARK: - CIRAWDecoder

/// A `RAWDecoder` backed by Apple's `CIRAWFilter`.
///
/// This is the Phase 1 default decoder. It uses CoreImage's built-in
/// DNG parsing to obtain a `CIImage` from the raw data, and
/// `DNGTagParser` for metadata extraction.
///
/// `CIRAWFilter` performs demosaic, black-level application, and color
/// matrix internally — so the `CIImage` returned by `decode()` is already
/// demosaiced (not a raw mosaic). This is acceptable for Phase 1 since
/// `CIRAWZeroProcessor` applies its zero recipe on top.
struct CIRAWDecoder: RAWDecoder {
    func decode(_ dngData: Data) throws -> CIImage {
        guard let filter = CIRAWFilter(imageData: dngData) else {
            throw DecodeError.filterCreationFailed
        }
        guard let image = filter.outputImage else {
            throw DecodeError.noOutputImage
        }
        return image
    }

    func extractMetadata(_ dngData: Data) throws -> DNGMetadata {
        try DNGTagParser.parse(dngData)
    }
}

// MARK: - DecodeError

enum DecodeError: LocalizedError {
    case filterCreationFailed
    case noOutputImage
    case metadataExtractionFailed
    case unsupportedFormat

    var errorDescription: String? {
        switch self {
        case .filterCreationFailed:
            return "Failed to create a RAW filter from the DNG data."
        case .noOutputImage:
            return "The RAW filter produced no output image."
        case .metadataExtractionFailed:
            return "Failed to extract metadata from the DNG file."
        case .unsupportedFormat:
            return "The DNG format is not supported by this decoder."
        }
    }
}
