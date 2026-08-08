import Foundation
import CoreImage
import Metal

// MARK: - MetalDebayerProcessor

/// A Phase 2 raw processor intended to use custom Metal compute kernels for debayering.
///
/// ## Current status
/// The custom Metal pipeline (`MetalPipelineRunner.runPipeline`) is not yet
/// wired into the capture flow. This processor currently delegates to
/// `CIRAWZeroProcessor` (the canonical zero-process recipe) so behavior matches
/// Phase 1. The Metal pipeline remains Phase 2 scaffolding.
nonisolated struct MetalDebayerProcessor: RAWProcessor {

    /// The Metal pipeline runner (dormant — not yet invoked by `develop`).
    private let runner: MetalPipelineRunner?

    /// Fallback CIRAWFilter processor holding the canonical zero-process recipe.
    private let fallback = CIRAWZeroProcessor()

    // MARK: - Initialization

    init() {
        self.runner = try? MetalPipelineRunner()
    }

    // MARK: - RAWProcessor

    func develop(dngData: Data, mode: CaptureMode) throws -> CIImage {
        // RAW-only mode just needs a preview; use CIRAWFilter for speed.
        if mode == .rawOnly {
            return try fallback.develop(dngData: dngData, mode: mode)
        }

        return try fallback.develop(dngData: dngData, mode: mode)
    }
}
