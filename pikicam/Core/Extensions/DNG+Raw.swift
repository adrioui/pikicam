import Foundation
import UniformTypeIdentifiers

// MARK: - DNGFile

/// A lightweight wrapper around raw DNG (Digital Negative) file data.
///
/// Provides helpers for validating DNG structure and extracting metadata tags
/// needed by the development pipeline. Phase 1 only validates the file; Phase 2/3
/// will add full tag extraction (ColorMatrix, AsShotNeutral, BlackLevel, etc.)
/// per grand-plan.md §3.3.
struct DNGFile {
    /// The raw DNG file bytes.
    let data: Data

    // MARK: - Validation

    /// Returns `true` if the data starts with a valid TIFF/DNG byte order marker.
    ///
    /// DNG is a TIFF container. Valid byte orders:
    /// - `II*` (little-endian, Intel)
    /// - `MM*` (big-endian, Motorola)
    var isValidDNG: Bool {
        guard data.count >= 4 else { return false }
        // Little-endian TIFF: 0x49492A00 ("II*\0")
        let le: [UInt8] = [0x49, 0x49, 0x2A, 0x00]
        // Big-endian TIFF: 0x4D4D002A ("MM\0*")
        let be: [UInt8] = [0x4D, 0x4D, 0x00, 0x2A]
        let bytes = Array(data.prefix(4))
        return bytes == le || bytes == be
    }

    /// The TIFF byte order of the file, if valid.
    var byteOrder: ByteOrder? {
        guard data.count >= 2 else { return nil }
        let b0 = data[data.startIndex]
        let b1 = data[data.startIndex + 1]
        if b0 == 0x49 && b1 == 0x49 { return .littleEndian }
        if b0 == 0x4D && b1 == 0x4D { return .bigEndian }
        return nil
    }

    enum ByteOrder {
        case littleEndian
        case bigEndian
    }

    // MARK: - CFA Pattern (Phase 2)

    /// The Color Filter Array (Bayer) pattern.
    ///
    /// Phase 2 will parse this from DNG tag 0x828E (CFAPattern).
    /// For now, returns `.unknown` — Phase 1 relies on CIRAWFilter
    /// for demosaic and does not need this.
    var cfaPattern: CFAPattern {
        .unknown
    }
}

// MARK: - CFAPattern

/// The Bayer color filter array arrangement.
enum CFAPattern: String, Sendable {
    case rggb = "RGGB"
    case bggr = "BGGR"
    case grbg = "GRBG"
    case gbrg = "GBRG"
    case unknown = "UNKNOWN"
}

// MARK: - Data Extension

extension Data {
    /// Returns `true` if this data represents a valid DNG file.
    var isValidDNG: Bool {
        DNGFile(data: self).isValidDNG
    }

    /// The CFA (Bayer) pattern of this DNG, if extractable.
    var cfaPattern: CFAPattern {
        DNGFile(data: self).cfaPattern
    }
}
