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
/// Zero-process is the only recipe; there are no development modes.
nonisolated struct CIRAWZeroProcessor: RAWProcessor {

    // MARK: - RAWProcessor

    /// Develops DNG data into a CIImage using the zero-process recipe.
    ///
    /// - Parameter dngData: Raw DNG file data from the capture pipeline.
    /// - Returns: A CIImage rendered with the zero-process recipe.
    /// - Throws: `DevelopError` if the filter cannot be created, a required
    ///   control is unsupported on this runtime, or the filter has no output.
    func develop(dngData: Data) throws -> CIImage {
        guard let filter = CIRAWFilter(imageData: dngData) else {
            throw DevelopError.filterCreationFailed
        }

        try applyZeroRecipe(filter)

        guard let outputImage = filter.outputImage else {
            throw DevelopError.renderingFailed
        }

        return outputImage
    }

    // MARK: - Zero Recipe

    /// Applies the zero-process recipe to a CIRAWFilter: every enhancement
    /// knob zeroed or disabled explicitly.
    ///
    /// Each control is set through its typed `CIRAWFilter` property. The
    /// setter selector is verified with `responds(to:)` before assignment:
    /// some runtimes (notably the iOS Simulator's `CIRAWFilterImpl`) do not
    /// implement every control and would raise `NSInvalidArgumentException`
    /// on set. An unsupported control is a hard, typed error — the recipe
    /// must be complete or fail loudly; it is never silently skipped.
    ///
    /// White balance is left at the DNG's AsShot neutral (the filter's
    /// default): temperature/tint are not subjective knobs.
    private func applyZeroRecipe(_ filter: CIRAWFilter) throws {
        try apply(filter, "baselineExposure") { filter.baselineExposure = 0.0 }
        try apply(filter, "exposure") { filter.exposure = 0.0 }
        try apply(filter, "boostAmount") { filter.boostAmount = 0.0 }
        try apply(filter, "shadowBias") { filter.shadowBias = 0.0 }
        try apply(filter, "localToneMapAmount") { filter.localToneMapAmount = 0.0 }
        try apply(filter, "luminanceNoiseReductionAmount") { filter.luminanceNoiseReductionAmount = 0.0 }
        try apply(filter, "sharpnessAmount") { filter.sharpnessAmount = 0.0 }
        try apply(filter, "contrastAmount") { filter.contrastAmount = 0.0 }
        try apply(filter, "isLensCorrectionEnabled") { filter.isLensCorrectionEnabled = false }
        try apply(filter, "isGamutMappingEnabled") { filter.isGamutMappingEnabled = false }
    }

    /// Assigns a `CIRAWFilter` control through its typed property, verifying
    /// the runtime implements the setter first.
    ///
    /// - Throws: `DevelopError.unsupportedControl` if the runtime does not
    ///   implement the control's setter (e.g. the iOS Simulator).
    private func apply(_ filter: CIRAWFilter, _ control: String, _ assign: () -> Void) throws {
        let setter = Selector("set" + control.prefix(1).uppercased() + control.dropFirst() + ":")
        guard filter.responds(to: setter) else {
            throw DevelopError.unsupportedControl(control)
        }
        assign()
    }
}
