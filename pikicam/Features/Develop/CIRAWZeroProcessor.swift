import Foundation
import CoreImage

/// A raw processor that uses `CIRAWFilter` with all enhancement properties
/// explicitly zeroed or disabled.
///
/// This implements the "zero-process" recipe defined in the grand plan §3.2.
/// The only operations performed are the radiometric floor that cannot be
/// bypassed:
/// - Bayer demosaic (Apple's algorithm)
/// - Black-level subtraction (from DNG tags)
/// - Camera color matrix (from DNG tags)
/// - White balance (from AsShotNeutral)
///
/// All subjective enhancements are explicitly disabled:
/// - No exposure boost (`boostAmount = 0`)
/// - No shadow recovery (`shadowBias = 0`)
/// - No local tone mapping (`localToneMapAmount = 0`)
/// - No noise reduction (`luminanceNoiseReductionAmount = 0`)
/// - No sharpening (`sharpnessAmount = 0`)
/// - No contrast adjustment (`contrastAmount = 0`)
/// - No lens correction (`isLensCorrectionEnabled = false`)
/// - No gamut mapping (`isGamutMappingEnabled = false`)
///
/// ## Phase 2 Note
/// This processor will be replaced by a custom Metal-based pipeline that
/// gives us full control over demosaic, color matrix application, and tone
/// curve. Until then, this provides an honest "Apple-but-naked" rendering.
nonisolated struct CIRAWZeroProcessor: RAWProcessor {

    // MARK: - RAWProcessor

    /// Develops DNG data into a CIImage using the specified mode.
    ///
    /// - Parameters:
    ///   - dngData: Raw DNG file data from the capture pipeline.
    ///   - mode: The capture mode (zero, standard, rawOnly).
    /// - Returns: A CIImage rendered with the chosen processing recipe.
    /// - Throws: `DevelopError` if the filter cannot be created or has no output.
    func develop(dngData: Data, mode: CaptureMode) throws -> CIImage {
        guard let filter = CIRAWFilter(imageData: dngData) else {
            throw DevelopError.filterCreationFailed
        }

        applyZeroRecipe(filter, mode: mode)

        guard let outputImage = filter.outputImage else {
            throw DevelopError.renderingFailed
        }

        return outputImage
    }

    // MARK: - Zero Recipe

    /// Applies the zero-process recipe to a CIRAWFilter.
    ///
    /// In **Zero** mode, every enhancement knob is zeroed explicitly.
    /// In **Standard** mode, Apple's defaults are left as-is.
    /// In **RAW Only** mode, the zero recipe is used for preview.
    private func applyZeroRecipe(_ filter: CIRAWFilter, mode: CaptureMode) {
        switch mode {
        case .zero, .rawOnly:
            // The defining recipe: every subjective knob at zero.
            filter.baselineExposure = 0.0
            filter.exposure = 0.0
            filter.boostAmount = 0.0
            filter.shadowBias = 0.0
            filter.localToneMapAmount = 0.0
            filter.luminanceNoiseReductionAmount = 0.0
            filter.sharpnessAmount = 0.0
            filter.contrastAmount = 0.0
            filter.isLensCorrectionEnabled = false
            filter.isGamutMappingEnabled = false

            // White balance: use AsShot neutral (the DNG's recommended values).
            // The filter defaults to AsShot, so we leave temperature/tint at defaults.

        case .standard:
            // Apple's default processing — leave everything at filter defaults.
            // This serves as a comparison baseline for the zero mode.
            break
        }
    }
}
