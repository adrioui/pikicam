import Foundation

// MARK: - DemosaicAlgorithm

/// The demosaic algorithm used to reconstruct a full-color image from Bayer-encoded sensor data.
///
/// Each algorithm balances speed, sharpness, and artifact suppression differently:
/// - `bilinear`: Fastest, lowest quality (nearest-neighbor interpolation).
/// - `malvar`: Good quality, moderate speed (Malvar-He-Cutler, the default).
/// - `amaze`: High quality, slower (LibRaw's AMaZE algorithm).
/// - `dcb`: High quality, slower (LibRaw's DCB algorithm).
///
/// Consumed by ``MetalPipelineRunner`` when running the custom Metal debayer pipeline.
enum DemosaicAlgorithm: String, CaseIterable, Sendable, Codable {
    /// Simple bilinear interpolation. Fast but prone to color artifacts on fine details.
    case bilinear = "Bilinear"

    /// Malvar-He-Cutler gradient-corrected interpolation. Good balance of quality and speed.
    case malvar = "Malvar-He-Cutler"

    /// AMaZE (Adaptive Homogeneity-Directed Demosaicing). High-quality, computationally expensive.
    case amaze = "AMaZE (LibRaw)"

    /// DCB (Demosaicing Color Buffer). High-quality, computationally expensive.
    case dcb = "DCB (LibRaw)"

    /// A human-readable description of the algorithm.
    var description: String {
        switch self {
        case .bilinear:
            return "Simple interpolation, fastest, lowest quality."
        case .malvar:
            return "Gradient-corrected, good quality, moderate speed."
        case .amaze:
            return "Adaptive homogeneity-directed, high quality, slow."
        case .dcb:
            return "Color buffer-based, high quality, slow."
        }
    }
}