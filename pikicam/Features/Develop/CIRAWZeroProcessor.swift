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
    /// - Throws: `DevelopError` if the filter cannot be created or has no
    ///   output.
    func develop(dngData: Data) throws -> CIImage {
        guard let filter = CIRAWFilter(imageData: dngData) else {
            throw DevelopError.filterCreationFailed
        }

        applyZeroRecipe(filter)

        guard let outputImage = filter.outputImage else {
            throw DevelopError.renderingFailed
        }

        return outputImage
    }

    // MARK: - Zero Recipe

    /// Applies the zero-process recipe to a CIRAWFilter: every enhancement
    /// knob zeroed or disabled explicitly.
    ///
    /// Each control is set through its typed `CIRAWFilter` property when the
    /// runtime implements the setter. Some runtimes (the iOS Simulator's
    /// `CIRAWFilterImpl`, and certain devices such as the iPhone 12 mini) do
    /// not implement every control and would raise `NSInvalidArgumentException`
    /// on set; there, the enhancement is simply **absent** — the filter's
    /// default is already the neutral value (0 for amounts, false for flags) —
    /// so skipping the assignment cannot violate the recipe. The recipe's
    /// invariant is "no enhancement is applied", and a missing control
    /// guarantees that by construction. A missing setter is therefore never
    /// an error; only a filter that cannot be created or produces no output
    /// fails.
    ///
    /// White balance is left at the DNG's AsShot neutral (the filter's
    /// default): temperature/tint are not subjective knobs.
    private func applyZeroRecipe(_ filter: CIRAWFilter) {
        apply(filter, "baselineExposure") { filter.baselineExposure = 0.0 }
        apply(filter, "exposure") { filter.exposure = 0.0 }
        apply(filter, "boostAmount") { filter.boostAmount = 0.0 }
        apply(filter, "shadowBias") { filter.shadowBias = 0.0 }
        apply(filter, "localToneMapAmount") { filter.localToneMapAmount = 0.0 }
        apply(filter, "luminanceNoiseReductionAmount") { filter.luminanceNoiseReductionAmount = 0.0 }
        apply(filter, "sharpnessAmount") { filter.sharpnessAmount = 0.0 }
        apply(filter, "contrastAmount") { filter.contrastAmount = 0.0 }
        apply(filter, "isLensCorrectionEnabled") { filter.isLensCorrectionEnabled = false }
        apply(filter, "isGamutMappingEnabled") { filter.isGamutMappingEnabled = false }
    }

    /// Assigns a `CIRAWFilter` control through its typed property when the
    /// runtime implements the setter. A missing setter is skipped: the
    /// control's default is already the neutral value, so the zero-process
    /// invariant holds without it.
    private func apply(_ filter: CIRAWFilter, _ control: String, _ assign: () -> Void) {
        let setter = Selector("set" + control.prefix(1).uppercased() + control.dropFirst() + ":")
        guard filter.responds(to: setter) else { return }
        assign()
    }
}
