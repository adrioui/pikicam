import Foundation
import CoreImage
import ImageIO
import UniformTypeIdentifiers

// MARK: - DNGMetadata

/// Metadata extracted from a DNG file needed by the Metal debayer pipeline.
///
/// All values are read from DNG/TIFF tags via `CGImageSource` and
/// `CGImageProperties`. This struct is the bridge between the DNG file
/// and the `DemosaicUniforms` struct uploaded to the Metal kernel.
///
/// Marked `nonisolated`: it is a pure value type carrying DNG tag data
/// across isolation boundaries (produced by `DNGTagParser`, consumed by
/// the background `MetalPipelineRunner`).
nonisolated struct DNGMetadata: Sendable {
    /// Image width in pixels.
    let width: Int
    /// Image height in pixels.
    let height: Int
    /// The Bayer CFA pattern (RGGB, BGGR, GRBG, GBRG).
    let cfaPattern: CFAPattern
    /// Per-channel black levels: [R, G1, B, G2].
    let blackLevel: [Float]
    /// White level (sensor saturation value).
    let whiteLevel: Float
    /// AsShot neutral values [R, G, B] — gains to neutralize white.
    let asShotNeutral: [Float]
    /// Camera RGB → XYZ D50 color matrix (3×3, row-major).
    let colorMatrix1: [Float]
    /// Optional second color matrix (different illuminant).
    let colorMatrix2: [Float]?
    /// Forward matrix camera RGB → XYZ (preferred over ColorMatrix if present).
    let forwardMatrix1: [Float]?
    /// Optional second forward matrix.
    let forwardMatrix2: [Float]?
    /// Baseline exposure offset from DNG.
    let baselineExposure: Float
    /// Linearization table (raw values → linearized values), if present.
    let linearizationTable: [UInt16]?

    /// White balance gains normalized so G = 1.0.
    /// Computed as `1.0 / asShotNeutral`, then normalized.
    var whiteBalanceGains: [Float] {
        guard asShotNeutral.count >= 3 else { return [1, 1, 1] }
        let r = 1.0 / asShotNeutral[0]
        let g = 1.0 / asShotNeutral[1]
        let b = 1.0 / asShotNeutral[2]
        // Normalize so G = 1.0
        let scale = 1.0 / g
        return [r * scale, g * scale, b * scale]
    }

    /// The color matrix to use for rendering (ForwardMatrix preferred over ColorMatrix).
    var preferredColorMatrix: [Float] {
        forwardMatrix1 ?? colorMatrix1
    }

    /// The CFA pattern as a uint for the Metal uniform.
    var cfaPatternIndex: UInt32 {
        switch cfaPattern {
        case .rggb: return 0
        case .bggr: return 1
        case .grbg: return 2
        case .gbrg: return 3
        case .unknown: return 0 // default to RGGB
        }
    }
}

// MARK: - DNGTagParser

/// Parses DNG/TIFF metadata from raw DNG file data using ImageIO.
///
/// This is the Phase 2 bridge between the captured DNG and the Metal pipeline.
/// It extracts all tags needed by `MetalPipelineRunner` to populate
/// `DemosaicUniforms`:
/// - CFA pattern (tag 828E)
/// - BlackLevel (tag 61A5)
/// - WhiteLevel (tag 61A6)
/// - AsShotNeutral (tag 62D0)
/// - ColorMatrix1/2 (tags 62D0, 62D1)
/// - ForwardMatrix1/2 (tags 62BD, 62BE)
/// - BaselineExposure (tag 62B4)
/// - LinearizationTable (tag 6185)
enum DNGTagParser {

    /// Parses DNG metadata from raw file data.
    ///
    /// - Parameter data: Raw DNG file bytes.
    /// - Returns: A `DNGMetadata` struct with all extracted values.
    /// - Throws: `DNGParseError` if the data is not a valid DNG.
    static func parse(_ data: Data) throws -> DNGMetadata {
        guard data.isValidDNG else {
            throw DNGParseError.invalidDNGData
        }

        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw DNGParseError.imageSourceCreationFailed
        }

        guard CGImageSourceGetCount(source) > 0 else {
            throw DNGParseError.noImagesInSource
        }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any] ?? [:]

        // Extract width/height from TIFF tags
        let width = properties[kCGImagePropertyPixelWidth] as? Int ?? 0
        let height = properties[kCGImagePropertyPixelHeight] as? Int ?? 0

        guard width > 0, height > 0 else {
            throw DNGParseError.missingDimensions
        }

        // Extract DNG-specific tags. ImageIO doesn't expose DNG tags like
        // ColorMatrix1 or AsShotNeutral directly — these are in the raw
        // dictionary or need manual TIFF tag parsing. We use defaults
        // for now; the Metal pipeline falls back to CIRAWFilter.
        let dngDict: [String: Any] = (properties[kCGImagePropertyRawDictionary] as? [String: Any]) ?? [:]

        // CFA Pattern — try kCGImagePropertyCFAPattern, fallback to RGGB
        let cfaPattern = parseCFAPattern(from: properties)

        // Black Level
        let blackLevel = parseBlackLevel(from: properties, dngDict: dngDict)

        // White Level
        let whiteLevel = parseWhiteLevel(from: dngDict)

        // AsShot Neutral
        let asShotNeutral = parseAsShotNeutral(from: dngDict)

        // Color Matrices
        let colorMatrix1 = parseColorMatrix(from: dngDict, key: "ColorMatrix1") ?? Self.identityColorMatrix
        let colorMatrix2 = parseColorMatrix(from: dngDict, key: "ColorMatrix2")
        let forwardMatrix1 = parseColorMatrix(from: dngDict, key: "ForwardMatrix1")
        let forwardMatrix2 = parseColorMatrix(from: dngDict, key: "ForwardMatrix2")

        // Baseline Exposure
        let baselineExposure = (dngDict["BaselineExposure"] as? Double).map { Float($0) } ?? 0.0

        // Linearization Table
        let linearizationTable = parseLinearizationTable(from: dngDict)

        return DNGMetadata(
            width: width,
            height: height,
            cfaPattern: cfaPattern,
            blackLevel: blackLevel,
            whiteLevel: whiteLevel,
            asShotNeutral: asShotNeutral,
            colorMatrix1: colorMatrix1,
            colorMatrix2: colorMatrix2,
            forwardMatrix1: forwardMatrix1,
            forwardMatrix2: forwardMatrix2,
            baselineExposure: baselineExposure,
            linearizationTable: linearizationTable
        )
    }

    // MARK: - Private Parsing Helpers

    private static let identityColorMatrix: [Float] = [
        1, 0, 0,
        0, 1, 0,
        0, 0, 1,
    ]

    /// Parses the CFA pattern from image properties.
    ///
    /// Apple's CIRAWFilter exposes the CFA pattern via the raw preview properties.
    /// We try `kCGImagePropertyCFAPattern` first, then default to RGGB.
    private static func parseCFAPattern(from properties: [CFString: Any]) -> CFAPattern {
        // CoreImage RAW properties may contain the CFA pattern
        if let rawData = properties[kCGImagePropertyRawDictionary] as? [String: Any] {
            if let pattern = rawData["CFA"] as? String {
                return CFAPattern(rawValue: pattern) ?? .rggb
            }
        }

        // Default: most iPhone sensors use RGGB
        return .rggb
    }

    /// Parses per-channel black levels.
    ///
    /// DNG BlackLevel can be a single value or per-channel array.
    /// Default to 0 if not found (CIRAWFilter handles it internally).
    private static func parseBlackLevel(from properties: [CFString: Any], dngDict: [String: Any]) -> [Float] {
        // Try DNG tag first
        if let black = dngDict["BlackLevel"] as? [Double] {
            return black.map { Float($0) }
        }
        if let black = dngDict["BlackLevel"] as? Double {
            return [Float(black), Float(black), Float(black), Float(black)]
        }

        // Try CoreImage raw dictionary
        if let rawDict = properties[kCGImagePropertyRawDictionary] as? [String: Any] {
            if let black = rawDict["Black"] as? [Double] {
                return black.map { Float($0) }
            }
            if let black = rawDict["Black"] as? Double {
                return [Float(black), Float(black), Float(black), Float(black)]
            }
        }

        // Default: zero black level
        return [0, 0, 0, 0]
    }

    /// Parses the white level (sensor saturation).
    private static func parseWhiteLevel(from dngDict: [String: Any]) -> Float {
        if let white = dngDict["WhiteLevel"] as? Double {
            return Float(white)
        }
        if let white = dngDict["WhiteLevel"] as? Int {
            return Float(white)
        }
        // Default for 14-bit Bayer: 16383
        return 16383
    }

    /// Parses AsShotNeutral values [R, G, B].
    private static func parseAsShotNeutral(from dngDict: [String: Any]) -> [Float] {
        if let neutral = dngDict["AsShotNeutral"] as? [Double] {
            return neutral.prefix(3).map { Float($0) }
        }
        // Default: neutral white balance (1, 1, 1)
        return [1.0, 1.0, 1.0]
    }

    /// Parses a 3×3 color matrix from DNG tags.
    ///
    /// DNG color matrices are stored as 9 values in row-major order
    /// (SRational in the DNG spec, but ImageIO returns them as doubles).
    private static func parseColorMatrix(from dngDict: [String: Any], key: String) -> [Float]? {
        guard let matrix = dngDict[key] as? [Double], matrix.count >= 9 else {
            // Identity matrix fallback for ColorMatrix; nil for ForwardMatrix
            if key.contains("Forward") { return nil }
            return identityColorMatrix
        }
        return matrix.prefix(9).map { Float($0) }
    }

    /// Parses the linearization table if present.
    private static func parseLinearizationTable(from dngDict: [String: Any]) -> [UInt16]? {
        guard let table = dngDict["LinearizationTable"] as? [Double] else { return nil }
        return table.map { UInt16($0) }
    }
}

// MARK: - DNGParseError

enum DNGParseError: LocalizedError {
    case invalidDNGData
    case imageSourceCreationFailed
    case noImagesInSource
    case missingDimensions

    var errorDescription: String? {
        switch self {
        case .invalidDNGData:
            return "The data is not a valid DNG file."
        case .imageSourceCreationFailed:
            return "Failed to create an image source from the DNG data."
        case .noImagesInSource:
            return "The DNG file contains no images."
        case .missingDimensions:
            return "The DNG file is missing valid image dimensions."
        }
    }
}
