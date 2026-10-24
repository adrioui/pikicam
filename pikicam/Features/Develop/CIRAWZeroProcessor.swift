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
/// Every subjective enhancement `CIRAWFilter` declares is explicitly
/// neutralized — see ``recipe``, the single source of truth, pinned against
/// the SDK's own property set by `PikicamPipelineTests`.
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

    /// The complete zero-process recipe: every enhancement control declared by
    /// the iOS SDK's `CIRAWFilter.h`, paired with the typed setter that
    /// neutralizes it.
    ///
    /// This list is the recipe's single source of truth. `PikicamPipelineTests`
    /// asserts it matches the SDK's declared set, so a control can no longer
    /// silently drop out of the recipe the way chroma noise reduction, detail,
    /// moiré reduction, shadow boost, extended dynamic range, lens correction
    /// and gamut mapping all had.
    ///
    /// Deliberately **not** neutralized:
    /// - `neutralTemperature` / `neutralTint` — white balance comes from the
    ///   DNG's AsShotNeutral; temperature and tint are not subjective knobs.
    /// - `decoderVersion` — the demosaic/decoder algorithm, not a post-filter.
    /// - `highlightRecoveryEnabled` — deprecated as of iOS 19
    ///   (`NS_AVAILABLE(16_0, 19_0)`); referencing it emits a deprecation
    ///   warning, and Apple no longer treats it as a supported control.
    static var recipe: [(objcProperty: String, neutralize: (CIRAWFilter) -> Void)] {
        [
            ("baselineExposure", { $0.baselineExposure = 0.0 }),
            ("exposure", { $0.exposure = 0.0 }),
            ("boostAmount", { $0.boostAmount = 0.0 }),
            ("boostShadowAmount", { $0.boostShadowAmount = 0.0 }),
            ("shadowBias", { $0.shadowBias = 0.0 }),
            ("localToneMapAmount", { $0.localToneMapAmount = 0.0 }),
            ("luminanceNoiseReductionAmount", { $0.luminanceNoiseReductionAmount = 0.0 }),
            ("colorNoiseReductionAmount", { $0.colorNoiseReductionAmount = 0.0 }),
            ("sharpnessAmount", { $0.sharpnessAmount = 0.0 }),
            ("detailAmount", { $0.detailAmount = 0.0 }),
            ("moireReductionAmount", { $0.moireReductionAmount = 0.0 }),
            ("contrastAmount", { $0.contrastAmount = 0.0 }),
            ("extendedDynamicRangeAmount", { $0.extendedDynamicRangeAmount = 0.0 }),
            ("lensCorrectionEnabled", { $0.isLensCorrectionEnabled = false }),
            ("gamutMappingEnabled", { $0.isGamutMappingEnabled = false }),
        ]
    }

    /// Applies the zero-process recipe: every control in ``recipe`` set to its
    /// neutral value wherever the runtime implements the setter.
    ///
    /// A missing setter is skipped rather than raised — some runtimes (the iOS
    /// Simulator's `CIRAWFilterImpl`, and certain devices such as the iPhone 12
    /// mini) do not implement every control and would trap on set. The skip is
    /// safe because ``recipe`` enumerates the controls explicitly; coverage —
    /// not the probe — is what guarantees the recipe.
    ///
    /// Internal rather than private so `PikicamPipelineTests` can apply the
    /// recipe to a filter it holds and read each control back off it: a
    /// complete recipe list is not proof that the probe reached every entry.
    func applyZeroRecipe(_ filter: CIRAWFilter) {
        for entry in Self.recipe {
            apply(filter, entry.objcProperty, entry.neutralize)
        }
    }

    /// Assigns a `CIRAWFilter` control through its typed property when the
    /// runtime implements the setter; a missing setter is skipped.
    ///
    /// - Parameters:
    ///   - filter: The filter to assign to.
    ///   - objcProperty: The **Objective-C** property name, because that is
    ///     what the runtime's setter is derived from. This is deliberately not
    ///     always the Swift spelling: the flags are declared
    ///     `@property(readwrite, getter= isLensCorrectionEnabled) BOOL
    ///     lensCorrectionEnabled`, so the setter is `setLensCorrectionEnabled:`
    ///     — deriving it from the Swift name (`isLensCorrectionEnabled`) yields
    ///     `setIsLensCorrectionEnabled:`, which no runtime implements, and the
    ///     probe would then skip the control in silence.
    ///   - neutralize: The typed assignment that returns the control to its
    ///     neutral value.
    private func apply(
        _ filter: CIRAWFilter,
        _ objcProperty: String,
        _ neutralize: (CIRAWFilter) -> Void
    ) {
        let setter = Selector(
            "set" + objcProperty.prefix(1).uppercased() + objcProperty.dropFirst() + ":"
        )
        guard filter.responds(to: setter) else { return }
        neutralize(filter)
    }
}
